"""Unit tests for infrastructure/catalog_fetchers.py (pure helper functions)."""
from __future__ import annotations

import os
import asyncio
from unittest.mock import AsyncMock, patch, MagicMock
import pytest

# Import private helpers using module-level access
import infrastructure.catalog_fetchers as _cf


# ---------------------------------------------------------------------------
# _normalize_orcid
# ---------------------------------------------------------------------------
class TestNormalizeOrcid:
    def test_bare_id_returned_uppercase(self):
        assert _cf._normalize_orcid("0000-0001-2345-6789") == "0000-0001-2345-6789"

    def test_https_prefix_stripped(self):
        assert _cf._normalize_orcid("https://orcid.org/0000-0001-2345-6789") == "0000-0001-2345-6789"

    def test_http_prefix_stripped(self):
        assert _cf._normalize_orcid("http://orcid.org/0000-0001-2345-6789") == "0000-0001-2345-6789"

    def test_trailing_slash_stripped(self):
        assert _cf._normalize_orcid("0000-0001-2345-6789/") == "0000-0001-2345-6789"

    def test_x_check_digit_normalized(self):
        result = _cf._normalize_orcid("0000-0001-2345-678X")
        assert result == "0000-0001-2345-678X"

    def test_invalid_format_returns_none(self):
        assert _cf._normalize_orcid("not-an-orcid") is None

    def test_empty_string_returns_none(self):
        assert _cf._normalize_orcid("") is None

    def test_none_returns_none(self):
        assert _cf._normalize_orcid(None) is None

    def test_too_short_returns_none(self):
        assert _cf._normalize_orcid("0000-0001-2345") is None


# ---------------------------------------------------------------------------
# _normalize_openalex_author_id
# ---------------------------------------------------------------------------
class TestNormalizeOpenAlexAuthorId:
    def test_bare_id_returned(self):
        assert _cf._normalize_openalex_author_id("A1234567890") == "A1234567890"

    def test_full_url_extracted(self):
        result = _cf._normalize_openalex_author_id("https://openalex.org/A1234567890")
        assert result == "A1234567890"

    def test_url_with_trailing_slash(self):
        result = _cf._normalize_openalex_author_id("https://openalex.org/A1234567890/")
        assert result == "A1234567890"

    def test_empty_string_returns_none(self):
        assert _cf._normalize_openalex_author_id("") is None

    def test_none_returns_none(self):
        assert _cf._normalize_openalex_author_id(None) is None

    def test_short_id_without_a_prefix_returns_none(self):
        # IDs like "12345" without "A" prefix are not recognized
        assert _cf._normalize_openalex_author_id("12345") is None

    def test_only_whitespace_returns_none(self):
        assert _cf._normalize_openalex_author_id("   ") is None


# ---------------------------------------------------------------------------
# _work_landing_url
# ---------------------------------------------------------------------------
class TestWorkLandingUrl:
    def test_landing_page_url_from_primary_location(self):
        work = {
            "primary_location": {
                "landing_page_url": "https://doi.org/10.1234/test"
            }
        }
        assert _cf._work_landing_url(work) == "https://doi.org/10.1234/test"

    def test_pdf_url_from_primary_location_as_fallback(self):
        work = {
            "primary_location": {
                "pdf_url": "https://example.com/paper.pdf"
            }
        }
        assert _cf._work_landing_url(work) == "https://example.com/paper.pdf"

    def test_doi_used_when_no_landing_page(self):
        work = {
            "primary_location": {},
            "doi": "https://doi.org/10.1234/test",
        }
        assert _cf._work_landing_url(work) == "https://doi.org/10.1234/test"

    def test_bare_doi_gets_https_prefix(self):
        work = {
            "primary_location": {},
            "doi": "10.1234/test",
        }
        result = _cf._work_landing_url(work)
        assert result == "https://doi.org/10.1234/test"

    def test_oa_url_used_as_fallback(self):
        work = {
            "primary_location": {},
            "open_access": {"oa_url": "https://oa.example.com/paper"},
        }
        assert _cf._work_landing_url(work) == "https://oa.example.com/paper"

    def test_best_oa_location_used(self):
        work = {
            "primary_location": {},
            "best_oa_location": {"landing_page_url": "https://best-oa.example.com/paper"},
        }
        assert _cf._work_landing_url(work) == "https://best-oa.example.com/paper"

    def test_returns_none_when_no_url_available(self):
        work = {"primary_location": {}}
        assert _cf._work_landing_url(work) is None

    def test_empty_work_returns_none(self):
        assert _cf._work_landing_url({}) is None

    def test_none_primary_location_handled(self):
        work = {"primary_location": None, "doi": "https://doi.org/10.1/test"}
        result = _cf._work_landing_url(work)
        assert result == "https://doi.org/10.1/test"

    def test_non_http_url_skipped_for_landing_page(self):
        work = {
            "primary_location": {"landing_page_url": "ftp://example.com/file"},
            "doi": "https://doi.org/10.1/test",
        }
        # ftp URL should be skipped; DOI fallback used
        result = _cf._work_landing_url(work)
        assert result is not None and result.startswith("https://doi.org")


# ---------------------------------------------------------------------------
# fetch_catalog_landing_urls: env flag disables fetching
# ---------------------------------------------------------------------------
class TestFetchCatalogLandingUrls:
    def test_disabled_by_env_returns_empty(self, monkeypatch):
        monkeypatch.setenv("CRAWL_ENABLE_CATALOG_FETCH", "0")
        result = asyncio.run(
            _cf.fetch_catalog_landing_urls({"openalex_id": "A123", "orcid_id": "0000-0001-2345-6789"})
        )
        assert result == []

    def test_disabled_by_false_value(self, monkeypatch):
        monkeypatch.setenv("CRAWL_ENABLE_CATALOG_FETCH", "false")
        result = asyncio.run(
            _cf.fetch_catalog_landing_urls({"openalex_id": "A123"})
        )
        assert result == []

    def test_none_profile_disabled_returns_empty(self, monkeypatch):
        monkeypatch.setenv("CRAWL_ENABLE_CATALOG_FETCH", "0")
        result = asyncio.run(
            _cf.fetch_catalog_landing_urls(None)
        )
        assert result == []

    def test_orcid_profile_prepended_when_enabled(self, monkeypatch):
        monkeypatch.setenv("CRAWL_ENABLE_CATALOG_FETCH", "1")
        monkeypatch.setenv("CRAWL_ORCID_PROFILE_URL", "1")

        async def mock_resolve_from_orcid(oid):
            return None  # no OpenAlex author found via ORCID

        async def mock_fetch_works(author_id):
            return []

        with patch.object(_cf, "_openalex_resolve_author_id_from_orcid", side_effect=mock_resolve_from_orcid), \
             patch.object(_cf, "_openalex_fetch_work_urls_for_author", side_effect=mock_fetch_works):
            result = asyncio.run(
                _cf.fetch_catalog_landing_urls({"orcid_id": "0000-0001-2345-6789"})
            )
        # ORCID profile URL should be prepended
        assert any("orcid.org" in u for u in result)

    def test_openalex_id_used_directly(self, monkeypatch):
        monkeypatch.setenv("CRAWL_ENABLE_CATALOG_FETCH", "1")
        monkeypatch.setenv("CRAWL_ORCID_PROFILE_URL", "0")

        async def mock_fetch_works(author_id):
            return ["https://doi.org/10.1/test1", "https://arxiv.org/abs/1"]

        with patch.object(_cf, "_openalex_fetch_work_urls_for_author", side_effect=mock_fetch_works):
            result = asyncio.run(
                _cf.fetch_catalog_landing_urls({"openalex_id": "A1234567890"})
            )
        assert "https://doi.org/10.1/test1" in result
        assert "https://arxiv.org/abs/1" in result

    def test_duplicate_urls_deduplicated(self, monkeypatch):
        monkeypatch.setenv("CRAWL_ENABLE_CATALOG_FETCH", "1")
        monkeypatch.setenv("CRAWL_ORCID_PROFILE_URL", "0")

        async def mock_fetch_works(author_id):
            return ["https://doi.org/10.1/a", "https://doi.org/10.1/a"]

        # ID must be >= 8 chars starting with "A" to pass _normalize_openalex_author_id
        with patch.object(_cf, "_openalex_fetch_work_urls_for_author", side_effect=mock_fetch_works):
            result = asyncio.run(
                _cf.fetch_catalog_landing_urls({"openalex_id": "A1234567890"})
            )
        assert result.count("https://doi.org/10.1/a") == 1


# ---------------------------------------------------------------------------
# _openalex_headers
# ---------------------------------------------------------------------------
class TestOpenAlexHeaders:
    def test_returns_dict_with_user_agent(self):
        import infrastructure.catalog_fetchers as _cf
        headers = _cf._openalex_headers()
        assert "User-Agent" in headers
        assert "Accept" in headers
        assert "application/json" in headers["Accept"]


# ---------------------------------------------------------------------------
# _openalex_resolve_author_id_from_orcid - mock httpx
# ---------------------------------------------------------------------------
class TestOpenAlexResolveAuthorIdFromOrcid:
    def test_returns_author_id_on_success(self):
        import asyncio
        from unittest.mock import AsyncMock, MagicMock, patch
        import infrastructure.catalog_fetchers as _cf

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "results": [{"id": "https://openalex.org/A1234567890"}]
        }

        mock_client = MagicMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(return_value=mock_response)

        with patch("infrastructure.catalog_fetchers.httpx.AsyncClient", return_value=mock_client):
            result = asyncio.run(_cf._openalex_resolve_author_id_from_orcid("0000-0001-2345-6789"))

        assert result == "A1234567890"

    def test_returns_none_on_non_200(self):
        import asyncio
        from unittest.mock import AsyncMock, MagicMock, patch
        import infrastructure.catalog_fetchers as _cf

        mock_response = MagicMock()
        mock_response.status_code = 404

        mock_client = MagicMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(return_value=mock_response)

        with patch("infrastructure.catalog_fetchers.httpx.AsyncClient", return_value=mock_client):
            result = asyncio.run(_cf._openalex_resolve_author_id_from_orcid("0000-0001-2345-6789"))

        assert result is None

    def test_returns_none_on_exception(self):
        import asyncio
        from unittest.mock import AsyncMock, MagicMock, patch
        import infrastructure.catalog_fetchers as _cf

        mock_client = MagicMock()
        mock_client.__aenter__ = AsyncMock(side_effect=Exception("timeout"))
        mock_client.__aexit__ = AsyncMock(return_value=False)

        with patch("infrastructure.catalog_fetchers.httpx.AsyncClient", return_value=mock_client):
            result = asyncio.run(_cf._openalex_resolve_author_id_from_orcid("0000-0001-2345-6789"))

        assert result is None

    def test_returns_none_when_no_results(self):
        import asyncio
        from unittest.mock import AsyncMock, MagicMock, patch
        import infrastructure.catalog_fetchers as _cf

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"results": []}

        mock_client = MagicMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(return_value=mock_response)

        with patch("infrastructure.catalog_fetchers.httpx.AsyncClient", return_value=mock_client):
            result = asyncio.run(_cf._openalex_resolve_author_id_from_orcid("0000-0001-2345-6789"))

        assert result is None


# ---------------------------------------------------------------------------
# _openalex_fetch_work_urls_for_author - mock httpx
# ---------------------------------------------------------------------------
class TestOpenAlexFetchWorkUrls:
    def test_returns_urls_from_works(self):
        import asyncio
        from unittest.mock import AsyncMock, MagicMock, patch
        import infrastructure.catalog_fetchers as _cf

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "results": [
                {"primary_location": {"landing_page_url": "https://doi.org/10.1/paper1"}},
                {"primary_location": {"landing_page_url": "https://doi.org/10.1/paper2"}},
            ],
            "meta": {"next_cursor": None}
        }

        mock_client = MagicMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(return_value=mock_response)

        with patch("infrastructure.catalog_fetchers.httpx.AsyncClient", return_value=mock_client):
            result = asyncio.run(_cf._openalex_fetch_work_urls_for_author("A1234567890"))

        assert "https://doi.org/10.1/paper1" in result
        assert "https://doi.org/10.1/paper2" in result

    def test_returns_empty_on_non_200(self):
        import asyncio
        from unittest.mock import AsyncMock, MagicMock, patch
        import infrastructure.catalog_fetchers as _cf

        mock_response = MagicMock()
        mock_response.status_code = 503

        mock_client = MagicMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(return_value=mock_response)

        with patch("infrastructure.catalog_fetchers.httpx.AsyncClient", return_value=mock_client):
            result = asyncio.run(_cf._openalex_fetch_work_urls_for_author("A1234567890"))

        assert result == []

    def test_handles_exception(self):
        import asyncio
        from unittest.mock import AsyncMock, MagicMock, patch
        import infrastructure.catalog_fetchers as _cf

        mock_client = MagicMock()
        mock_client.__aenter__ = AsyncMock(side_effect=Exception("network error"))
        mock_client.__aexit__ = AsyncMock(return_value=False)

        with patch("infrastructure.catalog_fetchers.httpx.AsyncClient", return_value=mock_client):
            result = asyncio.run(_cf._openalex_fetch_work_urls_for_author("A1234567890"))

        assert result == []

    def test_pagination_with_cursor(self):
        import asyncio
        from unittest.mock import AsyncMock, MagicMock, patch
        import infrastructure.catalog_fetchers as _cf

        first_response = MagicMock()
        first_response.status_code = 200
        first_response.json.return_value = {
            "results": [{"primary_location": {"landing_page_url": "https://doi.org/page1"}}],
            "meta": {"next_cursor": "cursor123"}
        }

        second_response = MagicMock()
        second_response.status_code = 200
        second_response.json.return_value = {
            "results": [{"primary_location": {"landing_page_url": "https://doi.org/page2"}}],
            "meta": {"next_cursor": None}
        }

        mock_client = MagicMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(side_effect=[first_response, second_response])

        with patch("infrastructure.catalog_fetchers.httpx.AsyncClient", return_value=mock_client):
            result = asyncio.run(_cf._openalex_fetch_work_urls_for_author("A1234567890"))

        assert "https://doi.org/page1" in result
        assert "https://doi.org/page2" in result
