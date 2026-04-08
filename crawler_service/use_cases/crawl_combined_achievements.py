import asyncio
import json
import os
from typing import List, Optional, Dict, Any

from domain.models import Achievement, DevActivity, CrawlResult
from infrastructure.search_client import SearchClient
from infrastructure.search_queries import build_auto_search_queries
from infrastructure.url_ranking import rank_urls
from infrastructure.crawler_client import CrawlerClient
from infrastructure.db_client import DbClient
from infrastructure.crawl_audit import append_audit
from infrastructure.type_normalization import (
    normalize_title_key,
    fuzzy_match_type,
    filter_fields_for_type,
    build_type_synopsis_lines,
)

# Fallback list used only when the DB is unavailable
FALLBACK_ACHIEVEMENT_TYPES = [
    "Статья", "Конференция", "Грант", "РИД", "Хакатон",
    "Стипендия", "Стажировка", "Наставничество/менторство",
    "Упоминание в СМИ", "Публикация в СМИ", "Другое"
]

DATE_HINT = (
    "For the 'date' field extract the most complete date available and format it as ISO 8601: "
    "YYYY-MM-DD if the exact day is known, YYYY-MM if only month and year are known, "
    "or YYYY if only the year is known. Never leave it blank if any date is visible."
)

DUPLICATE_HINT = (
    "Do not output the same publication or achievement twice under different wording. "
    "If the same work appears in multiple sections of the page, keep a single entry with the best date."
)

FIELD_BINDING_HINT = (
    "For each achievement, the 'type' must match exactly one label from the allowed list. "
    "Fill 'fields' only with keys listed for that type; do not copy field names from another type."
)


def _max_urls() -> int:
    try:
        return max(1, min(12, int(os.getenv("CRAWL_MAX_URLS", "5"))))
    except ValueError:
        return 5


def _inter_url_delay() -> float:
    try:
        return max(0.0, float(os.getenv("CRAWL_INTER_URL_DELAY_SEC", "15")))
    except ValueError:
        return 15.0


def _chunk_threshold_override() -> int:
    raw = os.getenv("CRAWL_LLM_CHUNK_THRESHOLD", "").strip()
    if not raw:
        return 0
    try:
        return max(500, int(raw))
    except ValueError:
        return 0


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

    async def execute(
        self,
        researcher_name: str,
        url: Optional[str] = None,
        auto_search: bool = False,
        github_username: Optional[str] = None,
        researcher_id: int = 0,
    ) -> CrawlResult:
        profile = await self.db_client.fetch_researcher_profile(researcher_id) if researcher_id else None
        if profile and profile.get("full_name"):
            researcher_name = profile["full_name"]

        print(
            f"Executing CrawlAchievementsUseCase for {researcher_name} "
            f"(id={researcher_id}, GitHub: {github_username})"
        )

        urls_to_crawl: List[str] = []

        # 1. Collect URLs (multi-query + rank + optional manual URL)
        if auto_search and researcher_name:
            queries = build_auto_search_queries(researcher_name, profile)
            append_audit(
                {
                    "event": "search_queries",
                    "researcher_id": researcher_id,
                    "queries": queries,
                }
            )
            found = await self.search_client.search_urls_multi(queries)
            ranked = rank_urls(found, profile)
            urls_to_crawl.extend(ranked)

        manual = (url or "").strip()
        if manual:
            if manual not in urls_to_crawl:
                urls_to_crawl.insert(0, manual)
            else:
                urls_to_crawl.remove(manual)
                urls_to_crawl.insert(0, manual)

        max_u = _max_urls()
        urls_to_crawl = urls_to_crawl[:max_u]

        append_audit(
            {
                "event": "urls_selected",
                "researcher_id": researcher_id,
                "urls": urls_to_crawl,
                "max_urls": max_u,
            }
        )

        # 2. Fetch config from DB
        project_criteria = await self.db_client.fetch_project_criteria()
        activity_types = await self.db_client.fetch_activity_types()
        achievement_types_with_fields = await self.db_client.fetch_achievement_types_with_fields()

        if achievement_types_with_fields:
            achievement_type_titles = [t["title"] for t in achievement_types_with_fields]
            type_fields_map: Dict[str, List[Dict]] = {
                t["title"]: t["fields"] for t in achievement_types_with_fields
            }
            type_synopsis = build_type_synopsis_lines(achievement_types_with_fields)
        else:
            achievement_type_titles = FALLBACK_ACHIEVEMENT_TYPES
            type_fields_map = {}
            type_synopsis = ""

        achievements: List[Achievement] = []
        dev_activities: List[DevActivity] = []
        project_criteria_met: List[str] = []

        delay = _inter_url_delay()
        chunk_th = _chunk_threshold_override()

        # 3. Process URLs
        for url_index, target_url in enumerate(urls_to_crawl):
            if url_index > 0 and delay > 0:
                await asyncio.sleep(delay)

            is_github_repo = "github.com" in target_url and len(target_url.split("/")) >= 5

            if is_github_repo:
                schema = {
                    "type": "object",
                    "properties": {
                        "activities": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string", "enum": activity_types},
                                    "count": {"type": "integer"}
                                },
                                "required": ["type", "count"]
                            }
                        },
                        "criteria_met": {
                            "type": "array",
                            "items": {"type": "string", "enum": project_criteria}
                        }
                    }
                }

                gh_instruction = (
                    f"Analyze this GitHub repository for project {researcher_name}. "
                    f"Identify which of these criteria are met: {', '.join(project_criteria)}. "
                    f"Also estimate stats for: {', '.join(activity_types)}."
                )
                extracted = await self._extract_with_optional_chunk(
                    target_url, schema, gh_instruction, chunk_th
                )

                if isinstance(extracted, list):
                    for item in extracted:
                        if item.get("activities"):
                            for act in item["activities"]:
                                dev_activities.append(DevActivity(activity_type=act["type"], count=act["count"]))
                        if item.get("criteria_met"):
                            project_criteria_met.extend(item["criteria_met"])
                elif isinstance(extracted, dict):
                    if extracted.get("activities"):
                        for act in extracted["activities"]:
                            dev_activities.append(DevActivity(activity_type=act["type"], count=act["count"]))
                    if extracted.get("criteria_met"):
                        project_criteria_met.extend(extracted["criteria_met"])
            else:
                fields_hint = _build_fields_hint(type_fields_map)
                type_hint = (
                    "For the 'type' field use ONLY one of these exact values (in Russian): "
                    + ", ".join(f'"{t}"' for t in achievement_type_titles)
                    + ". If unsure, use \"Другое\"."
                )
                if type_synopsis:
                    type_hint += "\nType reference from catalog:\n" + type_synopsis

                schema = {
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
                    f"{FIELD_BINDING_HINT} "
                    f"{DUPLICATE_HINT} "
                    f"{type_hint} "
                    f"{DATE_HINT} "
                    f"{fields_hint}"
                )

                extracted = await self._extract_with_optional_chunk(
                    target_url, schema, instruction, chunk_th
                )

                if isinstance(extracted, list):
                    for item in extracted:
                        candidates = item.get("achievements") if isinstance(item.get("achievements"), list) else None
                        if candidates is None and item.get("title"):
                            candidates = [item]
                        for ach in (candidates or []):
                            if ach.get("title"):
                                achievements.append(Achievement(
                                    title=ach["title"],
                                    type=ach.get("type", "Другое"),
                                    url=ach.get("url", target_url),
                                    date=ach.get("date", ""),
                                    description=ach.get("description", ""),
                                    author_count=ach.get("author_count", 1),
                                    journal_title=ach.get("journal_title", ""),
                                    extra_fields=ach.get("fields") or {},
                                ))

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
            }
        )

        return result

    async def _extract_with_optional_chunk(
        self,
        target_url: str,
        schema: Dict[str, Any],
        instruction: str,
        chunk_th: int,
    ):
        if chunk_th > 0:
            return await self.crawler_client.crawl_and_extract(
                target_url, schema, instruction, chunk_token_threshold=chunk_th
            )
        return await self.crawler_client.crawl_and_extract(target_url, schema, instruction)
