"""Map LLM output to DB achievement types; filter fields; dedupe keys."""
from __future__ import annotations

import re
import unicodedata
from difflib import SequenceMatcher
from typing import Dict, List, Any, Optional, Set

# Модели часто возвращают англ. WorkType вместо русских подписей из enum.
_LLM_TYPE_ALIASES: Dict[str, str] = {
    "conference-paper": "Конференция",
    "conference_paper": "Конференция",
    "conferencepaper": "Конференция",
    "conference": "Конференция",
    "journal-article": "Статья",
    "journal_article": "Статья",
    "journalarticle": "Статья",
    "article": "Статья",
    "paper": "Статья",
    "grant": "Грант",
    "scholarship": "Стипендия",
    "stipend": "Стипендия",
    "hackathon": "Хакатон",
    "patent": "РИД",
    "intellectual-property": "РИД",
    "intellectual_property": "РИД",
    "internship": "Стажировка",
    "mentoring": "Наставничество/менторство",
    "media-mention": "Упоминание в СМИ",
    "media_mention": "Упоминание в СМИ",
    "media-publication": "Публикация в СМИ",
    "media_publication": "Публикация в СМИ",
    "other": "Другое",
}


def preprocess_llm_type(raw: str) -> str:
    s = (raw or "").strip()
    if not s:
        return s
    key = re.sub(r"[\s_]+", "-", s.lower())
    return _LLM_TYPE_ALIASES.get(key, s)


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
    raw = preprocess_llm_type((raw or "").strip())
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


def _all_catalog_field_titles(type_fields_map: Dict[str, List[Dict]]) -> Set[str]:
    titles: Set[str] = set()
    for fields in type_fields_map.values():
        for f in fields:
            t = (f.get("title") or "").strip()
            if t:
                titles.add(t)
    return titles


def coerce_crawl_achievement_dict(
    ach: Any,
    type_fields_map: Dict[str, List[Dict]],
) -> Optional[Dict[str, Any]]:
    """
    Приводит ответ LLM к виду {title, type, fields, ...}: переносит поля каталога с верхнего уровня в `fields`,
    подставляет заголовок, если модель положила только ключи полей
    """
    if not isinstance(ach, dict):
        return None
    std = {"type", "title", "url", "date", "description", "author_count", "journal_title", "fields", "error"}
    field_titles = _all_catalog_field_titles(type_fields_map)
    merged_fields: Dict[str, Any] = dict(ach.get("fields") or {})
    for k, v in list(ach.items()):
        if k in std or v is None:
            continue
        if k in field_titles:
            merged_fields[k] = v
    title = (ach.get("title") or "").strip()
    if not title:
        for key in (
            "Название достижения",
            "Полное название статьи",
            "Название темы выступления",
            "Полное название мероприятия",
            "Название РИД",
            "Полное название хакатона",
            "Название программы",
            "Название СМИ",
            "Полное название конкурса",
            "Юридическое название организации",
        ):
            v = merged_fields.get(key)
            if isinstance(v, str) and len(v.strip()) > 2:
                title = v.strip()
                break
        if not title:
            v2 = ach.get("Название")
            if isinstance(v2, str) and len(v2.strip()) > 2:
                title = v2.strip()
    if not title:
        for v in merged_fields.values():
            if not isinstance(v, str):
                continue
            s = v.strip()
            if len(s) > 20 and "http" not in s.lower() and "не указ" not in s.lower():
                title = s[:800]
                break
    if not title:
        return None
    ac = ach.get("author_count", 1)
    try:
        author_count = int(ac) if ac is not None else 1
    except (TypeError, ValueError):
        author_count = 1
    return {
        "title": title,
        "type": ach.get("type", "Другое"),
        "url": ach.get("url") or "",
        "date": ach.get("date") or "",
        "description": ach.get("description") or "",
        "author_count": author_count,
        "journal_title": ach.get("journal_title") or "",
        "fields": merged_fields,
    }


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
