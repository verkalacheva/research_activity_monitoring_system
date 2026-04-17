"""Build diversified search queries for auto_search (internet discovery)."""
from typing import List, Dict, Any, Optional

# Уточнения к запросу DDG: для «Имя + Грант» выдача часто пустая/мусорная без контекста.
_TYPE_QUERY_EXTRAS: Dict[str, str] = {
    "Грант": "грантовый конкурс победитель РНФ",
    "Стипендия": "стипендия конкурс победители список",
    "Хакатон": "хакатон hackathon devpost codenrock mlh case-in",
    "РИД": "регистрация РИД программа для ЭВМ патент",
    "Стажировка": "стажировка программа университет",
    "Наставничество/менторство": "наставничество менторство программа",
    "Упоминание в СМИ": "новости СМИ упоминание",
    "Публикация в СМИ": "публикация СМИ автор колонка",
}

_TYPE_QUERY_EXTRAS_CF: Dict[str, str] = {
    k.strip().casefold(): v for k, v in _TYPE_QUERY_EXTRAS.items()
}


def _query_extra_for_type(title: str) -> str:
    return _TYPE_QUERY_EXTRAS_CF.get((title or "").strip().casefold(), "")


def build_auto_search_queries(
    researcher_name: str,
    profile: Optional[Dict[str, Any]],
    achievement_type_titles: List[str],
) -> List[str]:
    """
    Строит запросы к поиску из каталога типов достижений (БД) + ORCID/OpenAlex из профиля.
    По одному запросу на тип (кроме «Другое»), затем идентификаторы.
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

    queries: List[str] = []
    titles = [t.strip() for t in (achievement_type_titles or []) if (t or "").strip()]
    for title in titles:
        if title.casefold() == "другое":
            continue
        extra = _query_extra_for_type(title)
        type_part = f"{title} {extra}".strip() if extra else title
        # Один запрос на тип из каталога; с аффилиацией — если есть (сужает выдачу).
        if aff:
            queries.append(f"{base_with_aff} {type_part}")
        else:
            queries.append(f"{quoted} {type_part}")

    if not queries:
        queries.append(f"{base_with_aff} научные достижения" if aff else f"{quoted} научные достижения")

    oid = (p.get("orcid_id") or "").strip()
    if oid:
        oid_clean = oid.replace("https://orcid.org/", "").replace("http://orcid.org/", "").strip()
        queries.append(f"{oid_clean} ORCID {name}")
        queries.append(f"orcid.org/{oid_clean.split('/')[-1]}")

    oax = (p.get("openalex_id") or "").strip()
    if oax:
        queries.append(f'openalex.org/{oax.strip("/").split("/")[-1]} {quoted}')

    seen = set()
    out: List[str] = []
    for q in queries:
        q = " ".join(q.split())
        if len(q) < 8 or q in seen:
            continue
        seen.add(q)
        out.append(q)

    # Доп. запросы: публикации, elibrary, профиль вуза (не привязаны к одному типу из каталога).
    out.extend(_build_discovery_queries(name, p, seen))
    final: List[str] = []
    seen2 = set()
    for q in out:
        q = " ".join(q.split())
        if len(q) < 8 or q in seen2:
            continue
        seen2.add(q)
        final.append(q)
    return final


def _domain_hint(profile: Optional[Dict[str, Any]]) -> str:
    """Грубый site: из аффилиации (первое слово домена не угадываем — только явные шаблоны)."""
    if not profile:
        return ""
    fac = (profile.get("faculty") or "").lower()
    for token, domain in (
        ("itmo", "itmo.ru"),
        ("мгу", "msu.ru"),
        ("спбгу", "spbu.ru"),
        ("вышка", "hse.ru"),
        ("мифи", "mephi.ru"),
    ):
        if token in fac:
            return domain
    return ""


def _build_discovery_queries(
    name: str,
    profile: Optional[Dict[str, Any]],
    existing: set,
) -> List[str]:
    quoted = f'"{name}"'
    aff = " ".join(
        x for x in [(profile or {}).get("faculty") or "", (profile or {}).get("subject_area") or ""]
        if x
    ).strip()
    base = f"{quoted} {aff}".strip() if aff else quoted
    extra: List[str] = [
        f"{base} публикации elibrary",
        f"{base} научные публикации",
        f"{base} профиль преподавателя",
        f"{quoted} ORCID публикации",
    ]
    dom = _domain_hint(profile)
    if dom:
        extra.append(f"{quoted} site:{dom}")
    out: List[str] = []
    for q in extra:
        q = " ".join(q.split())
        if len(q) >= 8 and q not in existing:
            existing.add(q)
            out.append(q)
    return out
