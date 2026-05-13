"""
Замена PROMPT_EXTRACT_SCHEMA_WITH_INSTRUCTION из crawl4ai.

Библиотека подставляет строку в модуль extraction_strategy при импорте — патчим и prompts,
и extraction_strategy, иначе остаётся старый текст про «список объектов по блокам страницы».
"""

from __future__ import annotations

# Плейсхолдеры как у crawl4ai: {URL}, {HTML}, {REQUEST}, {SCHEMA}
PROMPT_EXTRACT_SCHEMA_WITH_INSTRUCTION_PATCHED = """Here is the content from the URL:
<url>{URL}</url>

<url_content>
{HTML}
</url_content>

The user has made the following request for what information to extract from the above content:

<user_request>
{REQUEST}
</user_request>

<schema_block>
{SCHEMA}
</schema_block>

PAGE NOISE — IGNORE (do not use as evidence for achievements):
Site chrome only: navigation, footers, login and paywall prompts, cookie/consent banners,
share/cite widgets, Kindle/Dropbox/Google Drive modals, duplicate mobile headings,
«Cited by» / Crossref / Google Scholar widgets, «Loading…» placeholders, and diagnostic lines
(e.g. Hostname:, Render date:, Total loading time:, hasContentIssue).

AUTHOR / NAME MATCHING (in addition to rules inside <user_request>):
If the page shows the researcher under a Latin/international spelling (e.g. English author line)
that clearly corresponds to the person named in <user_request> (same surname + given names),
treat that as satisfying any «name must appear on the page» requirement — Cyrillic on the page is NOT required.

SOURCES — DO NOT OVER-EXTRACT:
Do NOT emit separate achievements from bibliography / «References» sections or third-party
«Cited by» lists unless <user_request> explicitly asks for those AND ties the named researcher
to each item on this page. For a publisher article landing page, prefer ONE primary work that
this URL describes when it matches the researcher — not every cited reference.

Please carefully read the URL content, <user_request>, and <schema_block>.
Extract according to the schema. Output must conform to <schema_block> shape exactly.

OUTPUT FORMAT (critical):
- Inside <blocks>...</blocks> output exactly ONE JSON value matching <schema_block>.
  Typically this is a single object: {"achievements": [...]}.
- No markdown code fences. No // or # comments inside JSON.
- Do NOT return a bare JSON array at the top level unless <schema_block> explicitly requires an array.
- Do NOT prepend or append prose inside <blocks>; only the JSON object.

SELF-CHECK (silent): verify JSON is parseable by json.loads(); omit Quality Score and omit extra commentary outside <blocks>.

Avoid common mistakes:
- Do NOT add comments using "//" or "#" in the JSON output.
- Balance braces, brackets, and commas correctly.
- Close </blocks> properly.

Result:
Put the final JSON object inside <blocks>...</blocks> only."""

_JSON_PATCHED = False
_JSON_ORIGINAL_DUMPS = None


def _patch_json_dumps_schema_unicode() -> None:
    """crawl4ai делает json.dumps(schema, indent=2) без ensure_ascii=False → кириллица как \\uXXXX."""
    global _JSON_PATCHED, _JSON_ORIGINAL_DUMPS
    if _JSON_PATCHED:
        return
    import json as _json_mod  # noqa: PLC0415

    _JSON_ORIGINAL_DUMPS = _json_mod.dumps

    def dumps_preserve_unicode(*args, **kwargs):
        if kwargs.get("indent") == 2 and "ensure_ascii" not in kwargs:
            kwargs = {**kwargs, "ensure_ascii": False}
        return _JSON_ORIGINAL_DUMPS(*args, **kwargs)

    _json_mod.dumps = dumps_preserve_unicode  # noqa: PLW0603 — намеренно для всего процесса
    _JSON_PATCHED = True


_PATCHED = False


def apply_crawl4ai_schema_prompt_patch() -> None:
    """Идемпотентно подменяет промпт до любых вызовов LLMExtractionStrategy."""
    global _PATCHED
    if _PATCHED:
        return
    import crawl4ai.extraction_strategy as es  # noqa: PLC0415
    import crawl4ai.prompts as pr  # noqa: PLC0415

    _patch_json_dumps_schema_unicode()

    pr.PROMPT_EXTRACT_SCHEMA_WITH_INSTRUCTION = PROMPT_EXTRACT_SCHEMA_WITH_INSTRUCTION_PATCHED
    es.PROMPT_EXTRACT_SCHEMA_WITH_INSTRUCTION = PROMPT_EXTRACT_SCHEMA_WITH_INSTRUCTION_PATCHED
    _PATCHED = True
