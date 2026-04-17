#!/usr/bin/env python3
"""Replace bare `import 'foo.dart'` with package imports where [foo] is mapped."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib"
PKG = "package:research_activity_monitoring_system"

FILES = {
    "entity_list_screen.dart": "presentation/screens/achievement/entity_list_screen.dart",
    "researcher_list_screen.dart": "presentation/screens/researcher/researcher_list_screen.dart",
    "researcher_form_screen.dart": "presentation/screens/researcher/researcher_form_screen.dart",
    "researcher_profile_screen.dart": "presentation/screens/researcher/researcher_profile_screen.dart",
    "team_list_screen.dart": "presentation/screens/team/team_list_screen.dart",
    "team_form_screen.dart": "presentation/screens/team/team_form_screen.dart",
    "team_details_screen.dart": "presentation/screens/team/team_details_screen.dart",
    "achievement_type_list_screen.dart": "presentation/screens/achievement/achievement_type_list_screen.dart",
    "achievement_type_form_screen.dart": "presentation/screens/achievement/achievement_type_form_screen.dart",
    "achievement_type_details_screen.dart": "presentation/screens/achievement/achievement_type_details_screen.dart",
    "achievement_result_list_screen.dart": "presentation/screens/achievement/achievement_result_list_screen.dart",
    "achievement_result_form_screen.dart": "presentation/screens/achievement/achievement_result_form_screen.dart",
    "achievement_status_list_screen.dart": "presentation/screens/achievement/achievement_status_list_screen.dart",
    "achievement_status_form_screen.dart": "presentation/screens/achievement/achievement_status_form_screen.dart",
    "achievement_participation_list_screen.dart": "presentation/screens/achievement/achievement_participation_list_screen.dart",
    "achievement_participation_form_screen.dart": "presentation/screens/achievement/achievement_participation_form_screen.dart",
    "achievement_form_screen.dart": "presentation/screens/achievement/achievement_form_screen.dart",
    "dev_activity_type_list_screen.dart": "presentation/screens/dev/dev_activity_type_list_screen.dart",
    "dev_activity_type_form_screen.dart": "presentation/screens/dev/dev_activity_type_form_screen.dart",
    "dev_project_criterion_list_screen.dart": "presentation/screens/dev/dev_project_criterion_list_screen.dart",
    "dev_project_criterion_form_screen.dart": "presentation/screens/dev/dev_project_criterion_form_screen.dart",
    "report_screen.dart": "presentation/screens/report/report_screen.dart",
    "settings_screen.dart": "presentation/screens/settings/settings_screen.dart",
    "sync_preview_dialog.dart": "presentation/widgets/sync_preview_dialog.dart",
}

LINE = re.compile(r"^import '([^/']+\.dart)';(\s*show\s+.+)?$")

def main() -> int:
    for path in sorted(ROOT.rglob("*.dart")):
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        out = []
        changed = False
        for line in lines:
            m = LINE.match(line.rstrip("\n"))
            if m and m.group(1) in FILES:
                suffix = m.group(2) or ""
                out.append(f"import '{PKG}/{FILES[m.group(1)]}';{suffix}\n")
                changed = True
            else:
                out.append(line)
        if changed:
            path.write_text("".join(out), encoding="utf-8")
            print("fixed", path.relative_to(ROOT.parent))
    return 0

if __name__ == "__main__":
    sys.exit(main())
