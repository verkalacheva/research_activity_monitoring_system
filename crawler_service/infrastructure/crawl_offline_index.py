"""
Офлайн-индекс: URL → метаданные снимка (preview, hash, ts) в Redis.

Требуется CRAWL_REDIS_URL или REDIS_URL и CRAWL_OFFLINE_INDEX_ENABLED=1.
"""
from __future__ import annotations

import hashlib
import json
import os
import time
from typing import Any, Dict, Optional


def _enabled() -> bool:
    return (os.getenv("CRAWL_OFFLINE_INDEX_ENABLED", "0") or "0").strip().lower() in (
        "1",
        "true",
        "yes",
        "on",
    )


def _redis_url() -> str:
    return (os.getenv("CRAWL_REDIS_URL") or os.getenv("REDIS_URL") or "").strip()


def _redis_key_prefix() -> str:
    return (os.getenv("CRAWL_REDIS_KEY_PREFIX") or "crawl:offline").strip().rstrip(":")


def _url_fingerprint(url: str) -> str:
    return hashlib.sha256(url.strip().encode("utf-8")).hexdigest()


def _snapshot_payload(url: str, text: str) -> Optional[Dict[str, Any]]:
    u = url.strip()
    if not u.startswith("http"):
        return None
    h = hashlib.sha256(text.encode("utf-8")).hexdigest()
    prev = text[:2000].replace("\x00", "")
    try:
        tlen = len(text)
    except Exception:
        return None
    return {
        "url": u,
        "content_sha256": h,
        "text_len": tlen,
        "ts": time.time(),
        "preview": prev,
    }


def record_page_snapshot(url: str, text: str) -> None:
    if not _enabled() or not url or not text:
        return
    url_conn = _redis_url()
    if not url_conn:
        print("[crawl_offline_index] включён индекс, но не задан CRAWL_REDIS_URL или REDIS_URL")
        return
    try:
        import redis  # type: ignore
    except ImportError:
        print("[crawl_offline_index] установите пакет redis")
        return
    payload = _snapshot_payload(url, text)
    if not payload:
        return
    fp = _url_fingerprint(payload["url"])
    key = f"{_redis_key_prefix()}:{fp}"
    raw = json.dumps(payload, ensure_ascii=False)
    try:
        r = redis.from_url(url_conn, decode_responses=True)
        r.set(key, raw)
    except Exception as e:
        print(f"[crawl_offline_index] Redis SET: {e}")


def fetch_preview(url: str) -> Optional[str]:
    """Прочитать сохранённый preview по URL (отладка / warm-start)."""
    if not _enabled():
        return None
    url_conn = _redis_url()
    if not url_conn:
        return None
    try:
        import redis  # type: ignore
    except ImportError:
        return None
    fp = _url_fingerprint(url.strip())
    key = f"{_redis_key_prefix()}:{fp}"
    try:
        r = redis.from_url(url_conn, decode_responses=True)
        raw = r.get(key)
        if not raw:
            return None
        data = json.loads(raw)
        prev = data.get("preview")
        return prev if isinstance(prev, str) else None
    except Exception:
        return None
