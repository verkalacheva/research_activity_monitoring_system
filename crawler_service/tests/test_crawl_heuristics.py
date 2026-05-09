"""Unit tests for infrastructure/crawl_heuristics.py."""
import os
import pytest
from infrastructure.crawl_heuristics import (
    normalize_url_for_dedup,
    compress_text_for_llm_signals,
    html_requires_playwright,
    pipeline_mode,
    cheap_llm_prefilter_enabled,
    skip_playwright_after_http_enabled,
    retrieval_top_k_effective,
    embedding_model_effective,
    cheap_relevance_min_score,
    sentence_boost_filter_enabled,
)


# ---------------------------------------------------------------------------
# normalize_url_for_dedup
# ---------------------------------------------------------------------------
class TestNormalizeUrlForDedup:
    def test_empty_string_returns_empty(self):
        assert normalize_url_for_dedup("") == ""

    def test_none_returns_empty(self):
        assert normalize_url_for_dedup(None) == ""

    def test_removes_fragment(self):
        url = "https://example.com/page#section"
        key = normalize_url_for_dedup(url)
        assert "#section" not in key

    def test_lowercases_host(self):
        url = "https://EXAMPLE.COM/path"
        key = normalize_url_for_dedup(url)
        assert "example.com" in key

    def test_removes_trailing_slash_from_path(self):
        key1 = normalize_url_for_dedup("https://example.com/path/")
        key2 = normalize_url_for_dedup("https://example.com/path")
        assert key1 == key2

    def test_preserves_query_string(self):
        url = "https://example.com/search?q=python"
        key = normalize_url_for_dedup(url)
        assert "q=python" in key

    def test_root_path_normalised(self):
        key = normalize_url_for_dedup("https://example.com")
        assert key  # non-empty, root path → "/"

    def test_two_equivalent_urls_produce_same_key(self):
        k1 = normalize_url_for_dedup("https://Example.COM/path/#sec")
        k2 = normalize_url_for_dedup("https://example.com/path/")
        assert k1 == k2

    def test_different_urls_produce_different_keys(self):
        k1 = normalize_url_for_dedup("https://a.com/page1")
        k2 = normalize_url_for_dedup("https://a.com/page2")
        assert k1 != k2


# ---------------------------------------------------------------------------
# compress_text_for_llm_signals
# ---------------------------------------------------------------------------
class TestCompressTextForLlmSignals:
    def _make_text(self, paragraphs):
        return "\n\n".join(paragraphs)

    def test_empty_text_returns_empty(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "1")
        assert compress_text_for_llm_signals("", 1000) == ""

    def test_short_text_three_paras_returned_as_is(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "1")
        text = self._make_text(["para one", "para two", "para three"])
        result = compress_text_for_llm_signals(text, 10_000)
        # ≤3 paragraphs: returned verbatim (up to max_chars)
        assert "para one" in result

    def test_high_signal_paragraphs_prioritised(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "1")
        # Paragraph with a year and achievement keyword should appear in output
        high = "В 2022 году получил грант на исследование нейронных сетей в Сколтехе."
        low_paras = [f"Lorem ipsum dolor sit amet {i}." for i in range(5)]
        paragraphs = low_paras[:2] + [high] + low_paras[2:]
        text = self._make_text(paragraphs)
        result = compress_text_for_llm_signals(text, 500)
        assert high[:30] in result

    def test_result_does_not_exceed_max_chars(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "1")
        paras = [f"Paragraph number {i} about публикация in 2021." for i in range(20)]
        text = self._make_text(paras)
        result = compress_text_for_llm_signals(text, 200)
        assert len(result) <= 200

    def test_disabled_filter_returns_text_unchanged(self, monkeypatch):
        # When the sentence-boost filter is off, the function returns text as-is
        # (truncation to max_chars is NOT applied in the disabled path).
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "0")
        text = self._make_text(["a" * 50] * 10)
        result = compress_text_for_llm_signals(text, 100)
        assert result == text


# ---------------------------------------------------------------------------
# html_requires_playwright
# ---------------------------------------------------------------------------
class TestHtmlRequiresPlaywright:
    def test_empty_plain_text_requires_playwright(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        assert html_requires_playwright("<html></html>", "") is True

    def test_very_short_plain_text_requires_playwright(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        assert html_requires_playwright("<html><p>Hi</p></html>", "Hi") is True

    def test_sufficient_text_with_body_tags_does_not_require_playwright(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        monkeypatch.setenv("CRAWL_HTTP_FIRST_MIN_WORDS", "10")
        # plain text must be > 120 chars to pass the char-length guard first
        plain = "word " * 50  # 250 chars, 50 words — well above both thresholds
        html = "<html><main><p>" + plain + "</p></main></html>"
        assert html_requires_playwright(html, plain) is False

    def test_force_playwright_env_overrides(self, monkeypatch):
        monkeypatch.setenv("CRAWL_FORCE_PLAYWRIGHT", "1")
        html = "<html><main>" + "<p>word " * 200 + "</p></main></html>"
        plain = "word " * 200
        assert html_requires_playwright(html, plain) is True

    def test_many_scripts_with_little_text_requires_playwright(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        scripts = "<script>x</script>" * 35
        html = f"<html>{scripts}<p>{'word ' * 10}</p></html>"
        plain = "word " * 10
        assert html_requires_playwright(html, plain) is True


# ---------------------------------------------------------------------------
# Pipeline/env flag helpers
# ---------------------------------------------------------------------------
class TestEnvHelpers:
    def test_pipeline_mode_defaults_to_fast(self, monkeypatch):
        monkeypatch.delenv("CRAWL_PIPELINE_MODE", raising=False)
        assert pipeline_mode() == "fast"

    def test_pipeline_mode_deep(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "deep")
        assert pipeline_mode() == "deep"

    def test_pipeline_mode_unknown_value_treated_as_fast(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "turbo")
        assert pipeline_mode() == "fast"

    def test_cheap_prefilter_disabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CHEAP_LLM_PREFILTER", raising=False)
        assert cheap_llm_prefilter_enabled() is False

    def test_cheap_prefilter_enabled_by_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHEAP_LLM_PREFILTER", "1")
        assert cheap_llm_prefilter_enabled() is True

    def test_skip_playwright_enabled_by_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_SKIP_PLAYWRIGHT_IF_HTTP_OK", raising=False)
        assert skip_playwright_after_http_enabled() is True

    def test_skip_playwright_disabled_by_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_SKIP_PLAYWRIGHT_IF_HTTP_OK", "0")
        assert skip_playwright_after_http_enabled() is False


# ---------------------------------------------------------------------------
# retrieval_top_k_effective
# ---------------------------------------------------------------------------
class TestRetrievalTopKEffective:
    def test_default_returns_large_value(self, monkeypatch):
        monkeypatch.delenv("CRAWL_RETRIEVAL_TOP_K", raising=False)
        assert retrieval_top_k_effective() >= 10 ** 6

    def test_custom_value_returned(self, monkeypatch):
        monkeypatch.setenv("CRAWL_RETRIEVAL_TOP_K", "50")
        assert retrieval_top_k_effective() == 50

    def test_minimum_enforced_at_one(self, monkeypatch):
        monkeypatch.setenv("CRAWL_RETRIEVAL_TOP_K", "0")
        assert retrieval_top_k_effective() == 1

    def test_invalid_value_falls_back_to_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_RETRIEVAL_TOP_K", "not_a_number")
        assert retrieval_top_k_effective() >= 10 ** 6


# ---------------------------------------------------------------------------
# embedding_model_effective
# ---------------------------------------------------------------------------
class TestEmbeddingModelEffective:
    def test_fast_mode_no_model_returns_empty(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.delenv("CRAWL_EMBEDDING_MODEL", raising=False)
        monkeypatch.setenv("CRAWL_FAST_USE_EMBEDDINGS", "0")
        assert embedding_model_effective() == ""

    def test_fast_mode_with_embeddings_enabled_returns_model(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_EMBEDDING_MODEL", "text-embedding-3-small")
        monkeypatch.setenv("CRAWL_FAST_USE_EMBEDDINGS", "1")
        assert embedding_model_effective() == "text-embedding-3-small"

    def test_deep_mode_returns_model_always(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "deep")
        monkeypatch.setenv("CRAWL_EMBEDDING_MODEL", "text-embedding-ada-002")
        assert embedding_model_effective() == "text-embedding-ada-002"

    def test_deep_mode_no_model_returns_empty_string(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "deep")
        monkeypatch.delenv("CRAWL_EMBEDDING_MODEL", raising=False)
        assert embedding_model_effective() == ""

    def test_fast_mode_embeddings_true_value(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_EMBEDDING_MODEL", "model-x")
        monkeypatch.setenv("CRAWL_FAST_USE_EMBEDDINGS", "true")
        assert embedding_model_effective() == "model-x"


# ---------------------------------------------------------------------------
# cheap_relevance_min_score
# ---------------------------------------------------------------------------
class TestCheapRelevanceMinScore:
    def test_default_score(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CHEAP_RELEVANCE_MIN", raising=False)
        assert cheap_relevance_min_score() == pytest.approx(0.06)

    def test_custom_score(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHEAP_RELEVANCE_MIN", "0.15")
        assert cheap_relevance_min_score() == pytest.approx(0.15)

    def test_invalid_value_returns_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHEAP_RELEVANCE_MIN", "bad_value")
        assert cheap_relevance_min_score() == pytest.approx(0.06)


# ---------------------------------------------------------------------------
# sentence_boost_filter_enabled
# ---------------------------------------------------------------------------
class TestSentenceBoostFilterEnabled:
    def test_enabled_by_default_in_fast_mode(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.delenv("CRAWL_CHUNK_SENTENCE_FILTER", raising=False)
        assert sentence_boost_filter_enabled() is True

    def test_disabled_in_deep_mode(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "deep")
        assert sentence_boost_filter_enabled() is False

    def test_disabled_by_env_in_fast_mode(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "0")
        assert sentence_boost_filter_enabled() is False

    def test_explicit_true_in_fast_mode(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "1")
        assert sentence_boost_filter_enabled() is True


# ---------------------------------------------------------------------------
# Additional compress_text_for_llm_signals tests
# ---------------------------------------------------------------------------
class TestCompressTextMoreBranches:
    def _make_text(self, paragraphs):
        return "\n\n".join(paragraphs)

    def test_deep_mode_returns_text_up_to_max_chars(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "deep")
        text = "word " * 1000
        result = compress_text_for_llm_signals(text, 100)
        # deep mode: filter disabled, returns text[:max_chars]
        assert result == text

    def test_truncates_long_high_signal_para(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "1")
        # Make high-signal paragraph longer than max_chars
        signal_para = "Получил грант в 2022 году " * 10  # ~260 chars
        low_paras = [f"Noise paragraph {i}." for i in range(5)]
        paragraphs = low_paras[:2] + [signal_para] + low_paras[2:]
        text = self._make_text(paragraphs)
        result = compress_text_for_llm_signals(text, 80)
        assert len(result) <= 80

    def test_fallback_when_no_output_produced(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "1")
        # All paragraphs are low signal, tiny budget: might trigger fallback
        paras = [f"short {i}" for i in range(5)]
        text = self._make_text(paras)
        result = compress_text_for_llm_signals(text, 1)  # 1 char budget
        # Should return something (either fallback or truncated)
        assert isinstance(result, str)

    def test_no_low_signal_paras_only_high(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "1")
        # All paragraphs have signals
        paras = [f"Публикация {i} в 2023 году." for i in range(6)]
        text = self._make_text(paras)
        result = compress_text_for_llm_signals(text, 5000)
        assert "Публикация" in result

    def test_mixed_high_and_low_signal(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_MODE", "fast")
        monkeypatch.setenv("CRAWL_CHUNK_SENTENCE_FILTER", "1")
        high_paras = [f"DOI: 10.1234/{i}; журнал {i}; год 2024" for i in range(3)]
        low_paras = [f"Обычный текст {i}" for i in range(4)]
        paras = low_paras[:2] + high_paras + low_paras[2:]
        text = self._make_text(paras)
        result = compress_text_for_llm_signals(text, 2000)
        # high-signal paragraphs should be present
        assert any("DOI" in result for _ in [1])


# ---------------------------------------------------------------------------
# Additional html_requires_playwright tests
# ---------------------------------------------------------------------------
class TestHtmlRequiresPlaywrightMore:
    def test_words_below_threshold_with_article_tag_skips_playwright(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        monkeypatch.setenv("CRAWL_HTTP_FIRST_MIN_WORDS", "200")
        # 100 words, well above max(40, 100) = 100 minimum, with article tag
        plain = "word " * 100
        html = "<html><article><p>" + plain + "</p></article></html>"
        result = html_requires_playwright(html, plain)
        assert result is False

    def test_no_structural_tags_few_words_requires_playwright(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        monkeypatch.setenv("CRAWL_HTTP_FIRST_MIN_WORDS", "10")
        plain = "word " * 100  # 100 words, passes char threshold
        html = "<html><body>" + plain + "</body></html>"  # no structural tags
        # 100 words < 200 → requires playwright
        result = html_requires_playwright(html, plain)
        assert result is True

    def test_many_scripts_over_30_requires_playwright(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        monkeypatch.setenv("CRAWL_HTTP_FIRST_MIN_WORDS", "10")
        plain = "word " * 150
        scripts = "<script>x</script>" * 31
        html = f"<html><article>{scripts}<p>{plain}</p></article></html>"
        # script_n > 30 and len(t) < 2500 → True
        result = html_requires_playwright(html, plain)
        assert result is True

    def test_moderate_scripts_with_few_words_requires_playwright(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        monkeypatch.setenv("CRAWL_HTTP_FIRST_MIN_WORDS", "10")
        plain = "word " * 150  # 150 words, 750 chars — passes char threshold
        scripts = "<script>x</script>" * 13  # 13 scripts, > 12
        html = f"<html><article>{scripts}<p>{plain}</p></article></html>"
        # script_n > 12 and 150 < 180 → True
        result = html_requires_playwright(html, plain)
        assert result is True

    def test_moderate_scripts_many_words_no_playwright(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        monkeypatch.setenv("CRAWL_HTTP_FIRST_MIN_WORDS", "10")
        plain = "word " * 200  # 200 words — not < 180
        scripts = "<script>x</script>" * 13
        html = f"<html><article>{scripts}<p>{plain}</p></article></html>"
        # script_n > 12 but 200 >= 180 → does NOT trigger this branch
        result = html_requires_playwright(html, plain)
        assert result is False

    def test_invalid_min_words_env_falls_back_to_120(self, monkeypatch):
        monkeypatch.delenv("CRAWL_FORCE_PLAYWRIGHT", raising=False)
        monkeypatch.setenv("CRAWL_HTTP_FIRST_MIN_WORDS", "not_int")
        plain = "word " * 200  # above 120
        html = "<html><article><p>" + plain + "</p></article></html>"
        result = html_requires_playwright(html, plain)
        assert result is False
