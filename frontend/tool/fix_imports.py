#!/usr/bin/env python3
"""One-off: rewrite relative imports to package imports after lib/ restructure."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib"
PKG = "package:research_activity_monitoring_system"

REPLACEMENTS = [
    (r"import '\.\./\.\./\.\./theme/", f"import '{PKG}/core/theme/"),
    (r"import '\.\./screens/", f"import '{PKG}/presentation/screens/"),
    (r"import '\.\./\.\./l10n/", f"import '{PKG}/core/l10n/"),
    (r"import '\.\./\.\./theme/", f"import '{PKG}/core/theme/"),
    (r"import '\.\./\.\./utils/", f"import '{PKG}/core/utils/"),
    (r"import '\.\./config\.dart'", f"import '{PKG}/core/config.dart'"),
    (r"import '\.\./models/", f"import '{PKG}/data/models/"),
    (r"import '\.\./services/", f"import '{PKG}/data/services/"),
    (r"import '\.\./theme/", f"import '{PKG}/core/theme/"),
    (r"import '\.\./utils/", f"import '{PKG}/core/utils/"),
    (r"import '\.\./l10n/", f"import '{PKG}/core/l10n/"),
    (r"import '\.\./widgets/", f"import '{PKG}/presentation/widgets/"),
    (r"import '\.\./features/", f"import '{PKG}/presentation/features/"),
    (r"import '\.\./main\.dart'", f"import '{PKG}/app/app.dart'"),
    (r"import '\.\./\.\./screens/", f"import '{PKG}/presentation/screens/"),
]

def main() -> int:
    for path in sorted(ROOT.rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        orig = text
        for pat, repl in REPLACEMENTS:
            text = re.sub(pat, repl, text)
        if text != orig:
            path.write_text(text, encoding="utf-8")
            print("updated", path.relative_to(ROOT.parent))
    return 0

if __name__ == "__main__":
    sys.exit(main())
