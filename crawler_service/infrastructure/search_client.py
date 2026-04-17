import os
from dataclasses import dataclass
from typing import List, Optional

from ddgs import DDGS


@dataclass
class SearchHit:
    """Single web search result with optional title/snippet for ranking."""

    url: str
    title: str = ""
    snippet: str = ""


def _max_results_per_query_from_env() -> Optional[int]:
    """Если задан CRAWL_MAX_RESULTS_PER_QUERY — ограничить выдачу DDG; иначе без лимита в нашем коде."""
    raw = os.getenv("CRAWL_MAX_RESULTS_PER_QUERY", "").strip()
    if not raw:
        return None
    try:
        return max(1, int(raw))
    except ValueError:
        return None


def round_robin_merge_hits(per_query: List[List["SearchHit"]]) -> List["SearchHit"]:
    """Чередуем URL из разных запросов, чтобы топ не состоял только из первой формулировки."""
    seen = set()
    out: List[SearchHit] = []
    if not per_query:
        return out
    max_len = max(len(x) for x in per_query)
    for i in range(max_len):
        for lst in per_query:
            if i < len(lst):
                h = lst[i]
                u = (h.url or "").strip()
                if u and u not in seen:
                    seen.add(u)
                    out.append(h)
    return out


class SearchClient:
    """Поиск ссылок для краулера — только DuckDuckGo (библиотека ddgs)."""

    def __init__(self, settings: dict = None):
        _ = settings or {}

    async def search_urls(self, query: str, max_results: Optional[int] = None) -> List[SearchHit]:
        hits: List[SearchHit] = []
        try:
            with DDGS() as ddgs:
                if max_results is None:
                    try:
                        results = list(ddgs.text(query))
                    except TypeError:
                        results = list(ddgs.text(query, max_results=100))
                else:
                    results = list(ddgs.text(query, max_results=max_results))
                for r in results:
                    href = r.get("href") or r.get("url")
                    if not href:
                        continue
                    hits.append(
                        SearchHit(
                            url=href,
                            title=(r.get("title") or "")[:500],
                            snippet=(r.get("body") or r.get("snippet") or "")[:2000],
                        )
                    )
        except Exception as e:
            print(f"DuckDuckGo search failed: {e}")

        junk_domains = ["youtube.com", "google.com", "facebook.com", "twitter.com", "linkedin.com"]
        return [h for h in hits if not any(domain in h.url for domain in junk_domains)]

    async def search_urls_multi(self, queries: List[str]) -> List[SearchHit]:
        """Несколько запросов; слияние round-robin по запросам."""
        max_r = _max_results_per_query_from_env()
        per_query: List[List[SearchHit]] = []
        for q in queries:
            q = (q or "").strip()
            if len(q) < 3:
                continue
            part = await self.search_urls(q, max_results=max_r)
            per_query.append(part)
        return round_robin_merge_hits(per_query)
