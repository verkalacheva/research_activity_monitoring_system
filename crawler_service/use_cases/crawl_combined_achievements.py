import asyncio
import os
import time
from typing import List, Optional, Dict, Any, Callable

from domain.models import Achievement, DevActivity, CrawlResult
from infrastructure.search_client import SearchClient
from infrastructure.search_queries import build_auto_search_queries
from infrastructure.catalog_fetchers import fetch_catalog_landing_urls
from infrastructure.url_ranking import (
    rank_search_hits,
    is_direct_binary_document_url,
    is_consumer_medical_booking_url,
    is_social_video_url,
)
from infrastructure.crawler_client import CrawlerClient
from infrastructure.page_text_pipeline import build_retrieval_queries
from infrastructure.db_client import DbClient
from infrastructure.crawl_audit import append_audit
from infrastructure.crawl_heuristics import normalize_url_for_dedup
from infrastructure.type_normalization import (
    normalize_title_key,
    fuzzy_match_type,
    filter_fields_for_type,
    build_type_synopsis_lines,
    coerce_crawl_achievement_dict,
)

# Fallback list used only when the DB is unavailable
FALLBACK_ACHIEVEMENT_TYPES = [
    "Статья", "Конференция", "Грант", "РИД", "Хакатон",
    "Стипендия", "Стажировка", "Наставничество/менторство",
    "Упоминание в СМИ", "Публикация в СМИ", "Другое"
]


def _grpc_still_active(cancel_check: Optional[Callable[[], bool]]) -> bool:
    """False когда клиент отменил RPC (кнопка «Стоп» на бэкенде → op.cancel)."""
    if cancel_check is None:
        return True
    try:
        return bool(cancel_check())
    except Exception:
        return False

DATE_HINT = (
    "For the 'date' field extract the most complete date available and format it as ISO 8601: "
    "YYYY-MM-DD if the exact day is known, YYYY-MM if only month and year are known, "
    "or YYYY if only the year is known. Never leave it blank if any date is visible."
)

DUPLICATE_HINT = (
    "Do not output the same real-world achievement twice under different wording. "
    "If the same work appears in multiple sections of the page, keep a single entry with the best date."
)

FIELD_BINDING_HINT = (
    "For each achievement, the 'type' must match exactly one label from the allowed list. "
    "Fill 'fields' only with keys listed for that type; do not copy field names from another type."
)

HTML_PAGE_HINT = (
    "Work with normal HTML pages: university or lab sites, journals, conference pages, "
    "grant or tender portals, hackathon or competition listings, media outlets, "
    "internship or mentoring programme pages, government IP registries (РИД), etc. "
    "Do not invent achievements from PDF filenames, enrollment orders, menus, or unrelated boilerplate. "
    "Government procurement / teacher-service contracts (закупки, «оказание услуг») are NOT personal research "
    "achievements unless the page explicitly names this person as performer in a research or teaching outcome; "
    "prefer {\"achievements\": []} there. "
    "If nothing on the page matches an allowed type for this person, return {\"achievements\": []}."
)

HTML_PAGE_HINT_RECALL = (
    "Work with normal HTML pages: university or lab sites, journals, conference pages, "
    "grant or tender portals, hackathon listings, media, CV-like profiles, ORCID-style publication lists. "
    "When the page is clearly a profile, publication list, or lab page for this person, extract achievements "
    "that plausibly belong to them; use type \"Другое\" with a short justification in description if evidence is partial. "
    "Avoid inventing titles from navigation menus or unrelated boilerplate. "
    "Treat generic procurement pages as low priority unless this person is explicitly named as performer or author."
)

# Явно снимаем перекос в сторону только «Статья / Конференция».
TYPE_COVERAGE_HINT = (
    "Use the full allowed type list from the schema. "
    "Do not default items to 'Статья' or 'Конференция' when the page clearly concerns "
    "a grant or stipend competition, tender award, hackathon, registered IP (РИД), "
    "internship, mentoring programme, or a media mention/publication as defined in the hints below. "
    "Pick the single best-matching label for each distinct real achievement."
)

TYPE_JSON_HINT = (
    "Each achievement object MUST use the schema shape: top-level keys title, type, url, date, description, "
    "author_count, journal_title, and a nested object `fields` for type-specific Russian field titles. "
    "The `type` value MUST be exactly one of the Russian enum strings from the schema — never English "
    "values such as conference-paper, journal-article, or grant."
)

# Различение похожих типов из каталога (русские названия в поле type).
TYPE_DISAMBIGUATION_HINT = (
    "Type disambiguation (use Russian labels exactly as in the allowed list): "
    "'Статья' = peer-reviewed or scholarly article in a journal or proceedings volume with bibliographic record; "
    "not a short news piece. "
    "'Конференция' = talk, poster, or proceedings at a scientific event (title of contribution + event). "
    "'Упоминание в СМИ' = third-party media mentions the person or their work in news. "
    "'Публикация в СМИ' = the person authored or co-authored an article/column in a media outlet. "
    "'РИД' = registered intellectual result (software patent, certificate of registration, etc.) on official registry pages. "
    "'Хакатон' = hackathon/competition with dates and official name. "
    "'Грант' = funded grant or competitive project award, not a generic scholarship unless clearly a grant program. "
    "'Стипендия' = scholarship/stipend competition with published winner lists. "
    "'Стажировка' = internship at an organization with start date. "
    "'Наставничество/менторство' = structured mentoring program with official page. "
    "If the page does not clearly fit one type, use 'Другое' and explain in fields."
)


def _inter_url_delay() -> float:
    try:
        return max(0.0, float(os.getenv("CRAWL_INTER_URL_DELAY_SEC", "15")))
    except ValueError:
        return 15.0


def _crawl_concurrency() -> int:
    """Параллельная обработка URL (asyncio + Semaphore). 1 = как раньше, по очереди."""
    raw = (os.getenv("CRAWL_CONCURRENCY", "5") or "5").strip()
    try:
        return max(1, min(64, int(raw)))
    except ValueError:
        return 5


def _chunk_threshold_override() -> int:
    raw = os.getenv("CRAWL_LLM_CHUNK_THRESHOLD", "").strip()
    if not raw:
        return 0
    try:
        return max(500, int(raw))
    except ValueError:
        return 0


def _effective_html_page_hint() -> str:
    """CRAWL_PROMPT_MODE=recall — мягче подсказки (больше recall); precision — по умолчанию."""
    mode = (os.getenv("CRAWL_PROMPT_MODE", "precision") or "precision").strip().lower()
    if mode == "recall":
        return HTML_PAGE_HINT_RECALL
    return HTML_PAGE_HINT


def _max_urls_per_sync() -> int:
    """CRAWL_MAX_URLS_PER_SYNC — верхняя граница URL за один прогон (0 = без лимита)."""
    raw = (os.getenv("CRAWL_MAX_URLS_PER_SYNC", "") or "").strip()
    if not raw:
        return 5
    try:
        return max(0, int(raw))
    except ValueError:
        return 0


def _merge_unique_urls(primary: List[str], secondary: List[str]) -> List[str]:
    seen = set()
    out: List[str] = []
    for u in primary + secondary:
        u = (u or "").strip()
        if u.startswith("http") and u not in seen:
            seen.add(u)
            out.append(u)
    return out


def _without_github_urls(urls: List[str]) -> List[str]:
    """GitHub обрабатывается integration_service; краулер не открывает github.com."""
    return [u for u in urls if "github.com" not in (u or "").lower()]


def _build_fields_hint(type_map: Dict[str, List[Dict]]) -> str:
    """Build a textual instruction that tells the LLM which fields to fill per type."""
    lines = [
        "For each achievement fill the 'fields' object with type-specific values "
        "(use the exact Russian field names as keys, string values):"
    ]
    for type_title, fields in type_map.items():
        if not fields:
            continue
        field_names = ", ".join(f'"{f["title"]}"' for f in fields)
        lines.append(f'  - {type_title}: {{{field_names}}}')
    lines.append(
        "Fill only the fields that correspond to the detected type. "
        "Leave unrecognised fields out of the object."
    )
    return "\n".join(lines)


class CrawlAchievementsUseCase:
    def __init__(self, search_client: SearchClient, crawler_client: CrawlerClient):
        self.search_client = search_client
        self.crawler_client = crawler_client
        self.db_client = DbClient()

    @staticmethod
    def _collect_achievements_from_extracted(
        extracted: Any,
        target_url: str,
        type_fields_map: Dict[str, List[Dict]],
    ) -> List[Achievement]:
        out: List[Achievement] = []
        if not isinstance(extracted, list):
            return out
        for item in extracted:
            candidates = item.get("achievements") if isinstance(item.get("achievements"), list) else None
            if candidates is None and item.get("title"):
                candidates = [item]
            for ach in (candidates or []):
                coerced = coerce_crawl_achievement_dict(ach, type_fields_map)
                if not coerced:
                    continue
                out.append(
                    Achievement(
                        title=coerced["title"],
                        type=coerced.get("type", "Другое"),
                        url=(coerced.get("url") or "").strip() or target_url,
                        date=coerced.get("date", "") or "",
                        description=coerced.get("description", "") or "",
                        author_count=int(coerced.get("author_count") or 1),
                        journal_title=coerced.get("journal_title", "") or "",
                        extra_fields=coerced.get("fields") or {},
                    )
                )
        return out

    async def execute(
        self,
        researcher_name: str,
        url: Optional[str] = None,
        auto_search: bool = False,
        github_username: Optional[str] = None,
        researcher_id: int = 0,
        cancel_check: Optional[Callable[[], bool]] = None,
    ) -> CrawlResult:
        profile = await self.db_client.fetch_researcher_profile(researcher_id) if researcher_id else None
        if profile and profile.get("full_name"):
            researcher_name = profile["full_name"]

        _ = github_username  # gRPC поле; GitHub не краулится — см. integration_service.

        print(
            f"Executing CrawlAchievementsUseCase for {researcher_name} "
            f"(id={researcher_id}); github.com excluded — use GitHub integration for dev data."
        )

        achievement_types_with_fields = await self.db_client.fetch_achievement_types_with_fields()
        if achievement_types_with_fields:
            achievement_type_titles = [t["title"] for t in achievement_types_with_fields]
            type_fields_map: Dict[str, List[Dict]] = {
                t["title"]: t["fields"] for t in achievement_types_with_fields
            }
            type_synopsis = build_type_synopsis_lines(achievement_types_with_fields)
        else:
            achievement_type_titles = list(FALLBACK_ACHIEVEMENT_TYPES)
            type_fields_map = {}
            type_synopsis = ""

        if not _grpc_still_active(cancel_check):
            return CrawlResult(
                achievements=[],
                dev_activities=[],
                project_criteria_met=[],
                warnings=list(dict.fromkeys(self.crawler_client.warnings)),
            )

        urls_to_crawl: List[str] = []

        # 1. Catalog (OpenAlex/ORCID) + DDG search + optional manual URL
        catalog_urls: List[str] = []
        if profile and researcher_id:
            catalog_urls = await fetch_catalog_landing_urls(profile)
            append_audit(
                {
                    "event": "catalog_urls",
                    "researcher_id": researcher_id,
                    "urls": catalog_urls,
                    "count": len(catalog_urls),
                }
            )

        if auto_search and researcher_name:
            queries = build_auto_search_queries(
                researcher_name,
                profile,
                achievement_type_titles,
            )
            append_audit(
                {
                    "event": "search_queries",
                    "researcher_id": researcher_id,
                    "queries": queries,
                }
            )
            found = await self.search_client.search_urls_multi(queries)
            ranked = rank_search_hits(found, profile, researcher_name)
            urls_to_crawl.extend(_merge_unique_urls(catalog_urls, ranked))
        else:
            urls_to_crawl.extend(catalog_urls)

        manual = (url or "").strip()
        if manual:
            if manual not in urls_to_crawl:
                urls_to_crawl.insert(0, manual)
            else:
                urls_to_crawl.remove(manual)
                urls_to_crawl.insert(0, manual)

        urls_to_crawl = _without_github_urls(urls_to_crawl)
        skipped_noise = [
            u
            for u in urls_to_crawl
            if is_direct_binary_document_url(u)
            or is_consumer_medical_booking_url(u)
            or is_social_video_url(u)
        ]
        urls_to_crawl = [
            u
            for u in urls_to_crawl
            if not is_direct_binary_document_url(u)
            and not is_consumer_medical_booking_url(u)
            and not is_social_video_url(u)
        ]
        if skipped_noise:
            samples = []
            for u in skipped_noise[:3]:
                s = (u or "").strip()
                if len(s) > 90:
                    s = s[:87] + "..."
                samples.append(s)
            extra = f" (+ещё {len(skipped_noise) - 3})" if len(skipped_noise) > 3 else ""
            note = (
                f"Пропущено {len(skipped_noise)} ссылок (бинарные файлы по настройкам, запись к врачу или видео в соцсетях): "
                + "; ".join(samples)
                + extra
            )
            if note not in self.crawler_client.warnings:
                self.crawler_client.warnings.append(note)

        mx = _max_urls_per_sync()
        if mx > 0 and len(urls_to_crawl) > mx:
            urls_to_crawl = urls_to_crawl[:mx]

        seen_u: set = set()
        dedup_urls: List[str] = []
        for u in urls_to_crawl:
            k = normalize_url_for_dedup(u)
            if not k or k in seen_u:
                continue
            seen_u.add(k)
            dedup_urls.append(u)
        urls_to_crawl = dedup_urls

        print(
            f"[CrawlAchievements] urls after search+catalog+rank: {len(urls_to_crawl)} "
            f"(max_urls={mx or '∞'})"
        )

        append_audit(
            {
                "event": "urls_selected",
                "researcher_id": researcher_id,
                "urls": urls_to_crawl,
                "url_count": len(urls_to_crawl),
                "max_urls_cap": mx,
            }
        )

        if not _grpc_still_active(cancel_check):
            return CrawlResult(
                achievements=[],
                dev_activities=[],
                project_criteria_met=[],
                warnings=list(dict.fromkeys(self.crawler_client.warnings)),
            )

        achievements: List[Achievement] = []
        dev_activities: List[DevActivity] = []
        project_criteria_met: List[str] = []

        delay = _inter_url_delay()
        chunk_th = _chunk_threshold_override()
        retrieval_queries = build_retrieval_queries(
            researcher_name,
            profile,
            achievement_type_titles,
        )

        fields_hint = _build_fields_hint(type_fields_map)
        type_hint = (
            "For the 'type' field use ONLY one of these exact values (in Russian): "
            + ", ".join(f'"{t}"' for t in achievement_type_titles)
            + ". If unsure, use \"Другое\"."
        )
        if type_synopsis:
            type_hint += "\nType reference from catalog:\n" + type_synopsis

        schema: Dict[str, Any] = {
            "type": "object",
            "properties": {
                "achievements": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "title": {"type": "string"},
                            "type": {"type": "string", "enum": achievement_type_titles},
                            "date": {
                                "type": "string",
                                "description": "ISO 8601 date: YYYY-MM-DD, YYYY-MM, or YYYY"
                            },
                            "description": {"type": "string"},
                            "author_count": {"type": "integer"},
                            "journal_title": {"type": "string"},
                            "url": {"type": "string"},
                            "fields": {
                                "type": "object",
                                "description": "Type-specific field values keyed by exact Russian field name",
                                "additionalProperties": {"type": "string"}
                            }
                        },
                        "required": ["title", "type"]
                    }
                }
            },
            "required": ["achievements"]
        }

        instruction = (
            f"Extract research achievements for {researcher_name}. "
            f"{_effective_html_page_hint()} "
            f"{TYPE_COVERAGE_HINT} "
            f"{TYPE_JSON_HINT} "
            f"{FIELD_BINDING_HINT} "
            f"{TYPE_DISAMBIGUATION_HINT} "
            f"{DUPLICATE_HINT} "
            f"{type_hint} "
            f"{DATE_HINT} "
            f"{fields_hint}"
        )

        concurrency = _crawl_concurrency()
        crawl_start = time.perf_counter()

        # 3. Process URLs (только вне GitHub; dev metrics по репозиториям — через integration_service)
        if concurrency <= 1:
            for url_index, target_url in enumerate(urls_to_crawl):
                if not _grpc_still_active(cancel_check):
                    break
                if url_index > 0 and delay > 0:
                    await asyncio.sleep(delay)

                extracted = await self._extract_with_optional_chunk(
                    target_url, schema, instruction, chunk_th, retrieval_queries
                )
                achievements.extend(
                    self._collect_achievements_from_extracted(
                        extracted, target_url, type_fields_map
                    )
                )
        else:
            if delay > 0:
                print(
                    f"[CrawlAchievements] parallel mode (CRAWL_CONCURRENCY={concurrency}): "
                    f"CRAWL_INTER_URL_DELAY_SEC={delay} ignored between URLs"
                )
            sem = asyncio.Semaphore(concurrency)

            async def _one_url(target_url: str) -> List[Achievement]:
                async with sem:
                    if not _grpc_still_active(cancel_check):
                        return []
                    extracted = await self._extract_with_optional_chunk(
                        target_url, schema, instruction, chunk_th, retrieval_queries
                    )
                    return self._collect_achievements_from_extracted(
                        extracted, target_url, type_fields_map
                    )

            pending = {asyncio.create_task(_one_url(u)) for u in urls_to_crawl}
            n_err = 0
            while pending:
                if not _grpc_still_active(cancel_check):
                    n_cancel = len(pending)
                    for t in pending:
                        t.cancel()
                    await asyncio.gather(*pending, return_exceptions=True)
                    append_audit(
                        {
                            "event": "crawl_parallel_cancelled",
                            "researcher_id": researcher_id,
                            "cancelled_tasks": n_cancel,
                        }
                    )
                    break
                done, pending = await asyncio.wait(
                    pending,
                    timeout=0.35,
                    return_when=asyncio.FIRST_COMPLETED,
                )
                for t in done:
                    try:
                        batch = t.result()
                    except asyncio.CancelledError:
                        continue
                    except Exception as e:
                        n_err += 1
                        print(f"[CrawlAchievements] URL task error: {e}")
                        continue
                    achievements.extend(batch)
            if n_err:
                append_audit(
                    {
                        "event": "parallel_url_task_errors",
                        "researcher_id": researcher_id,
                        "count": n_err,
                    }
                )

        append_audit(
            {
                "event": "crawl_urls_phase",
                "researcher_id": researcher_id,
                "urls_count": len(urls_to_crawl),
                "concurrency": concurrency,
                "duration_sec": round(time.perf_counter() - crawl_start, 3),
            }
        )

        # 4. Stage 2 (programmatic): normalize types + allowed fields per DB
        normalized: List[Achievement] = []
        for a in achievements:
            nt = fuzzy_match_type(a.type, achievement_type_titles)
            fields = filter_fields_for_type(a.extra_fields, nt, type_fields_map)
            normalized.append(
                Achievement(
                    title=a.title,
                    type=nt,
                    url=a.url,
                    date=a.date,
                    description=a.description,
                    author_count=a.author_count,
                    journal_title=a.journal_title,
                    extra_fields=fields,
                )
            )

        # Deduplicate by normalized title
        unique_map: Dict[str, Achievement] = {}
        for a in normalized:
            key = normalize_title_key(a.title)
            if not key:
                continue
            if key not in unique_map:
                unique_map[key] = a
            else:
                prev = unique_map[key]
                if len(a.description or "") > len(prev.description or ""):
                    unique_map[key] = a

        unique_criteria = list(set(project_criteria_met))

        merged_activities: Dict[str, int] = {}
        for da in dev_activities:
            merged_activities[da.activity_type] = merged_activities.get(da.activity_type, 0) + da.count

        final_activities = [DevActivity(activity_type=k, count=v) for k, v in merged_activities.items()]

        result = CrawlResult(
            achievements=list(unique_map.values()),
            dev_activities=final_activities,
            project_criteria_met=unique_criteria,
            warnings=list(dict.fromkeys(self.crawler_client.warnings)),
        )

        append_audit(
            {
                "event": "crawl_complete",
                "researcher_id": researcher_id,
                "achievements_count": len(result.achievements),
                "dev_activities_count": len(result.dev_activities),
                "warnings_count": len(result.warnings),
                "extraction_stats": dict(self.crawler_client.extraction_stats),
                "prompt_mode": (os.getenv("CRAWL_PROMPT_MODE", "precision") or "precision").strip(),
            }
        )

        return result

    async def _extract_with_optional_chunk(
        self,
        target_url: str,
        schema: Dict[str, Any],
        instruction: str,
        chunk_th: int,
        retrieval_queries: Optional[List[str]] = None,
    ):
        if chunk_th > 0:
            return await self.crawler_client.crawl_and_extract(
                target_url,
                schema,
                instruction,
                chunk_token_threshold=chunk_th,
                retrieval_queries=retrieval_queries,
            )
        return await self.crawler_client.crawl_and_extract(
            target_url, schema, instruction, retrieval_queries=retrieval_queries
        )
