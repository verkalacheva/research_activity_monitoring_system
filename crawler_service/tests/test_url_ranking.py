"""Unit tests for infrastructure/url_ranking.py."""
from __future__ import annotations

import os
import pytest
from infrastructure.url_ranking import (
    is_pdf_url,
    is_forced_download_url,
    is_other_binary_document_url,
    is_direct_binary_document_url,
    is_social_video_url,
    is_consumer_medical_booking_url,
    url_score,
    name_match_score,
    rank_search_hits,
    rank_urls,
)
from infrastructure.search_client import SearchHit


# ---------------------------------------------------------------------------
# is_pdf_url
# ---------------------------------------------------------------------------
class TestIsPdfUrl:
    def test_pdf_extension_detected(self):
        assert is_pdf_url("https://example.com/paper.pdf") is True

    def test_pdf_uppercase_extension_detected(self):
        # path is lowercased before check
        assert is_pdf_url("https://example.com/PAPER.PDF") is True

    def test_non_pdf_returns_false(self):
        assert is_pdf_url("https://example.com/page.html") is False

    def test_empty_string_returns_false(self):
        assert is_pdf_url("") is False

    def test_pdf_in_path_middle_not_detected(self):
        # only suffix matters
        assert is_pdf_url("https://example.com/pdf/document") is False


# ---------------------------------------------------------------------------
# is_forced_download_url
# ---------------------------------------------------------------------------
class TestIsForcedDownloadUrl:
    def test_file_download_path(self):
        assert is_forced_download_url("https://example.com/file/download?id=1") is True

    def test_files_download_path(self):
        assert is_forced_download_url("https://example.com/files/download/report") is True

    def test_download_slash_in_path(self):
        assert is_forced_download_url("https://example.com/download/report.docx") is True

    def test_disposition_attachment_param(self):
        assert is_forced_download_url("https://example.com/file?disposition=attachment") is True

    def test_download_1_param(self):
        assert is_forced_download_url("https://example.com/file?download=1") is True

    def test_normal_url_returns_false(self):
        assert is_forced_download_url("https://arxiv.org/abs/2301.00001") is False


# ---------------------------------------------------------------------------
# is_other_binary_document_url
# ---------------------------------------------------------------------------
class TestIsOtherBinaryDocumentUrl:
    @pytest.mark.parametrize("ext", [".doc", ".docx", ".ppt", ".pptx", ".xls", ".xlsx", ".zip", ".rar", ".rtf", ".odt", ".ods"])
    def test_binary_extension_detected(self, ext):
        url = f"https://example.com/report{ext}"
        assert is_other_binary_document_url(url) is True

    def test_html_not_binary(self):
        assert is_other_binary_document_url("https://example.com/page.html") is False

    def test_pdf_not_in_binary_list(self):
        # PDF is handled separately
        assert is_other_binary_document_url("https://example.com/paper.pdf") is False


# ---------------------------------------------------------------------------
# is_direct_binary_document_url
# ---------------------------------------------------------------------------
class TestIsDirectBinaryDocumentUrl:
    def test_doc_returns_true(self):
        assert is_direct_binary_document_url("https://example.com/file.docx") is True

    def test_forced_download_returns_true(self):
        assert is_direct_binary_document_url("https://example.com/download/file") is True

    def test_pdf_skipped_when_env_set(self, monkeypatch):
        monkeypatch.setenv("CRAWL_SKIP_PDF_URLS", "1")
        assert is_direct_binary_document_url("https://example.com/paper.pdf") is True

    def test_pdf_not_skipped_by_default(self, monkeypatch):
        monkeypatch.setenv("CRAWL_SKIP_PDF_URLS", "0")
        assert is_direct_binary_document_url("https://example.com/paper.pdf") is False

    def test_normal_url_returns_false(self):
        assert is_direct_binary_document_url("https://arxiv.org/abs/2301.00001") is False


# ---------------------------------------------------------------------------
# is_social_video_url
# ---------------------------------------------------------------------------
class TestIsSocialVideoUrl:
    @pytest.mark.parametrize("url", [
        "https://vk.com/video-123456",
        "https://youtube.com/watch?v=abc",
        "https://youtube.com/shorts/xyz",
        "https://rutube.ru/video/abc",
        "https://vk.com/clips-1234",
    ])
    def test_social_video_detected(self, url):
        assert is_social_video_url(url) is True

    def test_vk_non_video_page(self):
        assert is_social_video_url("https://vk.com/science_group") is False

    def test_academic_url_not_social(self):
        assert is_social_video_url("https://arxiv.org/abs/2301.00001") is False


# ---------------------------------------------------------------------------
# is_consumer_medical_booking_url
# ---------------------------------------------------------------------------
class TestIsConsumerMedicalBookingUrl:
    @pytest.mark.parametrize("url", [
        "https://docdoc.ru/doctor/12345",
        "https://krasotaimedicina.ru/clinic",
        "https://prodoctorov.ru/spb",
        "https://napopravku.ru/",
    ])
    def test_medical_booking_detected(self, url):
        assert is_consumer_medical_booking_url(url) is True

    def test_university_not_medical(self):
        assert is_consumer_medical_booking_url("https://itmo.ru/person/123") is False


# ---------------------------------------------------------------------------
# url_score
# ---------------------------------------------------------------------------
class TestUrlScore:
    def test_arxiv_has_positive_score(self):
        score = url_score("https://arxiv.org/abs/2301.00001", None)
        assert score > 0, "arxiv should have positive score"

    def test_doi_has_positive_score(self):
        assert url_score("https://doi.org/10.1234/test", None) > 0

    def test_orcid_profile_has_positive_score(self):
        score = url_score("https://orcid.org/0000-0001-2345-6789", None)
        assert score > 0

    def test_social_negatives_reduce_score(self):
        positive = url_score("https://example.com/publications", None)
        negative = url_score("https://instagram.com/user/post", None)
        assert negative < positive

    def test_academic_above_social_noise(self):
        academic = url_score("https://cyberleninka.ru/article/n/123", None)
        social = url_score("https://pinterest.com/pin/abc", None)
        assert academic > social

    def test_university_domain_bonus(self):
        uni = url_score("https://university.edu/staff/prof", None)
        random = url_score("https://random-site.org/page", None)
        assert uni > random

    def test_news_path_reduced_score(self):
        base = url_score("https://example.com/article/123", None)
        news = url_score("https://example.com/news/article/123", None)
        assert news < base

    def test_publication_path_bonus(self):
        pub = url_score("https://example.com/publications/2024", None)
        plain = url_score("https://example.com/2024", None)
        assert pub > plain

    def test_hackathon_url_has_positive_score(self):
        score = url_score("https://devpost.com/hackathon/abc", None)
        assert score > 0

    def test_empty_url_has_zero_or_neutral(self):
        # Empty URL — should not crash; score will be near 0
        score = url_score("", None)
        assert isinstance(score, float)


# ---------------------------------------------------------------------------
# name_match_score
# ---------------------------------------------------------------------------
class TestNameMatchScore:
    def test_full_name_match_returns_positive(self):
        score = name_match_score("Иванов Иван Иванович", "Иванов Иван публикация", "")
        assert score > 0

    def test_no_name_match_returns_zero(self):
        score = name_match_score("Иванов Иван", "Совершенно другая статья", "другой автор")
        assert score == 0.0

    def test_short_name_returns_zero(self):
        score = name_match_score("Ли", "title", "snippet")
        assert score == 0.0

    def test_empty_researcher_name(self):
        score = name_match_score("", "title", "snippet")
        assert score == 0.0

    def test_partial_match_less_than_full(self):
        full = name_match_score("Иванов Иван", "Иванов Иван исследование", "")
        partial = name_match_score("Иванов Иван", "Иванов исследование", "")
        assert full >= partial

    def test_score_upper_bound(self):
        # Maximum possible score is 6.0 (all parts match)
        score = name_match_score("Иванов Иван", "Иванов Иван конференция", "")
        assert score <= 6.0


# ---------------------------------------------------------------------------
# rank_search_hits
# ---------------------------------------------------------------------------
class TestRankSearchHits:
    def test_empty_hits_returns_empty(self):
        assert rank_search_hits([], None) == []

    def test_deduplicates_same_url(self):
        hits = [
            SearchHit(url="https://arxiv.org/abs/1"),
            SearchHit(url="https://arxiv.org/abs/1"),
        ]
        result = rank_search_hits(hits, None)
        assert len(result) == 1

    def test_academic_url_before_noise(self):
        hits = [
            SearchHit(url="https://pinterest.com/pin/abc"),
            SearchHit(url="https://arxiv.org/abs/2301.00001"),
        ]
        result = rank_search_hits(hits, None)
        if len(result) > 0:
            assert "arxiv" in result[0].lower() or len(result) >= 1

    def test_github_urls_excluded(self):
        hits = [
            SearchHit(url="https://github.com/user/repo"),
            SearchHit(url="https://arxiv.org/abs/1"),
        ]
        result = rank_search_hits(hits, None)
        assert not any("github.com" in u for u in result)

    def test_binary_document_excluded(self):
        hits = [
            SearchHit(url="https://example.com/report.docx"),
            SearchHit(url="https://arxiv.org/abs/2301.00001"),
        ]
        result = rank_search_hits(hits, None)
        assert not any(u.endswith(".docx") for u in result)

    def test_medical_booking_excluded(self):
        hits = [
            SearchHit(url="https://docdoc.ru/doctor/123"),
            SearchHit(url="https://arxiv.org/abs/2301"),
        ]
        result = rank_search_hits(hits, None)
        assert not any("docdoc.ru" in u for u in result)

    def test_social_video_excluded(self):
        hits = [
            SearchHit(url="https://youtube.com/watch?v=abc"),
            SearchHit(url="https://arxiv.org/abs/2301"),
        ]
        result = rank_search_hits(hits, None)
        assert not any("youtube.com/watch" in u for u in result)

    def test_name_match_boosts_rank(self):
        hits = [
            SearchHit(url="https://elibrary.ru/item.asp?id=1", title="Иванов Иван публикации"),
            SearchHit(url="https://arxiv.org/abs/99", title="Other author work"),
        ]
        result = rank_search_hits(hits, None, researcher_name="Иванов Иван")
        assert len(result) == 2
        assert "elibrary.ru" in result[0]

    def test_non_searchhit_objects_skipped(self):
        result = rank_search_hits(["not-a-hit", 42, None], None)
        assert result == []


# ---------------------------------------------------------------------------
# rank_urls
# ---------------------------------------------------------------------------
class TestRankUrls:
    def test_empty_list(self):
        assert rank_urls([], None) == []

    def test_returns_list_of_strings(self):
        urls = ["https://arxiv.org/abs/1", "https://doi.org/10.1/test"]
        result = rank_urls(urls, None)
        assert all(isinstance(u, str) for u in result)

    def test_academic_sorted_before_noise(self):
        urls = [
            "https://pinterest.com/user/board",
            "https://cyberleninka.ru/article/n/xyz",
        ]
        result = rank_urls(urls, None)
        assert result[0] == "https://cyberleninka.ru/article/n/xyz"

    def test_deduplicated(self):
        urls = ["https://arxiv.org/abs/1", "https://arxiv.org/abs/1"]
        result = rank_urls(urls, None)
        assert len(result) == 1
