#!/usr/bin/env python3
"""Smoke checks for type normalization and title keys (golden-style fixtures)."""
import json
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from infrastructure.type_normalization import fuzzy_match_type, normalize_title_key


def main() -> int:
    data = json.loads((Path(__file__).parent / "golden_sample.json").read_text(encoding="utf-8"))
    allowed = [t["title"] for t in data["achievement_types"]]

    for i, case in enumerate(data["cases"]):
        got = fuzzy_match_type(case["llm_type"], allowed)
        exp = case["expected_type"]
        assert got == exp, f"case[{i}] llm_type={case['llm_type']!r} got {got!r} expected {exp!r}"

    for ex in data.get("title_dedup_examples", []):
        k1 = normalize_title_key(ex["a"])
        k2 = normalize_title_key(ex["b"])
        same = k1 == k2
        assert same == ex["same_key"], (ex, k1, k2)

    print("golden eval OK:", len(data["cases"]), "type cases,", len(data.get("title_dedup_examples", [])), "dedup checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
