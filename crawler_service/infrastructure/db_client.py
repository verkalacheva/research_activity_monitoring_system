import os
import asyncpg
from typing import List, Dict, Any, Optional

# Таймаут установления TCP/TLS к БД (сек), чтобы не висеть при неверном хосте/порте
_DEFAULT_CONNECT_TIMEOUT = 15.0


def _normalize_dsn(dsn: str) -> str:
    """Только схема URI; sslmode и остальные query оставляем (asyncpg понимает libpq-строку)."""
    if dsn.startswith("postgres://"):
        dsn = dsn.replace("postgres://", "postgresql://", 1)
    return dsn


class DbClient:
    def __init__(self):
        raw = os.getenv("DATABASE_URL")
        self._raw_dsn = raw
        self.dsn = _normalize_dsn(raw) if raw else None
        # Last successfully loaded app_settings snapshot.
        # Used as a resilience fallback when DB has transient timeouts.
        self._settings_cache: Dict[str, str] = {}

    def _connect_timeout(self) -> float:
        try:
            return float(os.getenv("DB_CONNECT_TIMEOUT_SEC", str(_DEFAULT_CONNECT_TIMEOUT)))
        except ValueError:
            return _DEFAULT_CONNECT_TIMEOUT

    async def _connect(self):
        """Один таймаут на connect; DSN с ?sslmode= из docker-compose не режем."""
        if not self.dsn:
            raise RuntimeError("DATABASE_URL is not set")
        return await asyncpg.connect(self.dsn, timeout=self._connect_timeout())

    async def fetch_project_criteria(self) -> List[str]:
        if not self.dsn:
            return []

        conn = None
        try:
            conn = await self._connect()
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
            conn = await self._connect()
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
            conn = await self._connect()
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
            conn = await self._connect()
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

    async def ping(self) -> bool:
        if not self.dsn:
            return True
        conn = None
        try:
            conn = await self._connect()
            await conn.execute("SELECT 1")
            return True
        except Exception:
            return False
        finally:
            if conn:
                await conn.close()

    async def fetch_settings(self) -> Dict[str, str]:
        """Ключ LLM и прочие app_settings — единственный источник с UI (таблица app_settings)."""
        if not self.dsn:
            print("[DbClient] fetch_settings: DATABASE_URL is not set")
            return {}

        attempts = 2
        for attempt in range(1, attempts + 1):
            conn = None
            try:
                conn = await self._connect()
                rows = await conn.fetch(
                    "SELECT key, value FROM app_settings WHERE value IS NOT NULL AND value != ''"
                )
                data = {row["key"]: row["value"] for row in rows}
                self._settings_cache = data
                return data
            except Exception as e:
                detail = str(e).strip() or repr(e)
                dsn_hint = (self._raw_dsn or "")[:80]
                print(
                    f"[DbClient] Error fetching settings (attempt {attempt}/{attempts}): {detail} "
                    f"(dsn_host_ok={bool(self.dsn)}, dsn_prefix={dsn_hint!r})"
                )
                if attempt < attempts:
                    await asyncio.sleep(0.25)
                    continue
                if self._settings_cache:
                    print(
                        "[DbClient] Using cached app_settings due to DB timeout/error "
                        f"({len(self._settings_cache)} keys)"
                    )
                    return dict(self._settings_cache)
                return {}
            finally:
                if conn:
                    await conn.close()
