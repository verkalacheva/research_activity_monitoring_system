"""
Эвристики производительности: когда не нужен Playwright, дешёвый pre-filter до LLM.
"""
from __future__ import annotations

import os
import re
from typing import Sequence, Tuple
from urllib.parse import urlparse, urlunparse


def normalize_url_for_dedup(url: str) -> str:
    """Один URL — один проход (без фрагмента, host lower, path без лишнего /)."""
    u = (url or "").strip()
    if not u:
        return ""
    try:
        p = urlparse(u)
        path = (p.path or "").rstrip("/") or "/"
        return urlunparse((p.scheme, (p.netloc or "").lower(), path, "", p.query, ""))
    except Exception:
        return u


def pipeline_mode() -> str:
    """fast — меньше токенов/embeddings; deep — как раньше."""
    v = (os.getenv("CRAWL_PIPELINE_MODE", "fast") or "fast").strip().lower()
    return "deep" if v == "deep" else "fast"


def retrieval_top_k_effective() -> int:
    """Без верхней границы по числу чанков (кроме явного CRAWL_RETRIEVAL_TOP_K); итог режет CRAWL_MAX_RETRIEVAL_PROMPT_CHARS."""
    try:
        raw = (os.getenv("CRAWL_RETRIEVAL_TOP_K", "") or "").strip()
        if raw:
            return max(1, int(raw))
    except ValueError:
        pass
    return 10**9


def embedding_model_effective() -> str:
    """В режиме fast эмбеддинги по умолчанию отключены (BM25 достаточно)."""
    m = (os.getenv("CRAWL_EMBEDDING_MODEL") or "").strip()
    if pipeline_mode() == "fast":
        if (os.getenv("CRAWL_FAST_USE_EMBEDDINGS", "0") or "0").strip().lower() not in (
            "1",
            "true",
            "yes",
            "on",
        ):
            return ""
    return m


def skip_playwright_after_http_enabled() -> bool:
    v = (os.getenv("CRAWL_SKIP_PLAYWRIGHT_IF_HTTP_OK", "1") or "1").strip().lower()
    return v not in ("0", "false", "no", "off")


def cheap_llm_prefilter_enabled() -> bool:
    v = (os.getenv("CRAWL_CHEAP_LLM_PREFILTER", "0") or "0").strip().lower()
    return v in ("1", "true", "yes", "on")


def cheap_relevance_min_score() -> float:
    try:
        return float(os.getenv("CRAWL_CHEAP_RELEVANCE_MIN", "0.06"))
    except ValueError:
        return 0.06


def sentence_boost_filter_enabled() -> bool:
    """Оставить абзацы/фрагменты с датами и «сигналами» достижений (fast)."""
    if pipeline_mode() != "fast":
        return False
    v = (os.getenv("CRAWL_CHUNK_SENTENCE_FILTER", "1") or "1").strip().lower()
    return v not in ("0", "false", "no", "off")


_RE_YEAR = re.compile(r"\b(19|20)\d{2}\b")
_RE_SIGNAL = re.compile(
    r"(публикац|стать|конференц|грант|стипенд|наград|диссертац|патент|РИД|"
    r"стажировк|наставнич|менторств|упомян|упоминан|СМИ|медиа|"
    r"publication|proceedings|journal|grant|award|patent|ORCID|DOI|хакатон|hackathon|"
    r"internship|mentoring|media)",
    re.I,
)


def compress_text_for_llm_signals(text: str, max_chars: int) -> str:
    """Урезать шум: приоритет абзацам с годом или ключевыми словами.

    Алгоритм: сначала помещаем высокосигнальные абзацы (в порядке документа),
    затем добираем оставшейся ёмкостью низкосигнальные (тоже в порядке документа).
    Порядок внутри каждой группы сохраняется — LLM лучше читает связный текст.
    """
    if not sentence_boost_filter_enabled() or not (text or "").strip():
        return text
    paras = [p.strip() for p in re.split(r"\n\s*\n+", text) if p.strip()]
    if len(paras) <= 3:
        return text[:max_chars]
    # Score each paragraph; keep original position index for order restoration
    scored: list[tuple[float, int, str]] = []
    for i, p in enumerate(paras):
        s = 0.0
        if _RE_YEAR.search(p):
            s += 3.0
        if _RE_SIGNAL.search(p):
            s += 2.0
        if len(p) > 120:
            s += 0.5
        scored.append((s, i, p))
    # High-signal paragraphs first (original doc order within group),
    # then fill remaining capacity with low-signal ones (also in doc order).
    high = sorted([(s, i, p) for s, i, p in scored if s > 0], key=lambda x: x[1])
    low = sorted([(s, i, p) for s, i, p in scored if s <= 0], key=lambda x: x[1])
    out: list[str] = []
    n = 0
    for _, _, p in high:
        if n + len(p) + 2 > max_chars:
            remain = max_chars - n - 4
            if remain > 80:
                out.append(p[:remain] + "…")
            break
        out.append(p)
        n += len(p) + 2
    for _, _, p in low:
        if n + len(p) + 2 > max_chars:
            remain = max_chars - n - 4
            if remain > 80:
                out.append(p[:remain] + "…")
            break
        out.append(p)
        n += len(p) + 2
    if not out:
        return text[:max_chars]
    return "\n\n".join(out)[:max_chars]


def html_requires_playwright(html: str, plain_text: str) -> bool:
    """
    True — нужен JS/браузер. False — HTTP-текста достаточно для direct LLM.
    """
    if (os.getenv("CRAWL_FORCE_PLAYWRIGHT", "0") or "0").strip().lower() in (
        "1",
        "true",
        "yes",
        "on",
    ):
        return True
    t = (plain_text or "").strip()
    h = html or ""
    if len(t) < 120:
        return True
    try:
        min_words = int(os.getenv("CRAWL_HTTP_FIRST_MIN_WORDS", "120"))
    except ValueError:
        min_words = 120
    words = len(t.split())
    if words < min_words:
        hs = h.lower()[: min(len(h), 400_000)]
        if "<article" in hs or "<main" in hs:
            if words >= max(40, min_words // 2):
                return False
        return True
    hs = h.lower()[: min(len(h), 400_000)]
    if not any(x in hs for x in ("<article", "<p>", "<main", "<section", "<div")):
        if words < 200:
            return True
    script_n = hs.count("<script")
    if script_n > 30 and len(t) < 2500:
        return True
    if script_n > 12 and words < 180:
        return True
    return False
