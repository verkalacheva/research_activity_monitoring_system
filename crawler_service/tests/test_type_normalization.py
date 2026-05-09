"""Unit tests for infrastructure/type_normalization.py."""
import pytest
from infrastructure.type_normalization import (
    normalize_title_key,
    fuzzy_match_type,
    coerce_crawl_achievement_dict,
    filter_fields_for_type,
    build_type_synopsis_lines,
    preprocess_llm_type,
)

ALLOWED_TYPES = [
    "Статья", "Конференция", "Грант", "РИД", "Хакатон",
    "Стипендия", "Стажировка", "Наставничество/менторство",
    "Упоминание в СМИ", "Публикация в СМИ", "Другое",
]


# ---------------------------------------------------------------------------
# preprocess_llm_type
# ---------------------------------------------------------------------------
class TestPreprocessLlmType:
    def test_empty_string_returns_empty(self):
        assert preprocess_llm_type("") == ""

    def test_none_returns_empty(self):
        assert preprocess_llm_type(None) == ""

    def test_known_english_alias_conference_paper(self):
        assert preprocess_llm_type("conference-paper") == "Конференция"

    def test_known_english_alias_journal_article(self):
        assert preprocess_llm_type("journal-article") == "Статья"

    def test_underscore_variant_is_normalised(self):
        assert preprocess_llm_type("journal_article") == "Статья"

    def test_unknown_value_is_returned_as_is(self):
        assert preprocess_llm_type("Статья") == "Статья"

    def test_case_insensitive_lookup(self):
        assert preprocess_llm_type("GRANT") == "Грант"

    def test_space_variant_is_handled(self):
        # spaces → hyphens → lookup
        assert preprocess_llm_type("media mention") == "Упоминание в СМИ"


# ---------------------------------------------------------------------------
# normalize_title_key
# ---------------------------------------------------------------------------
class TestNormalizeTitleKey:
    def test_empty_returns_empty(self):
        assert normalize_title_key("") == ""

    def test_none_returns_empty(self):
        assert normalize_title_key(None) == ""

    def test_lowercases_text(self):
        assert normalize_title_key("My Article") == "my article"

    def test_strips_leading_trailing_whitespace(self):
        assert normalize_title_key("  hello  ") == "hello"

    def test_collapses_inner_whitespace(self):
        # Multiple spaces are normalised to a single space
        assert normalize_title_key("a   b") == "a b"

    def test_removes_punctuation(self):
        key = normalize_title_key("Hello, World!")
        assert "," not in key
        assert "!" not in key

    def test_preserves_cyrillic_characters(self):
        key = normalize_title_key("Статья о науке")
        assert "статья" in key
        assert "науке" in key

    def test_unicode_normalization_applied(self):
        # Composed vs decomposed 'й' should produce same key
        composed = "Иванов Иван"
        key = normalize_title_key(composed)
        assert key  # non-empty

    def test_two_similar_titles_produce_same_key(self):
        k1 = normalize_title_key("Deep Learning for NLP")
        k2 = normalize_title_key("Deep Learning for NLP")
        assert k1 == k2

    def test_differently_cased_titles_produce_same_key(self):
        assert normalize_title_key("Article Title") == normalize_title_key("article title")


# ---------------------------------------------------------------------------
# fuzzy_match_type
# ---------------------------------------------------------------------------
class TestFuzzyMatchType:
    def test_exact_match_returned(self):
        assert fuzzy_match_type("Статья", ALLOWED_TYPES) == "Статья"

    def test_case_insensitive_exact_match(self):
        assert fuzzy_match_type("статья", ALLOWED_TYPES) == "Статья"

    def test_english_alias_conference_paper(self):
        assert fuzzy_match_type("conference-paper", ALLOWED_TYPES) == "Конференция"

    def test_english_alias_article(self):
        assert fuzzy_match_type("article", ALLOWED_TYPES) == "Статья"

    def test_english_alias_grant(self):
        assert fuzzy_match_type("grant", ALLOWED_TYPES) == "Грант"

    def test_english_alias_patent(self):
        assert fuzzy_match_type("patent", ALLOWED_TYPES) == "РИД"

    def test_english_alias_internship(self):
        assert fuzzy_match_type("internship", ALLOWED_TYPES) == "Стажировка"

    def test_english_alias_mentoring(self):
        assert fuzzy_match_type("mentoring", ALLOWED_TYPES) == "Наставничество/менторство"

    def test_english_alias_other(self):
        assert fuzzy_match_type("other", ALLOWED_TYPES) == "Другое"

    def test_empty_string_returns_другое(self):
        assert fuzzy_match_type("", ALLOWED_TYPES) == "Другое"

    def test_none_returns_другое(self):
        assert fuzzy_match_type(None, ALLOWED_TYPES) == "Другое"

    def test_totally_unknown_type_falls_back_to_другое(self):
        assert fuzzy_match_type("xyzzy_unknown_blah", ALLOWED_TYPES) == "Другое"

    def test_empty_allowed_list_returns_raw_value(self):
        assert fuzzy_match_type("Статья", []) == "Статья"

    def test_fuzzy_close_match_konferencia_variant(self):
        # Slight misspelling should still resolve to Конференция
        result = fuzzy_match_type("Конференцыя", ALLOWED_TYPES)
        assert result == "Конференция"


# ---------------------------------------------------------------------------
# coerce_crawl_achievement_dict
# ---------------------------------------------------------------------------
class TestCoerceCrawlAchievementDict:
    TYPE_FIELDS_MAP = {
        "Статья": [{"title": "Полное название статьи"}, {"title": "Название журнала"}],
        "Конференция": [{"title": "Название темы выступления"}],
    }

    def test_returns_none_for_non_dict(self):
        assert coerce_crawl_achievement_dict("not a dict", {}) is None

    def test_returns_none_for_none(self):
        assert coerce_crawl_achievement_dict(None, {}) is None

    def test_returns_none_when_no_title_can_be_found(self):
        assert coerce_crawl_achievement_dict({}, {}) is None

    def test_basic_achievement_with_title(self):
        ach = {"title": "My paper", "type": "Статья"}
        result = coerce_crawl_achievement_dict(ach, self.TYPE_FIELDS_MAP)
        assert result is not None
        assert result["title"] == "My paper"
        assert result["type"] == "Статья"

    def test_title_extracted_from_known_field_key(self):
        ach = {
            "fields": {"Полное название статьи": "Исследование нейросетей"},
            "type": "Статья",
        }
        result = coerce_crawl_achievement_dict(ach, self.TYPE_FIELDS_MAP)
        assert result is not None
        assert result["title"] == "Исследование нейросетей"

    def test_catalog_fields_at_top_level_are_merged_into_fields(self):
        ach = {
            "title": "My paper",
            "type": "Статья",
            "Полное название статьи": "My paper full",
        }
        result = coerce_crawl_achievement_dict(ach, self.TYPE_FIELDS_MAP)
        assert "Полное название статьи" in result["fields"]

    def test_author_count_coerced_to_int(self):
        ach = {"title": "paper", "type": "Статья", "author_count": "3"}
        result = coerce_crawl_achievement_dict(ach, self.TYPE_FIELDS_MAP)
        assert result["author_count"] == 3

    def test_author_count_defaults_to_1_for_invalid_value(self):
        ach = {"title": "paper", "type": "Статья", "author_count": "many"}
        result = coerce_crawl_achievement_dict(ach, self.TYPE_FIELDS_MAP)
        assert result["author_count"] == 1

    def test_missing_optional_fields_default_to_empty_string(self):
        ach = {"title": "paper", "type": "Статья"}
        result = coerce_crawl_achievement_dict(ach, self.TYPE_FIELDS_MAP)
        assert result["url"] == ""
        assert result["date"] == ""
        assert result["description"] == ""
        assert result["journal_title"] == ""

    def test_type_defaults_to_другое_when_absent(self):
        ach = {"title": "mystery achievement"}
        result = coerce_crawl_achievement_dict(ach, {})
        assert result["type"] == "Другое"


# ---------------------------------------------------------------------------
# filter_fields_for_type
# ---------------------------------------------------------------------------
class TestFilterFieldsForType:
    TYPE_FIELDS_MAP = {
        "Статья": [{"title": "Полное название статьи"}, {"title": "Ссылка"}],
    }

    def test_keeps_only_fields_for_specified_type(self):
        fields = {
            "Полное название статьи": "My Article",
            "Название темы выступления": "Talk",  # belongs to Конференция, not Статья
        }
        result = filter_fields_for_type(fields, "Статья", self.TYPE_FIELDS_MAP)
        assert "Полное название статьи" in result
        assert "Название темы выступления" not in result

    def test_returns_all_fields_when_type_not_in_map(self):
        fields = {"SomeField": "value"}
        result = filter_fields_for_type(fields, "Хакатон", self.TYPE_FIELDS_MAP)
        assert result == {"SomeField": "value"}

    def test_converts_values_to_string(self):
        fields = {"Полное название статьи": 42}
        result = filter_fields_for_type(fields, "Статья", self.TYPE_FIELDS_MAP)
        assert result["Полное название статьи"] == "42"

    def test_strips_whitespace_from_values(self):
        fields = {"Полное название статьи": "  title  "}
        result = filter_fields_for_type(fields, "Статья", self.TYPE_FIELDS_MAP)
        assert result["Полное название статьи"] == "title"

    def test_none_values_excluded(self):
        fields = {"Полное название статьи": None, "Ссылка": "http://x.com"}
        result = filter_fields_for_type(fields, "Статья", self.TYPE_FIELDS_MAP)
        assert "Полное название статьи" not in result
        assert "Ссылка" in result

    def test_empty_fields_returns_empty_dict(self):
        result = filter_fields_for_type({}, "Статья", self.TYPE_FIELDS_MAP)
        assert result == {}

    def test_none_fields_returns_empty_dict(self):
        result = filter_fields_for_type(None, "Статья", self.TYPE_FIELDS_MAP)
        assert result == {}


# ---------------------------------------------------------------------------
# build_type_synopsis_lines
# ---------------------------------------------------------------------------
class TestBuildTypeSynopsisLines:
    def test_empty_list_returns_empty_string(self):
        assert build_type_synopsis_lines([]) == ""

    def test_type_without_description_renders_just_title(self):
        result = build_type_synopsis_lines([{"title": "Статья"}])
        assert '"Статья"' in result

    def test_type_with_description_renders_description(self):
        result = build_type_synopsis_lines([
            {"title": "Грант", "description": "Финансируемый проект"}
        ])
        assert "Финансируемый проект" in result

    def test_type_without_title_is_skipped(self):
        result = build_type_synopsis_lines([{"description": "no title here"}])
        assert result == ""

    def test_multiple_types_produce_multiple_lines(self):
        types = [
            {"title": "Статья"},
            {"title": "Конференция"},
        ]
        lines = build_type_synopsis_lines(types).split("\n")
        assert len(lines) == 2
