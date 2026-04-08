"""Score and order URLs from web search before crawling."""
import re
from typing import List, Dict, Any, Optional

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
    "researchgate.net",
    "acm.org",
    "nature.com",
    "science.org",
    "scopus",
    "wiley.com",
    "mdpi.com",
    "frontiersin.org",
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
    "google.com/search",
    "yandex.ru/search",
)


def _github_user(profile: Optional[Dict[str, Any]]) -> str:
    if not profile:
        return ""
    gh = (profile.get("github") or "").strip()
    if not gh:
        return ""
    return gh.replace("https://github.com/", "").replace("http://github.com/", "").strip("/").split("/")[0]


def url_score(url: str, profile: Optional[Dict[str, Any]]) -> float:
    u = (url or "").lower()
    score = 0.0
    for h in _ACADEMIC_POSITIVE:
        if h in u:
            score += 3.0
    for h in _UNIVERSITY_HINTS:
        if h in u:
            score += 1.5
    gh_user = _github_user(profile)
    if gh_user and f"github.com/{gh_user}".lower() in u:
        score += 2.5
    if "github.com" in u and "/blob/" not in u:
        score += 0.5
    for neg in _NEGATIVE:
        if neg in u:
            score -= 2.5
    if re.search(r"\.(edu|gov)(/|$)", u):
        score += 2.0
    return score


def rank_urls(urls: List[str], profile: Optional[Dict[str, Any]]) -> List[str]:
    """Dedupe, sort by relevance score descending."""
    seen = set()
    scored: List[tuple] = []
    for raw in urls:
        u = (raw or "").strip()
        if not u or u in seen:
            continue
        seen.add(u)
        scored.append((url_score(u, profile), u))
    scored.sort(key=lambda x: -x[0])
    return [u for _, u in scored]
