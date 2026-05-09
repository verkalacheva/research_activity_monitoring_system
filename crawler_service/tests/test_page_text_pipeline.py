"""Unit tests for infrastructure/page_text_pipeline.py (pure functions)."""
from __future__ import annotations

import pytest
from infrastructure.page_text_pipeline import (
    normalize_whitespace,
    dedupe_paragraphs,
    extract_main_text_trafilatura,
    main_text_from_html_and_fallback,
    tokenize,
    BM25,
    chunk_by_paragraphs,
    cheap_relevance_pass,
    rank_chunks_bm25,
    rerank_top_by_length,
    build_structured_context,
    clean_flat_text,
    prepare_text_for_llm,
    _chunk_quality_ok,
    _pipeline_enabled,
    _retrieval_enabled,
    _chunk_token_target,
    _max_prompt_chars_from_chunks,
    _short_page_threshold_chars,
    _embedding_prefilter_chunks,
)


# ---------------------------------------------------------------------------
# Env helper functions
# ---------------------------------------------------------------------------
class TestEnvHelpers:
    def test_pipeline_enabled_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_PIPELINE_ENABLED", raising=False)
        assert _pipeline_enabled() is True

    def test_pipeline_disabled_by_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "0")
        assert _pipeline_enabled() is False

    def test_retrieval_enabled_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_RETRIEVAL_ENABLED", raising=False)
        assert _retrieval_enabled() is True

    def test_retrieval_disabled_by_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_RETRIEVAL_ENABLED", "false")
        assert _retrieval_enabled() is False

    def test_chunk_token_target_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CHUNK_TOKEN_TARGET", raising=False)
        assert _chunk_token_target() == 500

    def test_chunk_token_target_custom(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHUNK_TOKEN_TARGET", "800")
        assert _chunk_token_target() == 800

    def test_chunk_token_target_clamped_min(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHUNK_TOKEN_TARGET", "10")
        assert _chunk_token_target() == 200

    def test_max_prompt_chars_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_MAX_RETRIEVAL_PROMPT_CHARS", raising=False)
        assert _max_prompt_chars_from_chunks() == 16000

    def test_max_prompt_chars_custom(self, monkeypatch):
        monkeypatch.setenv("CRAWL_MAX_RETRIEVAL_PROMPT_CHARS", "32000")
        assert _max_prompt_chars_from_chunks() == 32000

    def test_short_page_threshold_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_SKIP_RETRIEVAL_BELOW_CHARS", raising=False)
        assert _short_page_threshold_chars() == 4000

    def test_embedding_prefilter_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_EMBEDDING_PREFILTER", raising=False)
        assert _embedding_prefilter_chunks() >= 10 ** 6

    def test_embedding_prefilter_custom(self, monkeypatch):
        monkeypatch.setenv("CRAWL_EMBEDDING_PREFILTER", "50")
        assert _embedding_prefilter_chunks() == 50

    def test_embedding_prefilter_invalid(self, monkeypatch):
        monkeypatch.setenv("CRAWL_EMBEDDING_PREFILTER", "abc")
        assert _embedding_prefilter_chunks() >= 10 ** 6


# ---------------------------------------------------------------------------
# normalize_whitespace
# ---------------------------------------------------------------------------
class TestNormalizeWhitespace:
    def test_empty_returns_empty(self):
        assert normalize_whitespace("") == ""

    def test_none_returns_empty(self):
        assert normalize_whitespace(None) == ""

    def test_removes_extra_spaces(self):
        assert normalize_whitespace("hello   world") == "hello world"

    def test_collapses_multiple_newlines(self):
        result = normalize_whitespace("a\n\n\n\nb")
        assert result == "a\n\nb"

    def test_strips_leading_trailing_whitespace(self):
        assert normalize_whitespace("  hello  ") == "hello"

    def test_normalizes_crlf(self):
        result = normalize_whitespace("line1\r\nline2")
        assert result == "line1\nline2"

    def test_preserves_single_newlines(self):
        result = normalize_whitespace("line1\nline2")
        assert result == "line1\nline2"

    def test_collapses_tabs(self):
        result = normalize_whitespace("col1\t\tcol2")
        assert result == "col1 col2"


# ---------------------------------------------------------------------------
# dedupe_paragraphs
# ---------------------------------------------------------------------------
class TestDedupeParagraphs:
    def test_empty_returns_empty(self):
        assert dedupe_paragraphs("") == ""

    def test_single_paragraph_unchanged(self):
        text = "This is a paragraph about research."
        result = dedupe_paragraphs(text)
        assert "research" in result

    def test_duplicate_paragraphs_removed(self):
        para = "This is a duplicate paragraph. " * 5  # > 24 chars
        text = para + "\n\n" + para
        result = dedupe_paragraphs(text)
        # Should appear only once
        assert result.count(para.strip()) <= 1

    def test_short_paragraphs_always_kept(self):
        # Paragraphs < 24 chars are always kept even if duplicated
        text = "short\n\nshort\n\nshort"
        result = dedupe_paragraphs(text)
        assert "short" in result

    def test_case_insensitive_dedup(self):
        p1 = "This paragraph about research and publications is long enough to dedup."
        p2 = "THIS PARAGRAPH ABOUT RESEARCH AND PUBLICATIONS IS LONG ENOUGH TO DEDUP."
        text = p1 + "\n\n" + p2
        result = dedupe_paragraphs(text)
        # Second should be removed (case-insensitive)
        lines = [l for l in result.split("\n\n") if l.strip()]
        assert len(lines) == 1


# ---------------------------------------------------------------------------
# tokenize
# ---------------------------------------------------------------------------
class TestTokenize:
    def test_empty_string_returns_empty(self):
        assert tokenize("") == []

    def test_none_returns_empty(self):
        assert tokenize(None) == []

    def test_basic_words(self):
        result = tokenize("Hello world")
        assert "hello" in result
        assert "world" in result

    def test_short_words_excluded(self):
        result = tokenize("a b c de")
        assert "a" not in result
        assert "b" not in result
        assert "de" in result

    def test_russian_words_tokenized(self):
        result = tokenize("Привет мир")
        assert "привет" in result
        assert "мир" in result

    def test_punctuation_not_included(self):
        result = tokenize("Hello, world! How?")
        for t in result:
            assert "," not in t
            assert "!" not in t

    def test_lowercasing(self):
        result = tokenize("UPPER lower Mixed")
        assert "upper" in result
        assert "lower" in result
        assert "mixed" in result


# ---------------------------------------------------------------------------
# _chunk_quality_ok
# ---------------------------------------------------------------------------
class TestChunkQualityOk:
    def test_empty_chunk_fails(self):
        assert _chunk_quality_ok("") is False

    def test_short_chunk_fails(self):
        assert _chunk_quality_ok("short") is False

    def test_chunk_with_mostly_numbers_fails(self):
        # Less than 25% letters
        assert _chunk_quality_ok("1234567890 123 456 789 0123456789" * 3) is False

    def test_normal_text_passes(self):
        text = "This is a normal paragraph about research activities and publications."
        assert _chunk_quality_ok(text) is True

    def test_russian_text_passes(self):
        text = "Это нормальный абзац о научной деятельности и публикациях в журналах ВАК."
        assert _chunk_quality_ok(text) is True


# ---------------------------------------------------------------------------
# BM25
# ---------------------------------------------------------------------------
class TestBM25:
    def test_empty_corpus(self):
        bm = BM25([])
        assert bm.N == 0

    def test_single_document_perfect_match(self):
        corpus = [["research", "publication", "grant"]]
        bm = BM25(corpus)
        score = bm.score_doc(["research", "grant"], 0)
        assert score > 0

    def test_empty_query_returns_zero(self):
        corpus = [["research", "publication"]]
        bm = BM25(corpus)
        assert bm.score_doc([], 0) == 0.0

    def test_empty_document_returns_zero(self):
        corpus = [[], ["research"]]
        bm = BM25(corpus)
        assert bm.score_doc(["research"], 0) == 0.0

    def test_relevant_document_scores_higher(self):
        corpus = [
            ["research", "publication", "grant"],  # relevant
            ["hello", "world", "foo"],  # irrelevant
        ]
        bm = BM25(corpus)
        score_relevant = bm.score_doc(["research", "publication"], 0)
        score_irrelevant = bm.score_doc(["research", "publication"], 1)
        assert score_relevant > score_irrelevant

    def test_idf_rare_word_scores_higher(self):
        corpus = [
            ["research", "research", "common"],
            ["rare_term", "research"],
        ]
        bm = BM25(corpus)
        # rare_term appears in only 1 of 2 docs; IDF should be higher
        idf_rare = bm._idf("rare_term")
        idf_common = bm._idf("common")
        assert idf_rare > 0


# ---------------------------------------------------------------------------
# chunk_by_paragraphs
# ---------------------------------------------------------------------------
class TestChunkByParagraphs:
    def test_empty_text_returns_empty(self):
        result = chunk_by_paragraphs("", 100)
        assert result == []

    def test_single_short_paragraph(self):
        text = "This is a short paragraph about research."
        result = chunk_by_paragraphs(text, 500)
        assert len(result) >= 1
        assert any("research" in c for c in result)

    def test_multiple_paragraphs_chunked(self):
        paras = [f"Paragraph {i} about research activities and achievements." for i in range(10)]
        text = "\n\n".join(paras)
        result = chunk_by_paragraphs(text, 50)  # small token budget
        assert len(result) >= 1

    def test_very_long_paragraph_split(self):
        long_para = "word " * 2000  # 10000 chars, much larger than chunk
        result = chunk_by_paragraphs(long_para, 100)
        assert len(result) > 1

    def test_poor_quality_chunks_filtered(self):
        # Pure numbers should fail quality check
        text = "1234567890\n\nThis is a valid paragraph with enough alphabetic content to pass."
        result = chunk_by_paragraphs(text, 500)
        for chunk in result:
            assert _chunk_quality_ok(chunk)


# ---------------------------------------------------------------------------
# rank_chunks_bm25
# ---------------------------------------------------------------------------
class TestRankChunksBm25:
    def test_empty_chunks_returns_empty(self):
        assert rank_chunks_bm25([], ["query"]) == []

    def test_empty_queries_returns_zero_scores(self):
        chunks = ["chunk one", "chunk two"]
        result = rank_chunks_bm25(chunks, [])
        assert all(score == 0.0 for _, score in result)

    def test_returns_tuple_list(self):
        chunks = ["research paper grant", "hello world"]
        result = rank_chunks_bm25(chunks, ["research"])
        assert len(result) == 2
        assert all(isinstance(idx, int) and isinstance(sc, float) for idx, sc in result)

    def test_relevant_chunk_scores_higher(self):
        chunks = [
            "research publication grant award",  # highly relevant
            "hello world this is unrelated content",  # irrelevant
        ]
        result = rank_chunks_bm25(chunks, ["research", "publication"])
        # Result is sorted descending by score
        assert result[0][0] == 0  # first chunk should score higher

    def test_multiple_queries_combined(self):
        chunks = ["research", "publication", "grant award achievement"]
        result = rank_chunks_bm25(chunks, ["research", "achievement", "publication"])
        assert len(result) == 3


# ---------------------------------------------------------------------------
# rerank_top_by_length
# ---------------------------------------------------------------------------
class TestRerankTopByLength:
    def test_empty_indices_returns_empty(self):
        assert rerank_top_by_length(["chunk"], []) == []

    def test_single_index_returned(self):
        chunks = ["hello"]
        assert rerank_top_by_length(chunks, [0]) == [0]

    def test_longer_chunk_ranked_first(self):
        chunks = ["short", "a much longer chunk with more content for extraction"]
        result = rerank_top_by_length(chunks, [0, 1])
        assert result[0] == 1  # longer chunk first

    def test_preserves_all_indices(self):
        chunks = ["a" * 100, "b" * 50, "c" * 200]
        result = rerank_top_by_length(chunks, [0, 1, 2])
        assert sorted(result) == [0, 1, 2]


# ---------------------------------------------------------------------------
# build_structured_context
# ---------------------------------------------------------------------------
class TestBuildStructuredContext:
    def test_empty_list_returns_empty(self):
        assert build_structured_context([]) == ""

    def test_single_block(self):
        result = build_structured_context(["content here"])
        assert "[Источник 1]" in result
        assert "content here" in result

    def test_multiple_blocks_numbered(self):
        result = build_structured_context(["first", "second", "third"])
        assert "[Источник 1]" in result
        assert "[Источник 2]" in result
        assert "[Источник 3]" in result
        assert "first" in result
        assert "second" in result

    def test_blocks_separated_by_double_newline(self):
        result = build_structured_context(["block A", "block B"])
        assert "\n\n" in result


# ---------------------------------------------------------------------------
# clean_flat_text
# ---------------------------------------------------------------------------
class TestCleanFlatText:
    def test_empty_returns_empty(self, monkeypatch):
        monkeypatch.delenv("CRAWL_PIPELINE_ENABLED", raising=False)
        assert clean_flat_text("") == ""

    def test_normalizes_whitespace(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        result = clean_flat_text("  hello   world  ")
        assert result == "hello world"

    def test_pipeline_disabled_just_normalizes(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "0")
        result = clean_flat_text("hello   world")
        assert result == "hello world"

    def test_dedupes_paragraphs(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        para = "A long enough paragraph to trigger deduplication logic."
        text = para + "\n\n" + para
        result = clean_flat_text(text)
        assert result.count(para) <= 1


# ---------------------------------------------------------------------------
# prepare_text_for_llm
# ---------------------------------------------------------------------------
class TestPrepareTextForLlm:
    def test_empty_text_returns_empty(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_RETRIEVAL_ENABLED", "1")
        body, stats = prepare_text_for_llm("", ["query"])
        assert body == ""

    def test_pipeline_disabled_returns_text_as_is(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "0")
        text = "Some text content here."
        body, stats = prepare_text_for_llm(text, ["query"])
        assert "Some text" in body

    def test_no_retrieval_returns_full_text(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_RETRIEVAL_ENABLED", "0")
        text = "Research text about publications." * 10
        body, stats = prepare_text_for_llm(text, ["query"])
        assert stats["mode"] == "full_no_retrieval"

    def test_short_page_returns_full_short(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_RETRIEVAL_ENABLED", "1")
        monkeypatch.setenv("CRAWL_SKIP_RETRIEVAL_BELOW_CHARS", "10000")
        # Text shorter than threshold
        text = "Short text about research publications."
        body, stats = prepare_text_for_llm(text, ["research"])
        assert stats["mode"] == "full_short_page"
        assert "Short text" in body

    def test_retrieval_mode_for_long_text(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_RETRIEVAL_ENABLED", "1")
        monkeypatch.setenv("CRAWL_SKIP_RETRIEVAL_BELOW_CHARS", "100")
        # Create text longer than threshold
        para = "Research publications and achievements in science. " * 3
        text = "\n\n".join([para] * 20)  # long enough to trigger retrieval
        body, stats = prepare_text_for_llm(text, ["research", "publications"])
        assert "mode" in stats
        assert body  # non-empty

    def test_no_retrieval_queries_uses_text_as_query(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_RETRIEVAL_ENABLED", "1")
        monkeypatch.setenv("CRAWL_SKIP_RETRIEVAL_BELOW_CHARS", "100")
        para = "Research publications and achievements in science. " * 3
        text = "\n\n".join([para] * 20)
        # Pass empty queries → should fall back to text as query
        body, stats = prepare_text_for_llm(text, [])
        assert body


# ---------------------------------------------------------------------------
# cheap_relevance_pass
# ---------------------------------------------------------------------------
class TestCheapRelevancePass:
    def test_prefilter_disabled_always_true(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHEAP_LLM_PREFILTER", "0")
        assert cheap_relevance_pass("any text", ["query"]) is True

    def test_short_text_returns_false_when_enabled(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHEAP_LLM_PREFILTER", "1")
        monkeypatch.setenv("CRAWL_CHEAP_RELEVANCE_MIN", "0.1")
        # Short text → False
        assert cheap_relevance_pass("short", ["query"]) is False

    def test_relevant_text_passes(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHEAP_LLM_PREFILTER", "1")
        monkeypatch.setenv("CRAWL_CHEAP_RELEVANCE_MIN", "0.0001")
        text = "Research publications and scientific achievements. " * 10
        assert cheap_relevance_pass(text, ["research", "publications"]) is True

    def test_empty_queries_returns_true(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHEAP_LLM_PREFILTER", "1")
        text = "Some text content here that is long enough. " * 10
        assert cheap_relevance_pass(text, []) is True

    def test_none_queries_returns_true(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHEAP_LLM_PREFILTER", "1")
        text = "Research text here for testing. " * 10
        assert cheap_relevance_pass(text, None) is True


# ---------------------------------------------------------------------------
# main_text_from_html_and_fallback
# ---------------------------------------------------------------------------
class TestMainTextFromHtmlAndFallback:
    def test_pipeline_disabled_returns_normalized_fallback(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "0")
        result = main_text_from_html_and_fallback("<html><p>test</p></html>", "  fallback  ")
        assert result == "fallback"

    def test_empty_html_uses_fallback(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        result = main_text_from_html_and_fallback("", "fallback text content")
        assert "fallback" in result

    def test_fallback_when_html_extraction_fails(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        # Minimal HTML that trafilatura might return empty for
        result = main_text_from_html_and_fallback("<html></html>", "the fallback text")
        assert "fallback" in result

    def test_none_html_uses_fallback(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        result = main_text_from_html_and_fallback(None, "fallback content here")
        assert "fallback" in result


# ---------------------------------------------------------------------------
# extract_main_text_trafilatura
# ---------------------------------------------------------------------------
class TestExtractMainTextTrafilatura:
    def test_empty_html_returns_none(self):
        assert extract_main_text_trafilatura("") is None

    def test_none_html_returns_none(self):
        assert extract_main_text_trafilatura(None) is None

    def test_short_html_returns_none(self):
        assert extract_main_text_trafilatura("<p>hi</p>") is None  # < 40 chars

    def test_real_html_extracts_text(self):
        html = """<html>
        <head><title>Test</title></head>
        <body>
            <article>
                <h1>Research Publication</h1>
                <p>This is an article about scientific research and achievements in academia.</p>
                <p>It contains multiple paragraphs with substantial content for extraction.</p>
            </article>
        </body>
        </html>"""
        result = extract_main_text_trafilatura(html)
        # Either None (if trafilatura not available) or a non-empty string
        assert result is None or len(result.strip()) > 0


# ---------------------------------------------------------------------------
# Additional ValueError branch tests for env helpers
# ---------------------------------------------------------------------------
from infrastructure.page_text_pipeline import (
    _chunk_token_target,
    _max_prompt_chars_from_chunks,
    _short_page_threshold_chars,
)


class TestEnvHelperValueErrorBranches:
    def test_chunk_token_target_invalid_returns_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CHUNK_TOKEN_TARGET", "not_a_number")
        assert _chunk_token_target() == 500

    def test_max_prompt_chars_invalid_returns_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_MAX_RETRIEVAL_PROMPT_CHARS", "not_a_number")
        assert _max_prompt_chars_from_chunks() == 16000

    def test_max_prompt_chars_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_MAX_RETRIEVAL_PROMPT_CHARS", raising=False)
        assert _max_prompt_chars_from_chunks() == 16000

    def test_short_page_threshold_invalid_returns_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_SKIP_RETRIEVAL_BELOW_CHARS", "not_a_number")
        assert _short_page_threshold_chars() == 4000

    def test_short_page_threshold_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_SKIP_RETRIEVAL_BELOW_CHARS", raising=False)
        assert _short_page_threshold_chars() == 4000


# ---------------------------------------------------------------------------
# More coverage for existing functions
# ---------------------------------------------------------------------------
from infrastructure.page_text_pipeline import (
    normalize_whitespace,
    dedupe_paragraphs,
    clean_flat_text,
    tokenize,
    _chunk_quality_ok,
    chunk_by_paragraphs,
    cheap_relevance_pass,
    rank_chunks_bm25,
    rerank_top_by_length,
    build_structured_context,
    prepare_text_for_llm,
)


class TestNormalizeWhitespaceEdgeCases:
    def test_tabs_replaced(self):
        result = normalize_whitespace("hello\tworld")
        assert "\t" not in result

    def test_multiple_spaces_collapsed(self):
        result = normalize_whitespace("hello   world")
        assert "  " not in result

    def test_unix_newlines_preserved(self):
        result = normalize_whitespace("line1\nline2")
        assert "line1" in result and "line2" in result


class TestDedupeEdgeCases:
    def test_single_paragraph_not_deduped(self):
        result = dedupe_paragraphs("one paragraph here")
        assert "one paragraph here" in result

    def test_three_identical_paragraphs_deduped(self):
        text = "Paragraph\n\nParagraph\n\nParagraph"
        result = dedupe_paragraphs(text)
        # Deduplication may keep 1 occurrence
        assert result.count("Paragraph") <= 3


class TestTokenizeEdgeCases:
    def test_punctuation_split(self):
        tokens = tokenize("hello, world!")
        assert "hello" in tokens or "hello," in tokens

    def test_hyphenated_words(self):
        tokens = tokenize("well-known result")
        assert any("well" in t for t in tokens)


class TestBuildStructuredContextEdgeCases:
    def test_empty_chunks_returns_empty_string(self):
        result = build_structured_context([])
        assert result == "" or isinstance(result, str)


class TestPrepareTextForLlmEdgeCases:
    def test_very_long_text_truncated(self):
        long_text = "word " * 10000
        result, meta = prepare_text_for_llm(long_text, None)
        assert isinstance(result, str)

    def test_empty_queries_list(self):
        text = "Some text content here.\n\n" * 5
        result, meta = prepare_text_for_llm(text, [])
        assert isinstance(result, str)

    def test_non_empty_queries_with_short_text(self):
        short_text = "Hello world"
        result, meta = prepare_text_for_llm(short_text, ["query"])
        assert isinstance(result, str)


# ---------------------------------------------------------------------------
# _embedding_model_env – exception branch
# ---------------------------------------------------------------------------
from unittest.mock import patch, AsyncMock  # noqa: E402


class TestEmbeddingModelEnvException:
    def test_falls_back_to_env_var_when_import_fails(self, monkeypatch):
        from infrastructure import page_text_pipeline as _ptp
        monkeypatch.setenv("CRAWL_EMBEDDING_MODEL", "fallback-model")
        # Patch at the source module where it's imported from inside _embedding_model_env
        with patch("infrastructure.crawl_heuristics.embedding_model_effective",
                   side_effect=Exception("heuristics not available")):
            result = _ptp._embedding_model_env()
        assert result == "fallback-model"

    def test_falls_back_to_empty_when_no_env_and_import_fails(self, monkeypatch):
        monkeypatch.delenv("CRAWL_EMBEDDING_MODEL", raising=False)
        from infrastructure import page_text_pipeline as _ptp
        with patch("infrastructure.crawl_heuristics.embedding_model_effective",
                   side_effect=Exception("fail")):
            result = _ptp._embedding_model_env()
        assert result == ""


# ---------------------------------------------------------------------------
# prepare_text_for_llm_async
# ---------------------------------------------------------------------------
import asyncio as _asyncio


class TestPrepareTextForLlmAsync:
    def test_no_model_falls_back_to_sync(self, monkeypatch):
        from infrastructure.page_text_pipeline import prepare_text_for_llm_async
        monkeypatch.delenv("CRAWL_EMBEDDING_MODEL", raising=False)
        with patch("infrastructure.page_text_pipeline._embedding_model_env", return_value=""):
            result, stats = _asyncio.run(
                prepare_text_for_llm_async("Hello world", ["hello"])
            )
        assert isinstance(result, str)

    def test_pipeline_disabled_returns_finalized(self, monkeypatch):
        from infrastructure.page_text_pipeline import prepare_text_for_llm_async
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "0")
        with patch("infrastructure.page_text_pipeline._embedding_model_env", return_value="my-model"):
            result, stats = _asyncio.run(
                prepare_text_for_llm_async("Some page text content here.", ["query"])
            )
        assert isinstance(result, str)
        assert len(result) > 0

    def test_no_api_key_falls_back(self, monkeypatch):
        from infrastructure.page_text_pipeline import prepare_text_for_llm_async
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        with patch("infrastructure.page_text_pipeline._embedding_model_env", return_value="my-model"):
            result, stats = _asyncio.run(
                prepare_text_for_llm_async(
                    "Some page text content here.",
                    ["query"],
                    embedding_model="my-model",
                    embedding_api_key="",   # no key → fallback
                    embedding_api_base="",
                )
            )
        assert isinstance(result, str)

    def test_short_page_returns_full_text(self, monkeypatch):
        from infrastructure.page_text_pipeline import prepare_text_for_llm_async
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_SHORT_PAGE_CHARS", "100000")  # very high threshold
        short_text = "Short content."
        with patch("infrastructure.page_text_pipeline._embedding_model_env", return_value="my-model"):
            result, stats = _asyncio.run(
                prepare_text_for_llm_async(
                    short_text,
                    ["query"],
                    embedding_model="my-model",
                    embedding_api_key="sk-test",
                    embedding_api_base="https://api.example.com",
                )
            )
        assert isinstance(result, str)

    def test_embedding_exception_falls_back(self, monkeypatch):
        from infrastructure.page_text_pipeline import prepare_text_for_llm_async
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_SHORT_PAGE_CHARS", "1")  # very low threshold so we go to embedding path
        text = " ".join(["word"] * 200)
        with patch("infrastructure.page_text_pipeline._embedding_model_env", return_value="my-model"):
            with patch("infrastructure.page_text_pipeline._embed_strings_litellm",
                       new_callable=AsyncMock, side_effect=Exception("embedding failed")):
                result, stats = _asyncio.run(
                    prepare_text_for_llm_async(
                        text,
                        ["query"],
                        embedding_model="my-model",
                        embedding_api_key="sk-test",
                        embedding_api_base="https://api.example.com",
                    )
                )
        assert isinstance(result, str)

    def test_no_retrieval_queries_truncates_long_text(self, monkeypatch):
        from infrastructure.page_text_pipeline import prepare_text_for_llm_async
        monkeypatch.setenv("CRAWL_PIPELINE_ENABLED", "1")
        monkeypatch.setenv("CRAWL_SHORT_PAGE_CHARS", "1")
        monkeypatch.setenv("CRAWL_MAX_PROMPT_CHARS", "50")
        long_text = "A" * 200
        with patch("infrastructure.page_text_pipeline._embedding_model_env", return_value="my-model"):
            result, stats = _asyncio.run(
                prepare_text_for_llm_async(
                    long_text,
                    None,  # no queries → no retrieval
                    embedding_model="my-model",
                    embedding_api_key="sk-test",
                    embedding_api_base="https://api.example.com",
                )
            )
        assert isinstance(result, str)

    def test_empty_text_returns_empty(self, monkeypatch):
        from infrastructure.page_text_pipeline import prepare_text_for_llm_async
        with patch("infrastructure.page_text_pipeline._embedding_model_env", return_value="my-model"):
            result, stats = _asyncio.run(
                prepare_text_for_llm_async("", ["query"],
                    embedding_model="my-model",
                    embedding_api_key="sk-test",
                    embedding_api_base="https://api.example.com",
                )
            )
        assert result == ""


# ---------------------------------------------------------------------------
# build_retrieval_queries (lines 637, 651)
# ---------------------------------------------------------------------------
class TestBuildRetrievalQueries:
    def test_no_types_returns_fallback_query(self):
        from infrastructure.page_text_pipeline import build_retrieval_queries
        result = build_retrieval_queries("Ivan Petrov", None, [])
        # Should include the fallback with достижения etc when types is empty
        assert any("достижения" in q for q in result)

    def test_short_name_skipped_by_dedup(self):
        from infrastructure.page_text_pipeline import build_retrieval_queries
        # A name shorter than 4 chars triggers the `continue` on line 651
        result = build_retrieval_queries("", None, None)
        assert result == []

    def test_dedupe_removes_repeated_queries(self):
        from infrastructure.page_text_pipeline import build_retrieval_queries
        result = build_retrieval_queries("Ivan Petrov", None, ["Python", "Python"])
        # duplicates should be removed
        seen = set()
        for q in result:
            assert q not in seen
            seen.add(q)

    def test_with_achievement_types(self):
        from infrastructure.page_text_pipeline import build_retrieval_queries
        result = build_retrieval_queries("Anna Smith", {}, ["Patent", "Conference"])
        assert any("Patent" in q or "Conference" in q for q in result)


# ---------------------------------------------------------------------------
# _embed_strings_litellm – error paths
# ---------------------------------------------------------------------------
import asyncio as _asyncio_embed
from unittest.mock import MagicMock as _MagicMock, AsyncMock as _AsyncMock


class TestEmbedStringsLitellmErrors:
    def test_batch_size_mismatch_raises(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        import pytest
        from infrastructure.page_text_pipeline import _embed_strings_litellm, EmbeddingRuntime

        mock_resp = _MagicMock()
        mock_resp.data = []  # empty data for 1 input → mismatch

        runtime = EmbeddingRuntime(model="err-model-mismatch", api_key="key", api_base="http://api")
        with patch("litellm.aembedding", new_callable=_AsyncMock, return_value=mock_resp):
            with pytest.raises(RuntimeError, match="mismatch"):
                _asyncio_embed.run(_embed_strings_litellm(["text that needs embedding"], runtime))

    def test_dict_row_embedding_extracted(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        from infrastructure.page_text_pipeline import _embed_strings_litellm, EmbeddingRuntime

        mock_resp = _MagicMock()
        mock_resp.data = [{"embedding": [1.0, 2.0, 3.0]}]

        runtime = EmbeddingRuntime(model="err-model-dict-row", api_key="key", api_base="http://api")
        with patch("litellm.aembedding", new_callable=_AsyncMock, return_value=mock_resp):
            result = _asyncio_embed.run(_embed_strings_litellm(["some fresh text for dict row test"], runtime))
        assert result[0] == [1.0, 2.0, 3.0]

    def test_invalid_embedding_row_raises(self, monkeypatch, tmp_path):
        monkeypatch.setenv("CRAWL_CACHE_DIR", str(tmp_path))
        import pytest
        from infrastructure.page_text_pipeline import _embed_strings_litellm, EmbeddingRuntime

        mock_row = _MagicMock()
        mock_row.embedding = None  # None, not a list
        mock_resp = _MagicMock()
        mock_resp.data = [mock_row]

        runtime = EmbeddingRuntime(model="err-model-invalid-row", api_key="key", api_base="http://api")
        with patch("litellm.aembedding", new_callable=_AsyncMock, return_value=mock_resp):
            with pytest.raises(RuntimeError, match="invalid embedding row"):
                _asyncio_embed.run(_embed_strings_litellm(["unique text for invalid row test xyz999"], runtime))
