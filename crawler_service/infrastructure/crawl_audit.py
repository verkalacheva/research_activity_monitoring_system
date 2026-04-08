"""Optional JSONL audit log for debugging search → crawl → extraction."""
import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional


def append_audit(entry: Dict[str, Any]) -> None:
    path = (os.getenv("CRAWL_AUDIT_LOG") or "").strip()
    if not path:
        return
    line = dict(entry)
    line["ts"] = datetime.now(timezone.utc).isoformat()
    try:
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(line, ensure_ascii=False) + "\n")
    except OSError as e:
        print(f"[crawl_audit] cannot write {path}: {e}")
