"""Build diversified search queries for auto_search (internet discovery)."""
from typing import List, Dict, Any, Optional


def build_auto_search_queries(
    researcher_name: str,
    profile: Optional[Dict[str, Any]],
) -> List[str]:
    """
    Multiple narrow queries improve recall vs a single generic string.
    Queries are deduped; order matters (broader first).
    """
    name = (researcher_name or "").strip()
    if not name:
        return []

    p = profile or {}
    aff = " ".join(
        x for x in [p.get("faculty") or "", p.get("subject_area") or ""] if x
    ).strip()
    quoted = f'"{name}"'
    base_with_aff = f"{quoted} {aff}".strip() if aff else quoted

    queries: List[str] = [
        f"{base_with_aff} научные публикации статьи",
        f"{base_with_aff} грант конференция награда",
        f"{quoted} достижения публикации Scopus",
    ]

    oid = (p.get("orcid_id") or "").strip()
    if oid:
        oid_clean = oid.replace("https://orcid.org/", "").replace("http://orcid.org/", "").strip()
        queries.append(f"{oid_clean} ORCID {name}")
        queries.append(f"orcid.org/{oid_clean.split('/')[-1]}")

    oax = (p.get("openalex_id") or "").strip()
    if oax:
        queries.append(f'openalex.org/{oax.strip("/").split("/")[-1]} {quoted}')

    gh = (p.get("github") or "").strip()
    if gh:
        gh_user = gh.replace("https://github.com/", "").replace("http://github.com/", "").strip("/").split("/")[0]
        if gh_user:
            queries.append(f"site:github.com {gh_user}")

    seen = set()
    out: List[str] = []
    for q in queries:
        q = " ".join(q.split())
        if len(q) < 8 or q in seen:
            continue
        seen.add(q)
        out.append(q)
    return out[:12]
