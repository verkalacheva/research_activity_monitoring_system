import os
import asyncpg
import re
from typing import List, Dict, Any, Optional

def _normalize_dsn(dsn: str) -> str:
    if dsn.startswith("postgres://"):
        dsn = dsn.replace("postgres://", "postgresql://", 1)
    if "sslmode=" in dsn:
        dsn = re.sub(r'[?&]sslmode=[^&]*', '', dsn)
    return dsn

class DbClient:
    def __init__(self):
        raw = os.getenv("DATABASE_URL")
        self.dsn = _normalize_dsn(raw) if raw else None

    async def fetch_project_criteria(self) -> List[str]:
        if not self.dsn:
            return []
        
        conn = None
        try:
            conn = await asyncpg.connect(self.dsn)
            rows = await conn.fetch("SELECT title FROM dev_project_criteria")
            return [row["title"] for row in rows]
        except Exception as e:
            print(f"[DbClient] Error fetching criteria: {e}")
            return []
        finally:
            if conn:
                await conn.close()

    async def fetch_activity_types(self) -> List[str]:
        if not self.dsn:
            return []
        
        conn = None
        try:
            conn = await asyncpg.connect(self.dsn)
            rows = await conn.fetch("SELECT title FROM dev_employee_activity_types")
            return [row["title"] for row in rows]
        except Exception as e:
            print(f"[DbClient] Error fetching activity types: {e}")
            return []
        finally:
            if conn:
                await conn.close()

    async def fetch_achievement_types_with_fields(self) -> List[Dict[str, Any]]:
        """Return achievement types with their fields: [{title, fields: [{title, field_type}]}]."""
        if not self.dsn:
            return []

        conn = None
        try:
            conn = await asyncpg.connect(self.dsn)
            try:
                type_rows = await conn.fetch(
                    "SELECT id, title, description, icon_name FROM achievement_types "
                    "WHERE deleted_at IS NULL ORDER BY title"
                )
                has_description = True
            except Exception:
                type_rows = await conn.fetch(
                    "SELECT id, title, icon_name FROM achievement_types "
                    "WHERE deleted_at IS NULL ORDER BY title"
                )
                has_description = False
            field_rows = await conn.fetch(
                "SELECT achievement_type_id, title, field_type "
                "FROM achievement_fields WHERE deleted_at IS NULL ORDER BY id"
            )

            fields_by_type: Dict[int, List[Dict]] = {}
            for f in field_rows:
                fields_by_type.setdefault(f["achievement_type_id"], []).append(
                    {"title": f["title"], "field_type": f["field_type"]}
                )

            return [
                {
                    "title": t["title"],
                    "description": ((t["description"] or "").strip() if has_description else ""),
                    "icon_name": (t["icon_name"] or "").strip(),
                    "fields": fields_by_type.get(t["id"], []),
                }
                for t in type_rows
            ]
        except Exception as e:
            print(f"[DbClient] Error fetching achievement types with fields: {e}")
            return []
        finally:
            if conn:
                await conn.close()

    async def fetch_researcher_profile(self, researcher_id: int) -> Optional[Dict[str, Any]]:
        """ORCID/OpenAlex/GitHub and affiliation for smarter web search queries."""
        if not self.dsn or not researcher_id:
            return None

        conn = None
        try:
            conn = await asyncpg.connect(self.dsn)
            row = await conn.fetchrow(
                "SELECT id, name, surname, second_name, orcid_id, openalex_id, github, "
                "faculty, subject_area FROM researchers WHERE id = $1 AND deleted_at IS NULL",
                researcher_id,
            )
            if not row:
                return None
            parts = [row["surname"], row["name"]]
            if row["second_name"]:
                parts.append(row["second_name"])
            full_name = " ".join(p for p in parts if p).strip()
            return {
                "id": row["id"],
                "full_name": full_name,
                "orcid_id": row["orcid_id"] or "",
                "openalex_id": row["openalex_id"] or "",
                "github": row["github"] or "",
                "faculty": row["faculty"] or "",
                "subject_area": row["subject_area"] or "",
            }
        except Exception as e:
            print(f"[DbClient] Error fetching researcher {researcher_id}: {e}")
            return None
        finally:
            if conn:
                await conn.close()

    async def fetch_settings(self) -> Dict[str, str]:
        """Return all app_settings as {key: value} dict, ignoring NULL/empty values."""
        if not self.dsn:
            return {}

        conn = None
        try:
            conn = await asyncpg.connect(self.dsn)
            rows = await conn.fetch(
                "SELECT key, value FROM app_settings WHERE value IS NOT NULL AND value != ''"
            )
            return {row["key"]: row["value"] for row in rows}
        except Exception as e:
            print(f"[DbClient] Error fetching settings: {e}")
            return {}
        finally:
            if conn:
                await conn.close()
