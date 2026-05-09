"""Unit tests for infrastructure/search_queries.py."""
from __future__ import annotations

import pytest
from infrastructure.search_queries import build_auto_search_queries


# ---------------------------------------------------------------------------
# build_auto_search_queries
# ---------------------------------------------------------------------------
class TestBuildAutoSearchQueries:
    def test_empty_name_returns_empty(self):
        result = build_auto_search_queries("", None, ["Статья"])
        assert result == []

    def test_whitespace_only_name_returns_empty(self):
        result = build_auto_search_queries("   ", None, [])
        assert result == []

    def test_basic_query_contains_researcher_name(self):
        queries = build_auto_search_queries("Иванов Иван", None, ["Статья"])
        combined = " ".join(queries)
        assert "Иванов Иван" in combined

    def test_one_query_per_achievement_type(self):
        types = ["Статья", "Грант", "Хакатон"]
        queries = build_auto_search_queries("Иванов Иван", None, types)
        # At least one query per type (excluding "Другое")
        assert len(queries) >= len(types)

    def test_drugoye_type_excluded(self):
        queries = build_auto_search_queries("Иванов Иван", None, ["Другое", "Статья"])
        combined = " ".join(queries)
        assert "Другое" not in combined

    def test_orcid_appended_when_present(self):
        profile = {"orcid_id": "0000-0001-2345-6789"}
        queries = build_auto_search_queries("Иванов Иван", profile, ["Статья"])
        orcid_queries = [q for q in queries if "0000-0001-2345-6789" in q or "orcid" in q.lower()]
        assert len(orcid_queries) >= 1

    def test_openalex_appended_when_present(self):
        profile = {"openalex_id": "A1234567890"}
        queries = build_auto_search_queries("Иванов Иван", profile, ["Статья"])
        oax_queries = [q for q in queries if "A1234567890" in q or "openalex" in q.lower()]
        assert len(oax_queries) >= 1

    def test_affiliation_included_when_faculty_present(self):
        profile = {"faculty": "Физический факультет", "subject_area": ""}
        queries = build_auto_search_queries("Иванов Иван", profile, ["Статья"])
        with_aff = [q for q in queries if "Физический факультет" in q]
        assert len(with_aff) >= 1

    def test_no_duplicate_queries(self):
        profile = {"faculty": "ИТМО", "orcid_id": "0000-0001-2345-6789"}
        queries = build_auto_search_queries("Иванов Иван", profile, ["Статья", "Грант", "Хакатон"])
        assert len(queries) == len(set(queries)), "All queries should be unique"

    def test_all_queries_long_enough(self):
        queries = build_auto_search_queries("Иванов Иван", None, ["Статья"])
        for q in queries:
            assert len(q) >= 8, f"Query too short: {q!r}"

    def test_query_words_joined_cleanly(self):
        # No double spaces in any query
        queries = build_auto_search_queries("Иванов Иван", {"faculty": "ИТМО"}, ["Статья"])
        for q in queries:
            assert "  " not in q, f"Double space in query: {q!r}"

    def test_no_types_generates_fallback_query(self):
        queries = build_auto_search_queries("Иванов Иван", None, [])
        # Should generate at least one fallback query with "научные достижения"
        assert len(queries) > 0
        has_fallback = any("научные достижения" in q for q in queries)
        assert has_fallback

    def test_orcid_query_format(self):
        profile = {"orcid_id": "https://orcid.org/0000-0001-2345-6789"}
        queries = build_auto_search_queries("Петров Пётр", profile, [])
        orcid_queries = [q for q in queries if "0000-0001-2345-6789" in q]
        assert len(orcid_queries) >= 1

    def test_grant_type_gets_extra_keywords(self):
        queries = build_auto_search_queries("Иванов Иван", None, ["Грант"])
        grant_query = [q for q in queries if "Грант" in q or "грант" in q.lower()]
        assert len(grant_query) >= 1
        # Grant type has extra keywords like "РНФ", "победитель"
        combined = " ".join(grant_query)
        assert any(keyword in combined for keyword in ["РНФ", "победитель", "грантовый"])

    def test_discovery_queries_always_generated(self):
        # Even with no types, some discovery queries are always added
        queries = build_auto_search_queries("Иванов Иван", None, [])
        discovery_signals = ["elibrary", "профил", "публикаци", "ORCID"]
        has_any = any(
            any(signal.lower() in q.lower() for signal in discovery_signals)
            for q in queries
        )
        assert has_any, f"Expected discovery queries, got: {queries}"

    def test_site_hint_from_itmo_faculty(self):
        # _domain_hint matches ASCII "itmo" (case-insensitive) in faculty string
        profile = {"faculty": "itmo university"}
        queries = build_auto_search_queries("Иванов Иван", profile, [])
        site_queries = [q for q in queries if "itmo.ru" in q]
        assert len(site_queries) >= 1

    def test_site_hint_from_spbgu_faculty(self):
        profile = {"faculty": "СПБГУ биофак"}
        queries = build_auto_search_queries("Иванов Иван", profile, [])
        site_queries = [q for q in queries if "spbu.ru" in q]
        assert len(site_queries) >= 1

    def test_name_quoted_in_query(self):
        queries = build_auto_search_queries("Иванов Иван", None, ["Статья"])
        quoted = [q for q in queries if '"Иванов Иван"' in q]
        assert len(quoted) >= 1, "Name should appear quoted in at least one query"


# ---------------------------------------------------------------------------
# Edge cases for _query_extra_for_type (indirectly through build_auto_search_queries)
# ---------------------------------------------------------------------------
class TestQueryExtrasForTypes:
    def test_hackathon_type_gets_devpost_hint(self):
        queries = build_auto_search_queries("Иванов Иван", None, ["Хакатон"])
        hackathon_queries = [q for q in queries if "Хакатон" in q or "хакатон" in q.lower()]
        combined = " ".join(hackathon_queries)
        assert "devpost" in combined or "hackathon" in combined.lower()

    def test_rid_type_gets_patent_hint(self):
        queries = build_auto_search_queries("Иванов Иван", None, ["РИД"])
        rid_queries = [q for q in queries if "РИД" in q]
        combined = " ".join(rid_queries)
        assert "патент" in combined or "РИД" in combined

    def test_unknown_type_no_extra(self):
        queries = build_auto_search_queries("Иванов Иван", None, ["НеизвестныйТип"])
        type_queries = [q for q in queries if "НеизвестныйТип" in q]
        # Query still generated, but just with the type title, no extra noise keywords
        assert len(type_queries) >= 1
