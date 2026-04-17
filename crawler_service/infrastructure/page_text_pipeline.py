"""
Crawler → cleaning → chunking → retrieval (BM25) → structured context for LLM.

Keeps crawling separate from the model: HTML/JS/nav is stripped before any LLM call.
"""
from __future__ import annotations

import math
import os
import re
from collections import Counter
from dataclasses import dataclass
from typing import List, Optional, Sequence, Tuple

from infrastructure.crawl_cache import cache_get_embedding, cache_set_embedding

# Rough tokens: mixed RU/EN; ~4 chars/token is a common heuristic for budgeting.
_CHARS_PER_TOKEN = 4


def _pipeline_enabled() -> bool:
    v = (os.getenv("CRAWL_PIPELINE_ENABLED", "1") or "1").strip().lower()
    return v not in ("0", "false", "no", "off")


def _retrieval_enabled() -> bool:
    v = (os.getenv("CRAWL_RETRIEVAL_ENABLED", "1") or "1").strip().lower()
    return v not in ("0", "false", "no", "off")


def _chunk_token_target() -> int:
    try:
        return max(200, min(1200, int(os.getenv("CRAWL_CHUNK_TOKEN_TARGET", "500"))))
    except ValueError:
        return 500


def _retrieval_top_k() -> int:
    try:
        from infrastructure.crawl_heuristics import retrieval_top_k_effective

        return retrieval_top_k_effective()
    except Exception:
        try:
            return max(1, min(20, int(os.getenv("CRAWL_RETRIEVAL_TOP_K", "5"))))
        except ValueError:
            return 5


def _max_prompt_chars_from_chunks() -> int:
    """Cap total characters assembled from retrieved chunks (input to direct LLM)."""
    try:
        return max(4000, int(os.getenv("CRAWL_MAX_RETRIEVAL_PROMPT_CHARS", "16000")))
    except ValueError:
        return 16000


def _short_page_threshold_chars() -> int:
    """Below this length, skip retrieval and send full cleaned text (minus truncation)."""
    try:
        return max(500, int(os.getenv("CRAWL_SKIP_RETRIEVAL_BELOW_CHARS", "4000")))
    except ValueError:
        return 4000


def _embedding_model_env() -> str:
    try:
        from infrastructure.crawl_heuristics import embedding_model_effective

        return embedding_model_effective()
    except Exception:
        return (os.getenv("CRAWL_EMBEDDING_MODEL") or "").strip()


def _embedding_prefilter_chunks() -> int:
    try:
        return max(8, min(80, int(os.getenv("CRAWL_EMBEDDING_PREFILTER", "28"))))
    except ValueError:
        return 28


@dataclass
class EmbeddingRuntime:
    """OpenAI-compatible embeddings (e.g. OpenRouter)."""

    model: str
    api_key: str
    api_base: str


def normalize_whitespace(text: str) -> str:
    t = (text or "").replace("\r\n", "\n").replace("\r", "\n")
    t = re.sub(r"[ \t]+", " ", t)
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


def dedupe_paragraphs(text: str) -> str:
    """Remove repeated paragraphs (common in mirrored nav / footers)."""
    blocks = re.split(r"\n\s*\n+", text or "")
    seen = set()
    out: List[str] = []
    for b in blocks:
        s = b.strip()
        if not s:
            continue
        key = s.casefold()
        if len(key) < 24:
            out.append(s)
            continue
        if key in seen:
            continue
        seen.add(key)
        out.append(s)
    return "\n\n".join(out)


def extract_main_text_trafilatura(html: str) -> Optional[str]:
    # Skip only trivial fragments (not full documents).
    if not html or len(html) < 40:
        return None
    try:
        import trafilatura  # type: ignore
    except Exception:
        # Broken lxml/justext stacks also fail at import time.
        return None
    try:
        extracted = trafilatura.extract(
            html,
            include_comments=False,
            include_tables=True,
            include_images=False,
            favor_recall=True,
        )
        if not extracted or not str(extracted).strip():
            return None
        return str(extracted).strip()
    except Exception:
        return None


def main_text_from_html_and_fallback(html: Optional[str], markdown_fallback: str) -> str:
    """
    Prefer trafilatura on raw HTML (main article text); else cleaned markdown/plain.
    """
    if not _pipeline_enabled():
        return normalize_whitespace(markdown_fallback or "")

    h = (html or "").strip()
    if h:
        t = extract_main_text_trafilatura(h)
        if t and len(t.strip()) >= 40:
            return dedupe_paragraphs(normalize_whitespace(t))

    fb = normalize_whitespace(markdown_fallback or "")
    return dedupe_paragraphs(fb) if fb else ""


def tokenize(text: str) -> List[str]:
    return re.findall(r"[\w\u0400-\u04FF]{2,}", (text or "").lower())


def _chunk_quality_ok(chunk: str) -> bool:
    if len(chunk.strip()) < 40:
        return False
    letters = sum(1 for c in chunk if c.isalpha() or ("\u0400" <= c <= "\u04ff"))
    return letters / max(len(chunk), 1) >= 0.25


class BM25:
    """Okapi BM25 over tokenized documents."""

    def __init__(self, corpus: List[List[str]]):
        self.corpus = corpus
        self.N = len(corpus)
        self.df: Counter = Counter()
        self.doc_len: List[int] = []
        for doc in corpus:
            self.doc_len.append(len(doc))
            for w in set(doc):
                self.df[w] += 1
        self.avgdl = (sum(self.doc_len) / self.N) if self.N else 0.0
        self.k1 = 1.5
        self.b = 0.75

    def _idf(self, w: str) -> float:
        n = self.df.get(w, 0)
        return math.log((self.N - n + 0.5) / (n + 0.5) + 1.0)

    def score_doc(self, q: List[str], doc_idx: int) -> float:
        doc = self.corpus[doc_idx]
        if not doc:
            return 0.0
        tf = Counter(doc)
        dl = self.doc_len[doc_idx]
        avgdl = self.avgdl or 1.0
        s = 0.0
        for w in q:
            if w not in tf:
                continue
            idf = self._idf(w)
            num = tf[w] * (self.k1 + 1)
            den = tf[w] + self.k1 * (1 - self.b + self.b * (dl / avgdl))
            s += idf * (num / den)
        return s


def chunk_by_paragraphs(text: str, max_tokens: int) -> List[str]:
    max_chars = max(400, max_tokens * _CHARS_PER_TOKEN)
    parts = re.split(r"\n\s*\n+", text or "")
    chunks: List[str] = []
    buf: List[str] = []
    buf_len = 0

    def flush():
        nonlocal buf, buf_len
        if buf:
            chunks.append("\n\n".join(buf))
            buf = []
            buf_len = 0

    for p in parts:
        p = p.strip()
        if not p:
            continue
        if len(p) > max_chars:
            flush()
            for i in range(0, len(p), max_chars):
                chunks.append(p[i : i + max_chars])
            continue
        if buf_len + len(p) + 2 <= max_chars:
            buf.append(p)
            buf_len += len(p) + 2
        else:
            flush()
            buf = [p]
            buf_len = len(p)
    flush()
    out = [c for c in chunks if _chunk_quality_ok(c)]
    return out if out else ([text.strip()] if text.strip() else [])


def cheap_relevance_pass(text: str, queries: Optional[Sequence[str]]) -> bool:
    """Дешёвый pre-filter: BM25 по чанкам; при низком score — не звать LLM."""
    try:
        from infrastructure.crawl_heuristics import (
            cheap_llm_prefilter_enabled,
            cheap_relevance_min_score,
        )
    except Exception:
        return True
    if not cheap_llm_prefilter_enabled():
        return True
    t = (text or "").strip()
    if len(t) < 200:
        return False
    qs = [q for q in (queries or []) if (q or "").strip()]
    if not qs:
        return True
    chunks = chunk_by_paragraphs(t, _chunk_token_target())
    if not chunks:
        chunks = [t[:12000]]
    ranked = rank_chunks_bm25(chunks, qs)
    if not ranked:
        return True
    best = max(sc for _, sc in ranked)
    thr = cheap_relevance_min_score()
    if best <= 0:
        return True
    return best >= thr


def rank_chunks_bm25(
    chunks: List[str],
    queries: Sequence[str],
) -> List[Tuple[int, float]]:
    if not chunks or not queries:
        return [(i, 0.0) for i in range(len(chunks))]
    tokenized = [tokenize(c) for c in chunks]
    bm = BM25(tokenized)
    scores = [0.0] * len(chunks)
    for q in queries:
        qt = tokenize(q)
        if not qt:
            continue
        for i in range(len(chunks)):
            scores[i] = max(scores[i], bm.score_doc(qt, i))
    ranked = sorted(enumerate(scores), key=lambda x: x[1], reverse=True)
    return ranked


def rerank_top_by_length(chunks: List[str], indices: List[int]) -> List[int]:
    """Light rerank: prefer slightly longer chunks among top scores (more evidence)."""
    out = []
    for i in indices:
        out.append((i, len(chunks[i])))
    out.sort(key=lambda x: x[1], reverse=True)
    return [i for i, _ in out]


def build_structured_context(chunk_texts: List[str]) -> str:
    parts = []
    for i, block in enumerate(chunk_texts, 1):
        parts.append(f"[Источник {i}]\n{block.strip()}")
    return "\n\n".join(parts)


def _finalize_llm_body(body: str) -> str:
    """В режиме fast — сжать контекст по сигналам (годы, ключевые слова)."""
    if not (body or "").strip():
        return body
    try:
        from infrastructure.crawl_heuristics import compress_text_for_llm_signals

        return compress_text_for_llm_signals(body, _max_prompt_chars_from_chunks())
    except Exception:
        return body


def clean_flat_text(text: str) -> str:
    """Normalize + dedupe paragraphs for PDF/plain text (no HTML)."""
    if not _pipeline_enabled():
        return normalize_whitespace(text or "")
    return dedupe_paragraphs(normalize_whitespace(text or ""))


def prepare_text_for_llm(
    cleaned_page_text: str,
    retrieval_queries: Optional[Sequence[str]],
) -> Tuple[str, dict]:
    """
    Returns (body_for_prompt, stats).

    If page is short or retrieval disabled, returns truncated full text with stats.
    """
    stats: dict = {"mode": "full", "chunks_total": 0, "chunks_used": 0}
    text = cleaned_page_text or ""
    if not text.strip():
        return "", stats

    if not _pipeline_enabled():
        return _finalize_llm_body(text), stats

    max_prompt = _max_prompt_chars_from_chunks()
    if not _retrieval_enabled() or not retrieval_queries:
        stats["mode"] = "full_no_retrieval"
        if len(text) <= max_prompt:
            return _finalize_llm_body(text), stats
        return _finalize_llm_body(
            text[:max_prompt] + "\n\n[... текст обрезан по лимиту ...]"
        ), stats

    if len(text) <= _short_page_threshold_chars():
        stats["mode"] = "full_short_page"
        stats["chunks_total"] = 1
        stats["chunks_used"] = 1
        if len(text) <= max_prompt:
            return _finalize_llm_body(build_structured_context([text])), stats
        return _finalize_llm_body(build_structured_context([text[:max_prompt]])), stats

    chunks = chunk_by_paragraphs(text, _chunk_token_target())
    stats["chunks_total"] = len(chunks)
    if not chunks:
        return _finalize_llm_body(text[:max_prompt]), stats

    queries = [q for q in retrieval_queries if (q or "").strip()]
    if not queries:
        queries = [text[:500]]

    ranked = rank_chunks_bm25(chunks, queries)
    top_k = _retrieval_top_k()
    positive = [idx for idx, sc in ranked if sc > 0][: max(top_k * 3, top_k)]
    if positive:
        cand_idx = positive[: max(top_k * 2, top_k)]
    else:
        cand_idx = [idx for idx, _ in ranked[:top_k]]
    top_idx = rerank_top_by_length(chunks, cand_idx)[:top_k]

    selected = [chunks[i] for i in top_idx if 0 <= i < len(chunks)]
    stats["chunks_used"] = len(selected)
    stats["mode"] = "retrieval_bm25"

    body_parts: List[str] = []
    total = 0
    for block in selected:
        if total + len(block) + 40 > max_prompt:
            remain = max_prompt - total - 80
            if remain > 200:
                body_parts.append(block[:remain] + "\n[...]")
            break
        body_parts.append(block)
        total += len(block) + 40

    if not body_parts:
        body_parts = [selected[0][: max_prompt - 100]] if selected else [text[:max_prompt]]

    return _finalize_llm_body(build_structured_context(body_parts)), stats


def _cosine_sim(a: List[float], b: List[float]) -> float:
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na <= 0 or nb <= 0:
        return 0.0
    return dot / (na * nb)


def _average_vectors(vectors: List[List[float]]) -> List[float]:
    if not vectors:
        return []
    dim = len(vectors[0])
    out = [0.0] * dim
    for v in vectors:
        if len(v) != dim:
            continue
        for i, x in enumerate(v):
            out[i] += x
    n = float(len(vectors))
    return [x / n for x in out]


async def _embed_strings_litellm(
    texts: List[str],
    runtime: EmbeddingRuntime,
) -> List[List[float]]:
    import litellm

    if not texts:
        return []
    out: List[Optional[List[float]]] = [None] * len(texts)
    missing: List[Tuple[int, str]] = []
    for i, t in enumerate(texts):
        cached = cache_get_embedding(runtime.model, t)
        if cached is not None:
            out[i] = cached
        else:
            missing.append((i, t))
    batch_sz = max(1, min(32, int(os.getenv("CRAWL_EMBEDDING_BATCH", "16"))))
    for start in range(0, len(missing), batch_sz):
        batch = missing[start : start + batch_sz]
        inputs = [t for _, t in batch]
        try:
            resp = await litellm.aembedding(
                model=runtime.model,
                input=inputs,
                api_key=runtime.api_key,
                api_base=runtime.api_base,
                encoding_format="float",
            )
        except TypeError:
            resp = await litellm.aembedding(
                model=runtime.model,
                input=inputs,
                api_key=runtime.api_key,
                api_base=runtime.api_base,
            )
        data = getattr(resp, "data", None) or []
        if len(data) != len(inputs):
            raise RuntimeError("embedding batch size mismatch")
        for (idx, _), row in zip(batch, data):
            emb = getattr(row, "embedding", None)
            if emb is None and isinstance(row, dict):
                emb = row.get("embedding")
            if not isinstance(emb, list):
                raise RuntimeError("invalid embedding row")
            vec = [float(x) for x in emb]
            out[idx] = vec
            cache_set_embedding(runtime.model, texts[idx], vec)
    resolved: List[List[float]] = []
    for v in out:
        if v is None:
            raise RuntimeError("missing embedding")
        resolved.append(v)
    return resolved


async def prepare_text_for_llm_async(
    cleaned_page_text: str,
    retrieval_queries: Optional[Sequence[str]],
    *,
    embedding_model: Optional[str] = None,
    embedding_api_key: str = "",
    embedding_api_base: str = "",
) -> Tuple[str, dict]:
    """
    Same as prepare_text_for_llm, but when CRAWL_EMBEDDING_MODEL is set (or embedding_model arg),
    uses hybrid BM25 prefilter + embedding cosine rerank.
    """
    model = (embedding_model or _embedding_model_env()).strip()
    if not model:
        return prepare_text_for_llm(cleaned_page_text, retrieval_queries)

    stats: dict = {"mode": "full", "chunks_total": 0, "chunks_used": 0}
    text = cleaned_page_text or ""
    if not text.strip():
        return "", stats

    if not _pipeline_enabled():
        return _finalize_llm_body(text), stats

    max_prompt = _max_prompt_chars_from_chunks()
    if not _retrieval_enabled() or not retrieval_queries:
        stats["mode"] = "full_no_retrieval"
        if len(text) <= max_prompt:
            return _finalize_llm_body(text), stats
        return _finalize_llm_body(
            text[:max_prompt] + "\n\n[... текст обрезан по лимиту ...]"
        ), stats

    if len(text) <= _short_page_threshold_chars():
        stats["mode"] = "full_short_page"
        stats["chunks_total"] = 1
        stats["chunks_used"] = 1
        if len(text) <= max_prompt:
            return _finalize_llm_body(build_structured_context([text])), stats
        return _finalize_llm_body(build_structured_context([text[:max_prompt]])), stats

    chunks = chunk_by_paragraphs(text, _chunk_token_target())
    stats["chunks_total"] = len(chunks)
    if not chunks:
        return _finalize_llm_body(text[:max_prompt]), stats

    queries = [q for q in retrieval_queries if (q or "").strip()]
    if not queries:
        queries = [text[:500]]

    runtime = EmbeddingRuntime(
        model=model,
        api_key=embedding_api_key or "",
        api_base=(embedding_api_base or "").strip()
        or os.getenv("LLM_API_BASE", "").strip()
        or os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
    )
    if not runtime.api_key:
        return prepare_text_for_llm(cleaned_page_text, retrieval_queries)

    try:
        ranked = rank_chunks_bm25(chunks, queries)
        pre_n = _embedding_prefilter_chunks()
        cand_idx = [idx for idx, _ in ranked[:pre_n]]
        if not cand_idx:
            cand_idx = list(range(min(len(chunks), pre_n)))

        q_texts = queries[:8]
        q_vecs = await _embed_strings_litellm(q_texts, runtime)
        query_vec = _average_vectors(q_vecs)

        subset = [chunks[i] for i in cand_idx]
        c_vecs = await _embed_strings_litellm(subset, runtime)

        scored: List[Tuple[int, float]] = []
        for j, i in enumerate(cand_idx):
            s = _cosine_sim(query_vec, c_vecs[j])
            scored.append((i, s))
        scored.sort(key=lambda x: x[1], reverse=True)

        top_k = _retrieval_top_k()
        top_idx = [i for i, _ in scored[:top_k]]
        top_idx = rerank_top_by_length(chunks, top_idx)[:top_k]

        selected = [chunks[i] for i in top_idx if 0 <= i < len(chunks)]
        stats["chunks_used"] = len(selected)
        stats["mode"] = "retrieval_hybrid_bm25_embed"

        body_parts: List[str] = []
        total = 0
        for block in selected:
            if total + len(block) + 40 > max_prompt:
                remain = max_prompt - total - 80
                if remain > 200:
                    body_parts.append(block[:remain] + "\n[...]")
                break
            body_parts.append(block)
            total += len(block) + 40

        if not body_parts:
            body_parts = [selected[0][: max_prompt - 100]] if selected else [text[:max_prompt]]

        return _finalize_llm_body(build_structured_context(body_parts)), stats
    except Exception as e:
        print(f"[page_text_pipeline] embedding retrieval failed → BM25 only: {e}")
        return prepare_text_for_llm(cleaned_page_text, retrieval_queries)


def build_retrieval_queries(
    researcher_name: str,
    profile: Optional[dict],
    achievement_type_titles: Optional[Sequence[str]],
) -> List[str]:
    """Multi-query strings for BM25 over chunks (recall without huge prompts)."""
    from infrastructure.search_queries import build_auto_search_queries

    name = (researcher_name or "").strip()
    out: List[str] = []
    if name:
        out.append(name)
        out.append(f"{name} публикации ORCID")
        out.append(f"{name} грант статья конференция")
    extra = build_auto_search_queries(
        name,
        profile,
        list(achievement_type_titles or []),
    )
    for q in extra[:12]:
        if q not in out:
            out.append(q)
    seen = set()
    final: List[str] = []
    for q in out:
        q = " ".join((q or "").split())
        if len(q) < 4 or q in seen:
            continue
        seen.add(q)
        final.append(q)
    return final[:15]
