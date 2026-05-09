"""Unit tests for infrastructure/db_client.py."""
from __future__ import annotations

import asyncio
import os
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from infrastructure.db_client import DbClient, _normalize_dsn


# ---------------------------------------------------------------------------
# _normalize_dsn
# ---------------------------------------------------------------------------
class TestNormalizeDsn:
    def test_postgres_scheme_converted(self):
        result = _normalize_dsn("postgres://user:pass@host/db")
        assert result.startswith("postgresql://")

    def test_postgresql_scheme_unchanged(self):
        result = _normalize_dsn("postgresql://user:pass@host/db")
        assert result.startswith("postgresql://")
        assert "postgres://" not in result or "postgresql://" in result

    def test_only_first_occurrence_replaced(self):
        result = _normalize_dsn("postgres://user@host/postgres://db")
        assert result.startswith("postgresql://")


# ---------------------------------------------------------------------------
# DbClient.__init__
# ---------------------------------------------------------------------------
class TestDbClientInit:
    def test_init_with_dsn(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://user:pass@localhost/db")
        client = DbClient()
        assert client.dsn is not None
        assert client._settings_cache == {}

    def test_init_without_dsn(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        client = DbClient()
        assert client.dsn is None

    def test_postgres_scheme_normalized(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgres://user:pass@localhost/db")
        client = DbClient()
        assert client.dsn.startswith("postgresql://")

    def test_connect_timeout_default(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        monkeypatch.delenv("DB_CONNECT_TIMEOUT_SEC", raising=False)
        client = DbClient()
        assert client._connect_timeout() == 15.0

    def test_connect_timeout_custom(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        monkeypatch.setenv("DB_CONNECT_TIMEOUT_SEC", "30.0")
        client = DbClient()
        assert client._connect_timeout() == 30.0

    def test_connect_timeout_invalid_falls_back(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        monkeypatch.setenv("DB_CONNECT_TIMEOUT_SEC", "bad")
        client = DbClient()
        assert client._connect_timeout() == 15.0


# ---------------------------------------------------------------------------
# fetch_project_criteria (no DSN → returns [])
# ---------------------------------------------------------------------------
class TestFetchProjectCriteria:
    def test_returns_empty_when_no_dsn(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        client = DbClient()
        result = asyncio.run(client.fetch_project_criteria())
        assert result == []

    def test_returns_empty_on_db_error(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        with patch.object(client, '_connect', new_callable=AsyncMock, side_effect=Exception("conn error")):
            result = asyncio.run(client.fetch_project_criteria())
        assert result == []


# ---------------------------------------------------------------------------
# fetch_activity_types (no DSN → returns [])
# ---------------------------------------------------------------------------
class TestFetchActivityTypes:
    def test_returns_empty_when_no_dsn(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        client = DbClient()
        result = asyncio.run(client.fetch_activity_types())
        assert result == []

    def test_returns_empty_on_db_error(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        with patch.object(client, '_connect', new_callable=AsyncMock, side_effect=Exception("conn error")):
            result = asyncio.run(client.fetch_activity_types())
        assert result == []


# ---------------------------------------------------------------------------
# fetch_achievement_types_with_fields (no DSN → returns [])
# ---------------------------------------------------------------------------
class TestFetchAchievementTypes:
    def test_returns_empty_when_no_dsn(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        client = DbClient()
        result = asyncio.run(client.fetch_achievement_types_with_fields())
        assert result == []

    def test_returns_empty_on_db_error(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        with patch.object(client, '_connect', new_callable=AsyncMock, side_effect=Exception("err")):
            result = asyncio.run(client.fetch_achievement_types_with_fields())
        assert result == []


# ---------------------------------------------------------------------------
# fetch_researcher_profile (no DSN or no researcher_id → None)
# ---------------------------------------------------------------------------
class TestFetchResearcherProfile:
    def test_returns_none_when_no_dsn(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        client = DbClient()
        result = asyncio.run(client.fetch_researcher_profile(1))
        assert result is None

    def test_returns_none_when_no_researcher_id(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        result = asyncio.run(client.fetch_researcher_profile(0))
        assert result is None

    def test_returns_none_on_db_error(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        with patch.object(client, '_connect', new_callable=AsyncMock, side_effect=Exception("err")):
            result = asyncio.run(client.fetch_researcher_profile(42))
        assert result is None


# ---------------------------------------------------------------------------
# ping (no DSN → True, db error → False)
# ---------------------------------------------------------------------------
class TestPing:
    def test_returns_true_when_no_dsn(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        client = DbClient()
        result = asyncio.run(client.ping())
        assert result is True

    def test_returns_false_on_db_error(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        with patch.object(client, '_connect', new_callable=AsyncMock, side_effect=Exception("conn error")):
            result = asyncio.run(client.ping())
        assert result is False


# ---------------------------------------------------------------------------
# fetch_settings (no DSN → {}, uses cache on error)
# ---------------------------------------------------------------------------
class TestFetchSettings:
    def test_returns_empty_dict_when_no_dsn(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        client = DbClient()
        result = asyncio.run(client.fetch_settings())
        assert result == {}

    def test_returns_cached_settings_on_error(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        client._settings_cache = {"llm_api_key": "cached-key"}
        with patch.object(client, '_connect', new_callable=AsyncMock, side_effect=Exception("timeout")):
            result = asyncio.run(client.fetch_settings())
        assert result.get("llm_api_key") == "cached-key"

    def test_returns_empty_dict_on_error_with_no_cache(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        with patch.object(client, '_connect', new_callable=AsyncMock, side_effect=Exception("conn error")):
            result = asyncio.run(client.fetch_settings())
        assert result == {}

    def test_connect_raises_when_no_dsn(self, monkeypatch):
        monkeypatch.delenv("DATABASE_URL", raising=False)
        client = DbClient()
        with pytest.raises(RuntimeError, match="DATABASE_URL"):
            asyncio.run(client._connect())


# ---------------------------------------------------------------------------
# Success paths (mock asyncpg.connect)
# ---------------------------------------------------------------------------
def _make_mock_conn(fetch_return=None, fetchrow_return=None):
    conn = AsyncMock()
    conn.fetch = AsyncMock(return_value=fetch_return if fetch_return is not None else [])
    conn.fetchrow = AsyncMock(return_value=fetchrow_return)
    conn.execute = AsyncMock(return_value=None)
    conn.close = AsyncMock()
    return conn


class TestFetchProjectCriteriaSuccess:
    def test_returns_criteria_titles(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        row = {"title": "Machine Learning"}
        conn = _make_mock_conn(fetch_return=[row])
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.fetch_project_criteria())
        assert result == ["Machine Learning"]
        conn.close.assert_awaited_once()

    def test_returns_empty_list_on_no_rows(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        conn = _make_mock_conn(fetch_return=[])
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.fetch_project_criteria())
        assert result == []


class TestFetchActivityTypesSuccess:
    def test_returns_activity_titles(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        row = {"title": "Conference Paper"}
        conn = _make_mock_conn(fetch_return=[row])
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.fetch_activity_types())
        assert result == ["Conference Paper"]
        conn.close.assert_awaited_once()


class TestFetchAchievementTypesSuccess:
    def test_returns_achievement_types_with_description(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        type_row = {"id": 1, "title": "Patent", "description": "A patent", "icon_name": "patent"}
        field_row = {"achievement_type_id": 1, "title": "Filing date", "field_type": "date"}
        conn = AsyncMock()
        # First fetch (with description) succeeds, second fetch (fields) returns field_row
        conn.fetch = AsyncMock(side_effect=[[type_row], [field_row]])
        conn.close = AsyncMock()
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.fetch_achievement_types_with_fields())
        assert len(result) == 1
        assert result[0]["title"] == "Patent"
        assert result[0]["fields"][0]["title"] == "Filing date"

    def test_falls_back_when_description_column_missing(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        type_row_no_desc = {"id": 2, "title": "Award", "icon_name": "award"}
        conn = AsyncMock()
        # First fetch raises (no description column), second (without description) succeeds, third (fields) empty
        conn.fetch = AsyncMock(side_effect=[Exception("column missing"), [type_row_no_desc], []])
        conn.close = AsyncMock()
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.fetch_achievement_types_with_fields())
        assert len(result) == 1
        assert result[0]["description"] == ""


class TestFetchResearcherProfileSuccess:
    def test_returns_profile_when_found(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        row = {
            "id": 5, "name": "Ivan", "surname": "Petrov", "second_name": "",
            "orcid_id": "0000-0001", "openalex_id": "A12", "github": "ipetrov",
            "faculty": "CS", "subject_area": "AI",
        }
        conn = _make_mock_conn(fetchrow_return=row)
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.fetch_researcher_profile(5))
        assert result is not None
        assert result["full_name"] == "Petrov Ivan"
        conn.close.assert_awaited_once()

    def test_returns_none_when_row_not_found(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        conn = _make_mock_conn(fetchrow_return=None)
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.fetch_researcher_profile(99))
        assert result is None

    def test_includes_second_name(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        row = {
            "id": 3, "name": "Anna", "surname": "Ivanova", "second_name": "Nikolaevna",
            "orcid_id": "", "openalex_id": "", "github": "",
            "faculty": "", "subject_area": "",
        }
        conn = _make_mock_conn(fetchrow_return=row)
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.fetch_researcher_profile(3))
        assert "Nikolaevna" in result["full_name"]


class TestPingSuccess:
    def test_returns_true_when_db_responds(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        conn = _make_mock_conn()
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.ping())
        assert result is True
        conn.close.assert_awaited_once()


class TestFetchSettingsSuccess:
    def test_returns_settings_dict(self, monkeypatch):
        monkeypatch.setenv("DATABASE_URL", "postgresql://localhost/test")
        client = DbClient()
        rows = [{"key": "llm_api_key", "value": "sk-test"}]
        conn = _make_mock_conn(fetch_return=rows)
        with patch.object(client, '_connect', new_callable=AsyncMock, return_value=conn):
            result = asyncio.run(client.fetch_settings())
        assert result["llm_api_key"] == "sk-test"
        conn.close.assert_awaited_once()
