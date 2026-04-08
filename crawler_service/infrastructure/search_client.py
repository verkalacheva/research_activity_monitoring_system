import os
from typing import List, Optional
from ddgs import DDGS
from tavily import TavilyClient


def _max_results_per_query() -> int:
    try:
        return max(1, int(os.getenv("CRAWL_MAX_RESULTS_PER_QUERY", "5")))
    except ValueError:
        return 5


class SearchClient:
    def __init__(self, settings: dict = None):
        s = settings or {}
        # DB setting has priority over ENV
        tavily_key: Optional[str] = s.get("tavily_api_key") or os.getenv("TAVILY_API_KEY") or None
        self.tavily_client = TavilyClient(api_key=tavily_key) if tavily_key else None

    async def search_urls(self, query: str, max_results: int = 5) -> List[str]:
        urls = []

        if self.tavily_client:
            try:
                result = self.tavily_client.search(query=query, search_depth="advanced", max_results=max_results)
                urls = [r['url'] for r in result.get('results', [])]
            except Exception as e:
                print(f"Tavily search failed: {e}")

        if not urls:
            try:
                with DDGS() as ddgs:
                    results = list(ddgs.text(query, max_results=max_results))
                    urls = [r['href'] for r in results if 'href' in r]
            except Exception as e:
                print(f"DuckDuckGo search failed: {e}")

        junk_domains = ["youtube.com", "google.com", "facebook.com", "twitter.com", "linkedin.com"]
        return [u for u in urls if not any(domain in u for domain in junk_domains)]

    async def search_urls_multi(self, queries: List[str]) -> List[str]:
        """Run several queries and merge URLs (order preserved, then ranked upstream)."""
        max_r = _max_results_per_query()
        merged: List[str] = []
        for q in queries:
            q = (q or "").strip()
            if len(q) < 3:
                continue
            part = await self.search_urls(q, max_results=max_r)
            merged.extend(part)
        return merged
