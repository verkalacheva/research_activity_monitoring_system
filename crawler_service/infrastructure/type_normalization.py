"""Map LLM output to DB achievement types; filter fields; dedupe keys."""
from __future__ import annotations

import re
import unicodedata
from difflib import SequenceMatcher
from typing import Dict, List, Any, Optional


def normalize_title_key(title: str) -> str:
    """Stable key for deduplication across URLs."""
    if not title:
        return ""
    t = unicodedata.normalize("NFKC", title)
    t = t.lower().strip()
    t = re.sub(r"[^\w\s\u0400-\u04ff]", " ", t, flags=re.UNICODE)
    t = re.sub(r"\s+", " ", t).strip()
    return t


def fuzzy_match_type(raw: str, allowed: List[str]) -> str:
    """Map a free-form or slightly wrong type string to the closest DB title."""
    raw = (raw or "").strip()
    if not allowed:
        return raw or "Другое"
    if not raw:
        return "Другое" if "Другое" in allowed else allowed[0]

    raw_lower = raw.lower()
    for a in allowed:
        if a.lower() == raw_lower:
            return a
        if raw_lower in a.lower() or a.lower() in raw_lower:
            if len(a) <= len(raw) * 2:
                return a

    best: Optional[str] = None
    best_score = 0.0
    for a in allowed:
        s = SequenceMatcher(None, raw_lower, a.lower()).ratio()
        if s > best_score:
            best_score = s
            best = a

    if best is not None and best_score >= 0.52:
        return best
    return "Другое" if "Другое" in allowed else (best or allowed[0])


def filter_fields_for_type(
    fields: Dict[str, Any],
    type_title: str,
    type_fields_map: Dict[str, List[Dict]],
) -> Dict[str, str]:
    """Keep only field titles defined for this achievement type."""
    allowed_titles = {f["title"] for f in type_fields_map.get(type_title, [])}
    if not allowed_titles:
        return {k: str(v) for k, v in (fields or {}).items() if v is not None}
    out: Dict[str, str] = {}
    for k, v in (fields or {}).items():
        if k in allowed_titles and v is not None:
            out[k] = str(v).strip()
    return out


def build_type_synopsis_lines(types_with_meta: List[Dict[str, Any]]) -> str:
    """Human-readable type hints for the LLM (title + optional DB description)."""
    lines: List[str] = []
    for t in types_with_meta:
        title = t.get("title") or ""
        if not title:
            continue
        desc = (t.get("description") or "").strip()
        icon = (t.get("icon_name") or "").strip()
        extra = []
        if desc:
            extra.append(f"описание: {desc}")
        if icon:
            extra.append(f"иконка: {icon}")
        if extra:
            lines.append(f'  - "{title}" — ' + "; ".join(extra))
        else:
            lines.append(f'  - "{title}"')
    return "\n".join(lines)
