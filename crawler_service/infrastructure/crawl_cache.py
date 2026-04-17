"""
Disk cache for crawl text, LLM responses, and embedding vectors (TTL + namespaced keys).
"""
from __future__ import annotations

import hashlib
import json
import os
import threading
import time
from typing import List, Optional, Sequence

_lock = threading.Lock()


def _global_cache_off() -> bool:
    return (os.getenv("CRAWL_CACHE_ENABLED", "1") or "1").strip().lower() in (
        "0",
        "false",
        "no",
        "off",
    )


def _cache_root() -> str:
    raw = (os.getenv("CRAWL_CACHE_DIR") or "").strip()
    if raw:
        root = os.path.expanduser(raw)
    else:
        root = os.path.join(os.path.expanduser("~"), ".cache", "research_activity_crawler")
    os.makedirs(root, exist_ok=True)
    return root


def _ttl_sec() -> float:
    try:
        return max(0.0, float(os.getenv("CRAWL_CACHE_TTL_SEC", "604800")))
    except ValueError:
        return 604800.0


def _page_cache_enabled() -> bool:
    if _global_cache_off():
        return False
    return (os.getenv("CRAWL_PAGE_CACHE_ENABLED", "1") or "1").strip().lower() not in (
        "0",
        "false",
        "no",
        "off",
    )


def _llm_cache_enabled() -> bool:
    if _global_cache_off():
        return False
    return (os.getenv("CRAWL_LLM_CACHE_ENABLED", "0") or "0").strip().lower() in (
        "1",
        "true",
        "yes",
        "on",
    )


def _embedding_cache_enabled() -> bool:
    if _global_cache_off():
        return False
    return (os.getenv("CRAWL_EMBEDDING_CACHE_ENABLED", "1") or "1").strip().lower() not in (
        "0",
        "false",
        "no",
        "off",
    )


def _key_hash(namespace: str, material: str) -> str:
    h = hashlib.sha256(f"{namespace}\0{material}".encode("utf-8")).hexdigest()
    return h


def _path_for(namespace: str, key_hash: str) -> str:
    sub = os.path.join(_cache_root(), namespace, key_hash[:2])
    os.makedirs(sub, exist_ok=True)
    return os.path.join(sub, f"{key_hash}.json")


def _read_json(path: str) -> Optional[dict]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def _write_json(path: str, payload: dict) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
    os.replace(tmp, path)


def cache_get_text(namespace: str, key_material: str) -> Optional[str]:
    if _global_cache_off():
        return None
    if namespace in ("page_text", "pdf_text") and not _page_cache_enabled():
        return None
    if namespace in ("llm_json", "llm_empty") and not _llm_cache_enabled():
        return None
    ttl = _ttl_sec()
    if ttl <= 0:
        return None
    kh = _key_hash(namespace, key_material)
    path = _path_for(namespace, kh)
    with _lock:
        data = _read_json(path)
    if not data or "ts" not in data:
        return None
    if time.time() - float(data["ts"]) > ttl:
        return None
    v = data.get("v")
    return v if isinstance(v, str) else None


def cache_set_text(namespace: str, key_material: str, value: str) -> None:
    if _global_cache_off():
        return
    if namespace in ("page_text", "pdf_text") and not _page_cache_enabled():
        return
    if namespace in ("llm_json", "llm_empty") and not _llm_cache_enabled():
        return
    ttl = _ttl_sec()
    if ttl <= 0:
        return
    kh = _key_hash(namespace, key_material)
    path = _path_for(namespace, kh)
    with _lock:
        _write_json(path, {"ts": time.time(), "v": value})


def cache_get_embedding(model: str, text: str) -> Optional[List[float]]:
    if not _embedding_cache_enabled():
        return None
    ttl = _ttl_sec()
    if ttl <= 0:
        return None
    material = f"{model}\0{text}"
    namespace = "embedding"
    kh = _key_hash(namespace, material)
    path = _path_for(namespace, kh)
    with _lock:
        data = _read_json(path)
    if not data or "ts" not in data:
        return None
    if time.time() - float(data["ts"]) > ttl:
        return None
    v = data.get("v")
    if isinstance(v, list) and v and isinstance(v[0], (int, float)):
        return [float(x) for x in v]
    return None


def cache_set_embedding(model: str, text: str, vector: List[float]) -> None:
    if not _embedding_cache_enabled():
        return
    ttl = _ttl_sec()
    if ttl <= 0:
        return
    material = f"{model}\0{text}"
    namespace = "embedding"
    kh = _key_hash(namespace, material)
    path = _path_for(namespace, kh)
    with _lock:
        _write_json(path, {"ts": time.time(), "v": vector})


def llm_cache_key_material(
    url: str,
    instruction: str,
    text_fingerprint: str,
    retrieval_queries: Optional[Sequence[str]] = None,
    json_contract: str = "",
    completion_model: str = "",
) -> str:
    q = ""
    if retrieval_queries:
        q = hashlib.sha256(
            json.dumps(list(retrieval_queries), ensure_ascii=False).encode("utf-8")
        ).hexdigest()[:32]
    jc = ""
    if (json_contract or "").strip():
        jc = hashlib.sha256(json_contract.encode("utf-8")).hexdigest()[:24]
    m = (completion_model or "").strip()
    return f"{url}\0{instruction}\0{text_fingerprint}\0{q}\0{jc}\0{m}"
