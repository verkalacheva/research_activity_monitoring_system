from dataclasses import dataclass, field
from typing import List, Optional, Dict

@dataclass
class Achievement:
    title: str
    type: str
    external_id: str = ""
    url: str = ""
    date: str = ""
    description: str = ""
    author_count: int = 1
    journal_title: str = ""
    extra_fields: Dict[str, str] = field(default_factory=dict)

@dataclass
class DevActivity:
    activity_type: str
    count: int

@dataclass
class CrawlResult:
    achievements: List[Achievement] = field(default_factory=list)
    dev_activities: List[DevActivity] = field(default_factory=list)
    project_criteria_met: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
