"""Score and order URLs from web search before crawling."""
import os
import re
import unicodedata
from typing import List, Dict, Any, Optional
from urllib.parse import urlparse

# Бинарники без PDF — пока не извлекаем текст (см. crawler для .pdf).
_NON_PDF_BINARY_SUFFIXES = (
    ".doc",
    ".docx",
    ".ppt",
    ".pptx",
    ".xls",
    ".xlsx",
    ".zip",
    ".rar",
    ".rtf",
    ".odt",
    ".ods",
)


def _skip_pdf_in_ranking() -> bool:
    """CRAWL_SKIP_PDF_URLS=1 — как раньше: PDF из выдачи убрать (нет PDF-пайплайна)."""
    return (os.getenv("CRAWL_SKIP_PDF_URLS", "0") or "0").strip().lower() in (
        "1",
        "true",
        "yes",
    )


def is_pdf_url(url: str) -> bool:
    try:
        path = (urlparse(url or "").path or "").lower()
    except Exception:
        path = ""
    return path.endswith(".pdf")


def is_forced_download_url(url: str) -> bool:
    """Скачивание файла (не HTML): Playwright уходит в «Download is starting» — не краулим."""
    u = (url or "").lower()
    if "/file/download" in u or "/files/download" in u:
        return True
    if "/download/" in u or "/downloads/" in u:
        return True
    if "disposition=attachment" in u or "download=1" in u:
        return True
    return False


def is_other_binary_document_url(url: str) -> bool:
    """DOC/DOCX/… — исключаем из краула."""
    try:
        path = (urlparse(url or "").path or "").lower()
    except Exception:
        path = ""
    return any(path.endswith(suf) for suf in _NON_PDF_BINARY_SUFFIXES)


def is_direct_binary_document_url(url: str) -> bool:
    """Совместимость: «бинарный» URL, который не должен попасть в ранжирование."""
    if is_forced_download_url(url):
        return True
    if is_other_binary_document_url(url):
        return True
    if is_pdf_url(url) and _skip_pdf_in_ranking():
        return True
    return False


def is_social_video_url(url: str) -> bool:
    """Видеохостинг в соцсетях — не источник достижений; модель почти всегда возвращает пусто."""
    u = (url or "").lower()
    return any(
        x in u
        for x in (
            "vk.com/video",
            "vk.com/clips",
            "youtube.com/watch",
            "youtube.com/shorts",
            "rutube.ru/video",
        )
    )


def is_consumer_medical_booking_url(url: str) -> bool:
    """Запись к врачу / клиники — не научные достижения, DDG часто путает"""
    u = (url or "").lower()
    return any(
        h in u
        for h in (
            "docdoc.ru",
            "krasotaimedicina.ru",
            "prodoctorov.ru",
            "napopravku.ru",
            "docdoc.com",
        )
    )


_ACADEMIC_POSITIVE = (
    "arxiv.org",
    "doi.org",
    "orcid.org",
    "openalex.org",
    "pubmed",
    "ieee.org",
    "springer",
    "sciencedirect",
    "elibrary.ru",
    "cyberleninka.ru",
    # RU / CIS: журналы, репозитории, ВАК, конференции, гранты, СМИ о науке
    "mathnet.ru",
    "math-net.ru",
    "knc.ru",
    "istina.msu.ru",
    "istina.spb.ru",
    "istina.ras.ru",
    "rscf.ru",
    "scinde.ru",
    "publications.hse.ru",
    "pure.spbu.ru",
    "pureportal.spbu.ru",
    "kmu.itmo.ru",
    "journals.rcsi.ru",
    "dissercat.com",
    "dissernet.org",
    "nplus1.ru",
    "elementy.ru",
    "indicator.ru",
    "ras.ru",
    "iphran.ru",
    "ispras.ru",
    "ipmnet.ru",
    "mi-ras.ru",
    "mi.ras.ru",
    "vestnik.spbu.ru",
    "sciencejournals.ru",
    "rcsi.science",
    "science-education.ru",
    "minobrnauki.gov.ru",
    "council.gov.ru",
    "turpion.ru",
    "pleiades.online",
    "journals.rudn.ru",
    "journals.tsu.ru",
    "researchgate.net",
    "acm.org",
    "nature.com",
    "science.org",
    "scopus",
    "wiley.com",
    "mdpi.com",
    "frontiersin.org",
    "fips.ru",
    "rospatent.gov.ru",
    "patents.google.com",
    "kaggle.com",
    "devpost.com",
)

_UNIVERSITY_HINTS = (
    ".edu",
    ".ac.uk",
    ".ac.ru",
    "university",
    "univ-",
    "institute",
    "институт",
    "университет",
)

# Порталы конкурсов / грантов / РИД — не статьи, но релевантны полноте типов.
_RESEARCH_PROGRAM_PORTALS = (
    "grants.gov",
    "devpost.com",
    "kaggle.com",
    "hackathon",
    "rnf.ru",
    "rospatent",
    "fips.ru",
    "patents.google.com",
    "zakupki",
    "gosuslugi",
)

# Хакатоны и ИТ-соревнования (RU + международные). devpost/kaggle уже в _ACADEMIC_POSITIVE — не дублируем.
_HACKATHON_COMPETITION_HINTS = (
    "hackerearth.com",
    "mlh.io",
    "devfolio.co",
    "unstop.com",
    "challengerocket.com",
    "codenrock.com",
    "case-in.ru",
    "casein.ru",
    "leadersofdigital.ru",
    "leadersofdigital",
    "ai-journey.ru",
    "openinnovations.ru",
    "hackathons.dev",
    "digital.gov.ru",
    "skills.ru",
    "worldskills.ru",
    "codefest.ru",
    "itfest.ru",
    "hackday.ru",
    "datathon.ru",
    "rucode.net",
    "russiancode.ru",
    "cup.yandex.ru",
    "contest.yandex",
    "/hackathon",
    "-hackathon-",
)

_NEGATIVE = (
    "pinterest.",
    "quora.com",
    "tiktok.com",
    "instagram.com",
    "facebook.com",
    "twitter.com",
    "x.com",
    "linkedin.com/feed",
    "youtube.com",
    "vk.com/video",
    "google.com/search",
    "yandex.ru/search",
)


def url_score(url: str, profile: Optional[Dict[str, Any]]) -> float:
    _ = profile
    u = (url or "").lower()
    score = 0.0
    for h in _ACADEMIC_POSITIVE:
        if h in u:
            score += 3.0
    for h in _UNIVERSITY_HINTS:
        if h in u:
            score += 1.5
    for neg in _NEGATIVE:
        if neg in u:
            score -= 2.5
    for portal in _RESEARCH_PROGRAM_PORTALS:
        if portal in u:
            score += 1.8
    hack_bonus = 0.0
    for h in _HACKATHON_COMPETITION_HINTS:
        if h in u:
            hack_bonus += 2.0
    score += min(hack_bonus, 8.0)
    if re.search(r"\.(edu|gov)(/|$)", u):
        score += 2.0
    for path_hint in (
        "/publication",
        "/publications",
        "/cv",
        "/profile",
        "/author",
        "scholar.google",
        "researchgate.net/profile",
        "orcid.org",
    ):
        if path_hint in u:
            score += 2.0
    for noise in ("/news/", "/novosti/", "/tag/", "/category/", "utm_source="):
        if noise in u:
            score -= 1.2
    return score


def _normalize_name_token(s: str) -> str:
    t = unicodedata.normalize("NFKC", s or "").lower().strip()
    t = re.sub(r"[\s\-]+", "", t)
    return t


def name_match_score(researcher_name: str, title: str, snippet: str) -> float:
    """Бонус, если ФИО (по частям) встречается в title/snippet выдачи DDG."""
    name = (researcher_name or "").strip()
    if len(name) < 4:
        return 0.0
    blob = f"{title or ''} {snippet or ''}".lower()
    parts = [p for p in re.split(r"\s+", name) if len(p) >= 3]
    if not parts:
        return 0.0
    hits = 0
    for p in parts:
        if p.lower() in blob:
            hits += 1
        else:
            nt = _normalize_name_token(p)
            if len(nt) >= 4 and nt in re.sub(r"\s+", "", blob):
                hits += 1
    return (hits / len(parts)) * 6.0


def rank_search_hits(
    hits: List["SearchHit"],
    profile: Optional[Dict[str, Any]],
    researcher_name: str = "",
) -> List[str]:
    """Dedupe, sort by url_score + snippet/title name match."""
    from infrastructure.search_client import SearchHit  # runtime import

    seen = set()
    scored: List[tuple] = []
    for h in hits:
        if not isinstance(h, SearchHit):
            continue
        u = (h.url or "").strip()
        if not u or u in seen:
            continue
        if "github.com" in u.lower():
            continue
        if is_direct_binary_document_url(u):
            continue
        if is_consumer_medical_booking_url(u):
            continue
        if is_social_video_url(u):
            continue
        seen.add(u)
        base = url_score(u, profile)
        nm = name_match_score(researcher_name, h.title, h.snippet)
        scored.append((base + nm, u))
    scored.sort(key=lambda x: -x[0])
    return [u for _, u in scored]


def rank_urls(urls: List[str], profile: Optional[Dict[str, Any]]) -> List[str]:
    """Обёртка без title/snippet (только доменный скоринг)."""
    from infrastructure.search_client import SearchHit

    hits = [SearchHit(url=u) for u in urls]
    return rank_search_hits(hits, profile, researcher_name="")
