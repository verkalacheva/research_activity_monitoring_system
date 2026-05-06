"""Web search для краулера (библиотека ddgs: Bing, Brave, Mojeek, …).

В Docker/datacenter редиректы Yahoo нестабильны — он исключён из дефолтного fallback-списка.
Основные бэкенды: CRAWL_DDGS_BACKEND (по умолчанию bing,mojeek,brave).
Fallback (при пустом ответе основных): CRAWL_DDGS_FALLBACK_BACKENDS (по умолчанию google,duckduckgo).
При необходимости задайте DDGS_PROXY.
"""

from __future__ import annotations

import asyncio
import logging
import os
import random
from dataclasses import dataclass
from typing import List, Optional

from ddgs import DDGS

logger = logging.getLogger(__name__)


@dataclass
class SearchHit:
    """Single web search result with optional title/snippet for ranking."""

    url: str
    title: str = ""
    snippet: str = ""


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


def _int_env(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, str(default)))
    except ValueError:
        return default


def _timeout_s() -> int:
    return max(8, min(120, _int_env("DDGS_TIMEOUT", 25)))


def _max_results_requested(req: Optional[int]) -> int:
    cap = max(10, min(200, _int_env("CRAWL_DDGS_MAX_RESULTS", 48)))
    n = req if req is not None else cap
    return max(10, min(n, cap))


def _primary_backends() -> str:
    return (os.environ.get("CRAWL_DDGS_BACKEND") or "").strip() or os.environ.get("CRAWL_DDGS_BACKENDS_PRIMARY", "").strip() or "bing,mojeek,brave"


def _fallback_backend_specs() -> List[str]:
    # Yahoo исключён из дефолта — его редиректы нестабильны в Docker/datacenter.
    # Чтобы включить явно: CRAWL_DDGS_FALLBACK_BACKENDS=google,yahoo,duckduckgo
    raw = (
        os.environ.get("CRAWL_DDGS_FALLBACK_BACKENDS", "").strip()
        or "google,duckduckgo"
    )
    return [x.strip() for x in raw.split(",") if x.strip()]


def _hits_from_items(results: List[dict]) -> List[SearchHit]:
    hits: List[SearchHit] = []
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
    return hits


class SearchClient:
    """Поиск ссылок для краулера через ddgs (несколько движков, не только DuckDuckGo HTML)."""

    def __init__(self, settings: dict | None = None):
        _ = settings or {}

    def _fetch_raw(self, query: str, max_results: int, backend: str) -> List[dict]:
        proxy = os.environ.get("DDGS_PROXY") or None
        kwargs = dict(
            backend=backend,
            region=os.environ.get("DDGS_REGION", "us-en"),
        )
        with DDGS(proxy=proxy, timeout=_timeout_s()) as ddgs:
            try:
                return list(ddgs.text(query, max_results=max_results, **kwargs))
            except TypeError:
                return list(ddgs.text(query, **kwargs))

    async def search_urls(self, query: str, max_results: Optional[int] = None) -> List[SearchHit]:
        n = _max_results_requested(max_results)
        q = (query or "").strip()
        raw_rows: List[dict] = []

        if len(q) < 2:
            return []

        # 1) основной список (часто bing/brave без html.duckduckgo)
        primary = _primary_backends()
        try:
            raw_rows = self._fetch_raw(q, n, primary)
            if raw_rows:
                logger.debug(
                    "[SearchClient] DDGS primary ok backend=%s rows=%d", primary, len(raw_rows)
                )
        except Exception as e:
            logger.warning("[SearchClient] DDGS primary failed (%s): %s", primary, e)

        # 2) fallback — только если пусто
        if not raw_rows:
            fallback_errors: List[str] = []
            for fb in _fallback_backend_specs():
                delay = random.uniform(0.4, 1.6)
                await asyncio.sleep(delay)
                try:
                    raw_rows = self._fetch_raw(q, n, fb)
                    if raw_rows:
                        logger.info(
                            "[SearchClient] DDGS fallback succeeded: %s (%d hits)", fb, len(raw_rows)
                        )
                        break
                    logger.info("[SearchClient] DDGS fallback empty: %s", fb)
                except Exception as e:
                    msg = f"{fb}: {e}"
                    fallback_errors.append(msg)
                    logger.info("[SearchClient] DDGS fallback failed (%s): %s", fb, e)
            if not raw_rows and fallback_errors:
                logger.warning(
                    "[SearchClient] DDGS fallback exhausted for query=%r: %s",
                    q[:120],
                    " | ".join(fallback_errors[:5]),
                )

        hits = _hits_from_items(raw_rows)
        junk_domains = ["youtube.com", "google.com", "facebook.com", "twitter.com", "linkedin.com"]
        filtered = [h for h in hits if not any(domain in h.url for domain in junk_domains)]
        return filtered

    async def search_urls_multi(self, queries: List[str]) -> List[SearchHit]:
        """Несколько запросов; слияние round-robin по запросам."""
        per_query: List[List[SearchHit]] = []
        for q in queries:
            q = (q or "").strip()
            if len(q) < 3:
                continue
            part = await self.search_urls(q, max_results=None)
            per_query.append(part)
        return round_robin_merge_hits(per_query)
