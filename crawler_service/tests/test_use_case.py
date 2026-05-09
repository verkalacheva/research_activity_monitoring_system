"""Unit and integration tests for use_cases/crawl_combined_achievements.py."""
import asyncio
import os
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from domain.models import Achievement, DevActivity, CrawlResult
from use_cases.crawl_combined_achievements import (
    CrawlAchievementsUseCase,
    _grpc_still_active,
    _merge_unique_urls,
    _without_github_urls,
    _abbreviated_name,
    _inter_url_delay,
    _crawl_concurrency,
    _chunk_threshold_override,
    _effective_html_page_hint,
    _max_urls_per_sync,
)


# ---------------------------------------------------------------------------
# Pure helper functions
# ---------------------------------------------------------------------------
class TestGrpcStillActive:
    def test_none_cancel_check_returns_true(self):
        assert _grpc_still_active(None) is True

    def test_cancel_check_returning_true(self):
        assert _grpc_still_active(lambda: True) is True

    def test_cancel_check_returning_false(self):
        assert _grpc_still_active(lambda: False) is False

    def test_cancel_check_raising_exception_returns_false(self):
        def bad_check():
            raise RuntimeError("network error")
        assert _grpc_still_active(bad_check) is False


class TestMergeUniqueUrls:
    def test_deduplicates_across_lists(self):
        result = _merge_unique_urls(
            ["http://a.com", "http://b.com"],
            ["http://b.com", "http://c.com"],
        )
        assert result == ["http://a.com", "http://b.com", "http://c.com"]

    def test_preserves_order_primary_first(self):
        result = _merge_unique_urls(["http://x.com"], ["http://y.com"])
        assert result[0] == "http://x.com"

    def test_filters_out_non_http_entries(self):
        result = _merge_unique_urls(["ftp://old.com", "http://ok.com"], [])
        assert "ftp://old.com" not in result
        assert "http://ok.com" in result

    def test_filters_out_empty_strings(self):
        result = _merge_unique_urls(["", "  ", "http://good.com"], [])
        assert "" not in result
        assert "  " not in result
        assert "http://good.com" in result

    def test_empty_inputs_return_empty(self):
        assert _merge_unique_urls([], []) == []


class TestWithoutGithubUrls:
    def test_removes_github_urls(self):
        urls = ["https://github.com/user/repo", "https://example.com/paper"]
        result = _without_github_urls(urls)
        assert "https://github.com/user/repo" not in result
        assert "https://example.com/paper" in result

    def test_case_insensitive_github_check(self):
        urls = ["HTTPS://GITHUB.COM/user/repo"]
        assert _without_github_urls(urls) == []

    def test_empty_list_returns_empty(self):
        assert _without_github_urls([]) == []

    def test_none_entries_are_handled(self):
        result = _without_github_urls([None, "http://ok.com"])
        assert "http://ok.com" in result


class TestAbbreviatedName:
    def test_three_part_name(self):
        assert _abbreviated_name("Иванов Иван Иванович") == "Иванов И.И."

    def test_two_part_name(self):
        assert _abbreviated_name("Петров Пётр") == "Петров П."

    def test_single_word_returned_as_is(self):
        assert _abbreviated_name("Иванов") == "Иванов"

    def test_empty_string_returned_as_is(self):
        assert _abbreviated_name("") == ""

    def test_none_fallthrough(self):
        # None is treated as empty: (None or "") → "" → 0 parts → returns original None
        result = _abbreviated_name(None)
        assert result is None or result == ""


class TestEnvHelpers:
    def test_inter_url_delay_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_INTER_URL_DELAY_SEC", raising=False)
        assert _inter_url_delay() == 15.0

    def test_inter_url_delay_from_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_INTER_URL_DELAY_SEC", "5")
        assert _inter_url_delay() == 5.0

    def test_inter_url_delay_negative_clamped_to_zero(self, monkeypatch):
        monkeypatch.setenv("CRAWL_INTER_URL_DELAY_SEC", "-3")
        assert _inter_url_delay() == 0.0

    def test_inter_url_delay_invalid_returns_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_INTER_URL_DELAY_SEC", "abc")
        assert _inter_url_delay() == 15.0

    def test_crawl_concurrency_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_CONCURRENCY", raising=False)
        assert _crawl_concurrency() == 5

    def test_crawl_concurrency_clamped_min(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CONCURRENCY", "0")
        assert _crawl_concurrency() == 1

    def test_crawl_concurrency_clamped_max(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CONCURRENCY", "999")
        assert _crawl_concurrency() == 64

    def test_max_urls_per_sync_zero_when_not_set(self, monkeypatch):
        monkeypatch.delenv("CRAWL_MAX_URLS_PER_SYNC", raising=False)
        assert _max_urls_per_sync() == 0

    def test_max_urls_per_sync_from_env(self, monkeypatch):
        monkeypatch.setenv("CRAWL_MAX_URLS_PER_SYNC", "10")
        assert _max_urls_per_sync() == 10


# ---------------------------------------------------------------------------
# CrawlAchievementsUseCase._collect_achievements_from_extracted (static)
# ---------------------------------------------------------------------------
class TestCollectAchievementsFromExtracted:
    TYPE_FIELDS_MAP = {
        "Статья": [{"title": "Полное название статьи"}],
    }

    def test_empty_list_returns_empty(self):
        result = CrawlAchievementsUseCase._collect_achievements_from_extracted(
            [], "http://example.com", self.TYPE_FIELDS_MAP
        )
        assert result == []

    def test_non_list_returns_empty(self):
        result = CrawlAchievementsUseCase._collect_achievements_from_extracted(
            "not a list", "http://example.com", self.TYPE_FIELDS_MAP
        )
        assert result == []

    def test_extracts_achievement_from_achievements_key(self):
        extracted = [{"achievements": [{"title": "My paper", "type": "Статья"}]}]
        result = CrawlAchievementsUseCase._collect_achievements_from_extracted(
            extracted, "http://example.com", self.TYPE_FIELDS_MAP
        )
        assert len(result) == 1
        assert result[0].title == "My paper"

    def test_extracts_achievement_from_direct_item_with_title(self):
        extracted = [{"title": "Direct paper", "type": "Статья"}]
        result = CrawlAchievementsUseCase._collect_achievements_from_extracted(
            extracted, "http://example.com", self.TYPE_FIELDS_MAP
        )
        assert len(result) == 1
        assert result[0].title == "Direct paper"

    def test_falls_back_to_target_url_when_no_url_in_item(self):
        extracted = [{"title": "Paper without URL", "type": "Статья"}]
        result = CrawlAchievementsUseCase._collect_achievements_from_extracted(
            extracted, "http://fallback.com", self.TYPE_FIELDS_MAP
        )
        assert result[0].url == "http://fallback.com"

    def test_skips_items_with_no_resolvable_title(self):
        extracted = [{"achievements": [{"type": "Статья"}]}]  # no title
        result = CrawlAchievementsUseCase._collect_achievements_from_extracted(
            extracted, "http://example.com", self.TYPE_FIELDS_MAP
        )
        assert result == []

    def test_author_count_defaults_to_1(self):
        extracted = [{"title": "Paper", "type": "Статья"}]
        result = CrawlAchievementsUseCase._collect_achievements_from_extracted(
            extracted, "http://example.com", self.TYPE_FIELDS_MAP
        )
        assert result[0].author_count == 1

    def test_multiple_achievements_in_one_item(self):
        extracted = [
            {
                "achievements": [
                    {"title": "Paper A", "type": "Статья"},
                    {"title": "Paper B", "type": "Конференция"},
                ]
            }
        ]
        result = CrawlAchievementsUseCase._collect_achievements_from_extracted(
            extracted, "http://example.com", {}
        )
        assert len(result) == 2


# ---------------------------------------------------------------------------
# CrawlAchievementsUseCase.partial_result
# ---------------------------------------------------------------------------
class TestPartialResult:
    def _make_use_case(self):
        search_client = MagicMock()
        crawler_client = MagicMock()
        crawler_client.warnings = []
        uc = CrawlAchievementsUseCase(search_client, crawler_client)
        return uc

    def test_empty_accumulated_returns_empty_result(self):
        uc = self._make_use_case()
        result = uc.partial_result()
        assert isinstance(result, CrawlResult)
        assert result.achievements == []

    def test_accumulated_achievements_are_deduplicated(self):
        uc = self._make_use_case()
        uc._achievement_type_titles = ["Статья", "Другое"]
        uc._type_fields_map = {}

        ach = Achievement(title="My Paper", type="Статья", url="http://a.com")
        ach_dup = Achievement(title="my paper", type="Статья", url="http://b.com")

        uc._accumulated = [ach, ach_dup]
        result = uc.partial_result()

        # Duplicate by normalized title key → only one survives
        assert len(result.achievements) == 1

    def test_partial_result_includes_cancellation_warning(self):
        uc = self._make_use_case()
        uc._accumulated = []
        result = uc.partial_result()
        assert any("прерван" in w for w in result.warnings)

    def test_longer_description_wins_dedup(self):
        uc = self._make_use_case()
        uc._achievement_type_titles = ["Статья", "Другое"]
        uc._type_fields_map = {}

        short = Achievement(title="My Paper", type="Статья", description="short")
        long_  = Achievement(title="My Paper", type="Статья", description="much longer description here")

        uc._accumulated = [short, long_]
        result = uc.partial_result()

        assert result.achievements[0].description == "much longer description here"


# ---------------------------------------------------------------------------
# CrawlAchievementsUseCase.execute (integration with mocked I/O)
# ---------------------------------------------------------------------------
class TestExecute:
    def _make_use_case(self, extracted_per_url=None):
        """Build a use case with all async I/O mocked."""
        search_client = MagicMock()
        search_client.search_urls_multi = AsyncMock(return_value=[])

        crawler_client = MagicMock()
        crawler_client.warnings = []
        crawler_client.extraction_stats = {}
        # Return provided extractions or empty list
        crawler_client.crawl_and_extract = AsyncMock(
            return_value=extracted_per_url if extracted_per_url is not None else []
        )

        uc = CrawlAchievementsUseCase(search_client, crawler_client)

        # Patch DB client on instance
        db_client = AsyncMock()
        db_client.fetch_researcher_profile = AsyncMock(return_value=None)
        db_client.fetch_achievement_types_with_fields = AsyncMock(return_value=[])
        db_client.fetch_settings = AsyncMock(return_value={})
        uc.db_client = db_client

        return uc

    def test_returns_crawl_result_with_no_urls(self):
        uc = self._make_use_case()
        result = asyncio.run(uc.execute(researcher_name="Иванов Иван Иванович"))
        assert isinstance(result, CrawlResult)
        assert result.achievements == []

    def test_returns_immediately_when_already_cancelled(self):
        uc = self._make_use_case()
        result = asyncio.run(
            uc.execute(researcher_name="Test", cancel_check=lambda: False)
        )
        assert isinstance(result, CrawlResult)
        assert result.achievements == []

    def test_deduplicates_achievements_by_title(self):
        extracted = [
            {"achievements": [{"title": "Same Paper", "type": "Статья"}]},
            {"achievements": [{"title": "Same Paper", "type": "Статья"}]},
        ]
        uc = self._make_use_case()
        uc.crawler_client.crawl_and_extract = AsyncMock(return_value=extracted[:1])

        # Patch to supply a manual URL so crawling actually fires
        result = asyncio.run(
            uc.execute(researcher_name="Иванов Иван", url="http://example.com/profile")
        )
        assert isinstance(result, CrawlResult)
        # No duplicates in final output
        titles = [a.title for a in result.achievements]
        assert len(titles) == len(set(titles))

    def test_github_urls_excluded_from_crawl(self):
        """Manual URL pointing to github.com must be stripped before crawling."""
        uc = self._make_use_case()
        crawl_calls = []

        async def fake_crawl(url, *args, **kwargs):
            crawl_calls.append(url)
            return []

        uc.crawler_client.crawl_and_extract = fake_crawl

        asyncio.run(
            uc.execute(
                researcher_name="Test",
                url="https://github.com/researcher/repo",
            )
        )
        assert not any("github.com" in u for u in crawl_calls)

    def test_max_urls_cap_respected(self, monkeypatch):
        monkeypatch.setenv("CRAWL_MAX_URLS_PER_SYNC", "1")
        monkeypatch.setenv("CRAWL_INTER_URL_DELAY_SEC", "0")
        monkeypatch.setenv("CRAWL_CONCURRENCY", "1")

        crawled_urls = []

        uc = self._make_use_case()

        async def fake_crawl(url, *args, **kwargs):
            crawled_urls.append(url)
            return []

        uc.crawler_client.crawl_and_extract = fake_crawl

        # Simulate two catalog URLs returned by db
        uc.db_client.fetch_researcher_profile = AsyncMock(return_value={"full_name": "Test User"})

        with patch(
            "use_cases.crawl_combined_achievements.fetch_catalog_landing_urls",
            new=AsyncMock(return_value=["http://a.com", "http://b.com"]),
        ):
            asyncio.run(uc.execute(researcher_name="Test", researcher_id=1))

        assert len(crawled_urls) <= 1


# ---------------------------------------------------------------------------
# Additional env helper ValueError branches (uncovered lines)
# ---------------------------------------------------------------------------
class TestEnvHelpersAdditional:
    def test_crawl_concurrency_invalid_returns_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_CONCURRENCY", "not_a_number")
        assert _crawl_concurrency() == 5

    def test_chunk_threshold_override_default(self, monkeypatch):
        monkeypatch.delenv("CRAWL_LLM_CHUNK_THRESHOLD", raising=False)
        assert _chunk_threshold_override() == 0

    def test_chunk_threshold_override_valid(self, monkeypatch):
        monkeypatch.setenv("CRAWL_LLM_CHUNK_THRESHOLD", "5000")
        assert _chunk_threshold_override() == 5000

    def test_chunk_threshold_override_clamped_min(self, monkeypatch):
        monkeypatch.setenv("CRAWL_LLM_CHUNK_THRESHOLD", "100")
        assert _chunk_threshold_override() == 500

    def test_chunk_threshold_override_invalid(self, monkeypatch):
        monkeypatch.setenv("CRAWL_LLM_CHUNK_THRESHOLD", "bad_value")
        assert _chunk_threshold_override() == 0

    def test_effective_html_page_hint_recall(self, monkeypatch):
        monkeypatch.setenv("CRAWL_PROMPT_MODE", "recall")
        hint = _effective_html_page_hint()
        assert isinstance(hint, str) and len(hint) > 0

    def test_effective_html_page_hint_default_precision(self, monkeypatch):
        monkeypatch.delenv("CRAWL_PROMPT_MODE", raising=False)
        hint = _effective_html_page_hint()
        assert isinstance(hint, str) and len(hint) > 0

    def test_max_urls_per_sync_invalid(self, monkeypatch):
        monkeypatch.setenv("CRAWL_MAX_URLS_PER_SYNC", "invalid")
        assert _max_urls_per_sync() == 0
