"""OpenAlex + ORCID: landing URLs for works (catalog discovery, not web search)."""
from __future__ import annotations

import os
import re
from typing import Any, Dict, List, Optional

import httpx

_OPENALEX = "https://api.openalex.org"


def _mailto_for_openalex() -> str:
    m = (os.getenv("OPENALEX_MAILTO") or "mailto:openalex@example.org").strip()
    if m.startswith("mailto:"):
        return m[8:]
    return m


def _openalex_headers() -> Dict[str, str]:
    return {
        "User-Agent": (
            f"ResearchActivityMonitor/1.0 "
            f"(https://github.com/; mailto:{_mailto_for_openalex()})"
        ),
        "Accept": "application/json",
    }


def _normalize_orcid(raw: str) -> Optional[str]:
    s = (raw or "").strip().replace("https://orcid.org/", "").replace("http://orcid.org/", "")
    s = s.strip("/")
    if re.match(r"^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$", s, re.I):
        return s.upper()
    return None


def _normalize_openalex_author_id(raw: str) -> Optional[str]:
    s = (raw or "").strip()
    if not s:
        return None
    if "openalex.org" in s.lower():
        s = s.rstrip("/").split("/")[-1]
    if s.startswith("A") and len(s) >= 8:
        return s
    return None


def _work_landing_url(work: Dict[str, Any]) -> Optional[str]:
    pl = work.get("primary_location") or {}
    if isinstance(pl, dict):
        for key in ("landing_page_url", "pdf_url", "source_url"):
            u = pl.get(key)
            if isinstance(u, str) and u.startswith("http"):
                return u.strip()
    doi = work.get("doi")
    if isinstance(doi, str) and doi.strip():
        d = doi.strip()
        if d.startswith("http"):
            return d
        return f"https://doi.org/{d.replace('https://doi.org/', '').lstrip('/')}"
    oa = work.get("open_access") or {}
    if isinstance(oa, dict):
        u = oa.get("oa_url")
        if isinstance(u, str) and u.startswith("http"):
            return u.strip()
    b = work.get("best_oa_location") or {}
    if isinstance(b, dict):
        u = b.get("landing_page_url") or b.get("pdf_url")
        if isinstance(u, str) and u.startswith("http"):
            return u.strip()
    return None


async def _openalex_resolve_author_id_from_orcid(orcid_clean: str) -> Optional[str]:
    """OpenAlex authors filter by ORCID → first author id."""
    oid_url = f"https://orcid.org/{orcid_clean}"
    params = {"filter": f"orcid:{oid_url}", "per_page": 5}
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            r = await client.get(
                f"{_OPENALEX}/authors",
                params=params,
                headers=_openalex_headers(),
            )
            if r.status_code != 200:
                print(f"[catalog] OpenAlex authors ORCID {orcid_clean}: HTTP {r.status_code}")
                return None
            data = r.json()
    except Exception as e:
        print(f"[catalog] OpenAlex authors ORCID error: {e}")
        return None
    results = data.get("results") or []
    if not results:
        return None
    aid = results[0].get("id") or ""
    if isinstance(aid, str) and "openalex.org" in aid:
        return aid.rstrip("/").split("/")[-1]
    return None


async def _openalex_fetch_work_urls_for_author(
    author_id_short: str,
    max_works: int,
) -> List[str]:
    """author_id_short like A1234567890."""
    urls: List[str] = []
    cursor: Optional[str] = None
    per = min(200, max(1, max_works))

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            while len(urls) < max_works:
                params: Dict[str, Any] = {
                    "filter": f"author.id:{author_id_short}",
                    "per_page": per,
                    "select": "id,doi,primary_location,open_access,best_oa_location",
                }
                if cursor:
                    params["cursor"] = cursor
                r = await client.get(
                    f"{_OPENALEX}/works",
                    params=params,
                    headers=_openalex_headers(),
                )
                if r.status_code != 200:
                    print(f"[catalog] OpenAlex works HTTP {r.status_code}")
                    break
                data = r.json()
                for w in data.get("results") or []:
                    u = _work_landing_url(w if isinstance(w, dict) else {})
                    if u and u not in urls:
                        urls.append(u)
                    if len(urls) >= max_works:
                        break
                cursor = (data.get("meta") or {}).get("next_cursor")
                if not cursor:
                    break
    except Exception as e:
        print(f"[catalog] OpenAlex works fetch error: {e}")

    return urls[:max_works]


async def fetch_catalog_landing_urls(profile: Optional[Dict[str, Any]]) -> List[str]:
    """
    Returns unique HTTP(S) landing URLs from OpenAlex (by stored OpenAlex id or ORCID),
    plus ORCID record API URLs as supplementary discovery when useful.
    """
    if (os.getenv("CRAWL_ENABLE_CATALOG_FETCH", "1") or "1").strip().lower() in (
        "0",
        "false",
        "no",
        "off",
    ):
        return []

    p = profile or {}
    try:
        max_works = max(1, int(os.getenv("OPENALEX_MAX_WORKS", "50")))
    except ValueError:
        max_works = 50

    author_id = _normalize_openalex_author_id(str(p.get("openalex_id") or ""))
    oid = _normalize_orcid(str(p.get("orcid_id") or ""))

    if not author_id and oid:
        author_id = await _openalex_resolve_author_id_from_orcid(oid)

    out: List[str] = []
    if author_id:
        out = await _openalex_fetch_work_urls_for_author(author_id, max_works)

    # ORCID public record: profile page as seed (optional)
    if oid and (os.getenv("CRAWL_ORCID_PROFILE_URL", "1") or "1").strip().lower() not in (
        "0",
        "false",
    ):
        prof = f"https://orcid.org/{oid}"
        if prof not in out:
            out.insert(0, prof)

    seen = set()
    unique: List[str] = []
    for u in out:
        u = (u or "").strip()
        if u.startswith("http") and u not in seen:
            seen.add(u)
            unique.append(u)
    print(f"[catalog] catalog URLs collected: {len(unique)} (OpenAlex author={author_id or '—'})")
    return unique
