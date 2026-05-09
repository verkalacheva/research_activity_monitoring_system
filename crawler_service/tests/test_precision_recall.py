"""
Precision / Recall metrics for the crawler's core classification components.

Each test section defines a ground-truth fixture, runs the component under test,
computes standard IR metrics, and asserts that they exceed a minimum threshold.

Helper
------
_pr(tp, fp, fn) → (precision, recall)
    precision = TP / (TP + FP),  1.0 when TP+FP == 0 (nothing predicted)
    recall    = TP / (TP + FN),  1.0 when TP+FN == 0 (nothing relevant)
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import List, Set

import pytest

# ---------------------------------------------------------------------------
# Common helper
# ---------------------------------------------------------------------------

def _pr(tp: int, fp: int, fn: int) -> tuple[float, float]:
    precision = tp / (tp + fp) if (tp + fp) > 0 else 1.0
    recall    = tp / (tp + fn) if (tp + fn) > 0 else 1.0
    return precision, recall


# ===========================================================================
# 1. URL-RANKING PRECISION / RECALL
# ===========================================================================
# Ground-truth fixture:
#   RELEVANT  — URLs the ranker should *keep* (academic / professional)
#   IRRELEVANT — URLs the ranker should *drop* (social media, binary docs, medical)
#
# Precision = fraction of returned URLs that are relevant
# Recall    = fraction of relevant URLs that were returned
# ===========================================================================

from infrastructure.url_ranking import rank_urls
from infrastructure.search_client import SearchHit

_RELEVANT_URLS: List[str] = [
    "https://arxiv.org/abs/2301.00001",
    "https://doi.org/10.1016/j.neunet.2023.01.001",
    "https://scholar.google.com/citations?user=abc123",
    "https://orcid.org/0000-0001-2345-6789",
    "https://elibrary.ru/item.asp?id=123456",
    "https://cyberleninka.ru/article/n/some-article",
    "https://university.edu/staff/ivanov",
    "https://researchgate.net/profile/Ivanov",
    "https://pubmed.ncbi.nlm.nih.gov/12345678",
    "https://ieee.org/document/123456",
]

_IRRELEVANT_URLS: List[str] = [
    "https://vk.com/video-123456_789",
    "https://youtube.com/watch?v=abc",
    "https://docdoc.ru/doctor/123",
    "https://krasotaimedicina.ru/clinic",
    "https://instagram.com/user/publications",
    "https://pinterest.com/user/board",
    "https://example.com/report.docx",
    "https://example.com/download/file",
]


class TestUrlRankingPrecisionRecall:
    """
    The ranker filters out irrelevant URLs by returning only items that pass
    the scoring threshold. We measure how accurately it separates signal from noise.
    """

    MIN_PRECISION = 0.75
    MIN_RECALL    = 0.70

    def _run(self, relevant: List[str], irrelevant: List[str]) -> List[str]:
        all_urls = relevant + irrelevant
        return rank_urls(all_urls, None)

    def test_precision_recall_balanced_set(self):
        returned = self._run(_RELEVANT_URLS, _IRRELEVANT_URLS)
        relevant_set  = set(_RELEVANT_URLS)
        irrelevant_set = set(_IRRELEVANT_URLS)

        tp = sum(1 for u in returned if u in relevant_set)
        fp = sum(1 for u in returned if u in irrelevant_set)
        fn = sum(1 for u in relevant_set if u not in returned)

        precision, recall = _pr(tp, fp, fn)
        assert precision >= self.MIN_PRECISION, (
            f"URL-ranking precision {precision:.2f} < {self.MIN_PRECISION} "
            f"(tp={tp}, fp={fp}, fn={fn}, returned={returned})"
        )
        assert recall >= self.MIN_RECALL, (
            f"URL-ranking recall {recall:.2f} < {self.MIN_RECALL} "
            f"(tp={tp}, fp={fp}, fn={fn})"
        )

    def test_precision_noisy_set(self):
        """With many more irrelevant URLs, recall stays high; precision > random baseline.

        rank_urls ranks but does not hard-cut, so some noise leaks through.
        The relevant threshold here is > random (random ≈ 5/17 ≈ 0.29).
        """
        noisy_irrelevant = _IRRELEVANT_URLS * 3 + [
            "https://twitter.com/user/status/1",
            "https://facebook.com/profile.php?id=1",
            "https://napopravku.ru/doctor/123",
            "https://rutube.ru/video/abc",
        ]
        # Deduplicate to avoid artificial inflation
        noisy_irrelevant = list(dict.fromkeys(noisy_irrelevant))
        returned = self._run(_RELEVANT_URLS[:5], noisy_irrelevant)

        relevant_set   = set(_RELEVANT_URLS[:5])
        irrelevant_set = set(noisy_irrelevant)

        tp = sum(1 for u in returned if u in relevant_set)
        fp = sum(1 for u in returned if u in irrelevant_set)
        fn = sum(1 for u in relevant_set if u not in returned)

        precision, recall = _pr(tp, fp, fn)
        # rank_urls is a soft ranker — precision floor is above random (0.29)
        min_precision_noisy = 0.45
        assert precision >= min_precision_noisy, (
            f"Noisy-set precision {precision:.2f} < {min_precision_noisy} "
            f"(tp={tp}, fp={fp}, fn={fn})"
        )
        # All relevant URLs must still be retrievable
        assert recall >= self.MIN_RECALL, (
            f"Noisy-set recall {recall:.2f} < {self.MIN_RECALL} "
            f"(tp={tp}, fp={fp}, fn={fn})"
        )

    def test_recall_only_relevant(self):
        """When all inputs are relevant, recall should be ~1."""
        returned = rank_urls(_RELEVANT_URLS, None)
        relevant_set = set(_RELEVANT_URLS)

        tp = sum(1 for u in returned if u in relevant_set)
        fn = len(relevant_set) - tp
        _, recall = _pr(tp, 0, fn)

        assert recall >= self.MIN_RECALL, (
            f"All-relevant recall {recall:.2f} < {self.MIN_RECALL} "
            f"(tp={tp}, fn={fn}, returned={returned})"
        )


# ===========================================================================
# 2. TYPE-NORMALISATION PRECISION / RECALL
# ===========================================================================
# Ground truth: a set of (llm_output, expected_type) pairs.
# Precision = Recall = accuracy here (single-label classification, no abstain).
# We also use the golden_sample.json fixture from eval/.
# ===========================================================================

from infrastructure.type_normalization import fuzzy_match_type

_GOLDEN_PATH = Path(__file__).resolve().parents[1] / "eval" / "golden_sample.json"

_TYPE_FIXTURE: List[dict] = [
    # English aliases → Russian canonical
    {"llm_type": "journal-article",   "expected": "Статья"},
    {"llm_type": "paper",             "expected": "Статья"},
    {"llm_type": "conference-paper",  "expected": "Конференция"},
    {"llm_type": "conference",        "expected": "Конференция"},
    {"llm_type": "grant",             "expected": "Грант"},
    {"llm_type": "patent",            "expected": "РИД"},
    {"llm_type": "hackathon",         "expected": "Хакатон"},
    {"llm_type": "internship",        "expected": "Стажировка"},
    {"llm_type": "other",             "expected": "Другое"},
    # Russian near-matches (fuzzy)
    {"llm_type": "статья",            "expected": "Статья"},
    {"llm_type": "Статья в журнале",  "expected": "Статья"},
    {"llm_type": "конференция ",      "expected": "Конференция"},
    {"llm_type": "Гранты",            "expected": "Грант"},
    {"llm_type": "неизвестный тип",   "expected": "Другое"},
]

_ALLOWED_TYPES = [
    "Статья", "Конференция", "Грант", "РИД", "Хакатон",
    "Стажировка", "Стипендия", "Наставничество/менторство",
    "Упоминание в СМИ", "Публикация в СМИ", "Другое",
]


class TestTypeNormalisationPrecisionRecall:
    MIN_ACCURACY = 0.80   # precision == recall for single-label classification

    def _evaluate(self, cases: List[dict]) -> tuple[float, float]:
        tp = fp = fn = 0
        for c in cases:
            got = fuzzy_match_type(c["llm_type"], _ALLOWED_TYPES)
            exp = c["expected"]
            if got == exp:
                tp += 1
            else:
                fp += 1
                fn += 1
        return _pr(tp, fp, fn)

    def test_precision_recall_inline_fixture(self):
        precision, recall = self._evaluate(_TYPE_FIXTURE)
        assert precision >= self.MIN_ACCURACY, (
            f"Type-normalisation precision {precision:.2f} < {self.MIN_ACCURACY}"
        )
        assert recall >= self.MIN_ACCURACY, (
            f"Type-normalisation recall {recall:.2f} < {self.MIN_ACCURACY}"
        )

    @pytest.mark.skipif(
        not _GOLDEN_PATH.exists(),
        reason="eval/golden_sample.json not found"
    )
    def test_precision_recall_golden_sample(self):
        data = json.loads(_GOLDEN_PATH.read_text(encoding="utf-8"))
        allowed = [t["title"] for t in data["achievement_types"]]
        cases = [
            {"llm_type": c["llm_type"], "expected": c["expected_type"]}
            for c in data["cases"]
        ]
        tp = fp = fn = 0
        for c in cases:
            got = fuzzy_match_type(c["llm_type"], allowed)
            if got == c["expected"]:
                tp += 1
            else:
                fp += 1
                fn += 1
        precision, recall = _pr(tp, fp, fn)
        assert precision >= self.MIN_ACCURACY, (
            f"Golden-sample precision {precision:.2f} < {self.MIN_ACCURACY}"
        )
        assert recall >= self.MIN_ACCURACY, (
            f"Golden-sample recall {recall:.2f} < {self.MIN_ACCURACY}"
        )


# ===========================================================================
# 3. ACHIEVEMENT DEDUPLICATION PRECISION / RECALL
# ===========================================================================
# Ground truth: pairs of achievements that are duplicates (same_key=True)
# and pairs that are NOT duplicates (same_key=False).
#
# The dedup key is normalize_title_key().
#
# TP = duplicate pair correctly merged (same key)
# FP = non-duplicate pair incorrectly merged (same key assigned to different titles)
# FN = duplicate pair missed (different keys assigned to same-meaning titles)
# ===========================================================================

from infrastructure.type_normalization import normalize_title_key

_DEDUP_FIXTURE: List[dict] = [
    # Should be merged (same_key=True)
    {"a": "Machine Learning: A Survey",     "b": "Machine learning: a survey",          "same": True},
    {"a": "  Deep Learning  ",              "b": "Deep Learning",                        "same": True},
    {"a": "Нейронные сети и их применение", "b": "нейронные сети и их применение",       "same": True},
    {"a": "Квантовые вычисления (2023)",    "b": "Квантовые вычисления  (2023)",          "same": True},
    {"a": "A\u2010B",                       "b": "A-B",                                  "same": True},  # different hyphens
    # Should NOT be merged (same_key=False)
    {"a": "Deep Learning",                  "b": "Reinforcement Learning",               "same": False},
    {"a": "Статья о нейронных сетях",       "b": "Доклад о нейронных сетях",             "same": False},
    {"a": "Метод градиентного спуска",      "b": "Анализ методов оптимизации",           "same": False},
    {"a": "NLP Survey 2022",                "b": "NLP Survey 2023",                      "same": False},
    {"a": "Краткий обзор",                  "b": "Подробный обзор",                      "same": False},
]


class TestDeduplicationPrecisionRecall:
    MIN_PRECISION = 0.80
    MIN_RECALL    = 0.80

    def test_precision_recall(self):
        tp = fp = fn = 0
        for case in _DEDUP_FIXTURE:
            k1 = normalize_title_key(case["a"])
            k2 = normalize_title_key(case["b"])
            predicted_same = (k1 == k2)
            actually_same  = case["same"]

            if predicted_same and actually_same:
                tp += 1
            elif predicted_same and not actually_same:
                fp += 1
            elif not predicted_same and actually_same:
                fn += 1
            # true negatives (not predicted, not expected) don't affect P/R

        precision, recall = _pr(tp, fp, fn)
        assert precision >= self.MIN_PRECISION, (
            f"Dedup precision {precision:.2f} < {self.MIN_PRECISION} "
            f"(tp={tp}, fp={fp}, fn={fn})"
        )
        assert recall >= self.MIN_RECALL, (
            f"Dedup recall {recall:.2f} < {self.MIN_RECALL} "
            f"(tp={tp}, fp={fp}, fn={fn})"
        )

    @pytest.mark.skipif(
        not _GOLDEN_PATH.exists(),
        reason="eval/golden_sample.json not found"
    )
    def test_dedup_golden_sample(self):
        data = json.loads(_GOLDEN_PATH.read_text(encoding="utf-8"))
        examples = data.get("title_dedup_examples", [])
        if not examples:
            pytest.skip("no title_dedup_examples in golden_sample.json")

        tp = fp = fn = 0
        for ex in examples:
            k1 = normalize_title_key(ex["a"])
            k2 = normalize_title_key(ex["b"])
            predicted_same = (k1 == k2)
            actually_same  = ex["same_key"]

            if predicted_same and actually_same:
                tp += 1
            elif predicted_same and not actually_same:
                fp += 1
            elif not predicted_same and actually_same:
                fn += 1

        precision, recall = _pr(tp, fp, fn)
        assert precision >= self.MIN_PRECISION, (
            f"Golden dedup precision {precision:.2f} < {self.MIN_PRECISION}"
        )
        assert recall >= self.MIN_RECALL, (
            f"Golden dedup recall {recall:.2f} < {self.MIN_RECALL}"
        )
