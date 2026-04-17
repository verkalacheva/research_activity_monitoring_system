import io
import os
import re
import json
import time
import random
import hashlib
import typing
import asyncio
import litellm
import httpx
from contextlib import asynccontextmanager
from collections import deque
from typing import List, Dict, Any, Optional, Tuple
from urllib.parse import urlparse
from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode
from crawl4ai.extraction_strategy import LLMExtractionStrategy
from translations.ru import LLM_MODEL_UNAVAILABLE_USER_RU
from infrastructure.url_ranking import is_pdf_url, is_forced_download_url
from infrastructure.crawl_cache import cache_get_text, cache_set_text, llm_cache_key_material
from infrastructure.crawl_offline_index import record_page_snapshot
from infrastructure.page_text_pipeline import (
    cheap_relevance_pass,
    clean_flat_text,
    main_text_from_html_and_fallback,
    prepare_text_for_llm_async,
)
from infrastructure.crawl_heuristics import (
    html_requires_playwright,
    skip_playwright_after_http_enabled,
)

try:
    litellm.num_retries = max(0, min(5, int(os.getenv("LITELLM_NUM_RETRIES", "0"))))
except ValueError:
    litellm.num_retries = 0
# Без повторов по 429 на free tier — litellm не должен раздувать burst
litellm.retry_on = ["ServiceUnavailableError", "Timeout"]
litellm.suppress_debug_info = True

def _litellm_failure_handler(kwargs, completion_response, start_time, end_time):
    print(f"[LiteLLM FAILURE] model={kwargs.get('model')} | exception={kwargs.get('exception')} | response={completion_response}")

litellm.failure_callback = [_litellm_failure_handler]


class KeyPool:
    """Циклический пул API-ключей с ротацией при исчерпании лимита."""

    def __init__(self, keys: List[str]):
        self._keys = keys
        self._index = 0
        self._rotations = 0

    @classmethod
    def from_env(cls, *env_vars: str) -> "KeyPool":
        keys = []
        for var in env_vars:
            val = os.getenv(var, "")
            keys.extend(k.strip() for k in val.split(",") if k.strip())
        return cls(keys or ["no-key"])

    @classmethod
    def from_value(cls, value: str) -> "KeyPool":
        keys = [k.strip() for k in value.split(",") if k.strip()]
        return cls(keys or ["no-key"])

    def current(self) -> str:
        return self._keys[self._index]

    def rotate(self) -> bool:
        self._rotations += 1
        if self._rotations >= len(self._keys):
            print("[KeyPool] All keys exhausted, no more rotation.")
            return False
        self._index = (self._index + 1) % len(self._keys)
        print(f"[KeyPool] Rotated to key index {self._index}")
        return True

    def reset_rotations(self):
        self._rotations = 0

    def __len__(self):
        return len(self._keys)


# Module-level ENV-based key pool for OpenRouter
_openrouter_env_pool: Optional[KeyPool] = None

def _get_openrouter_env_pool() -> KeyPool:
    global _openrouter_env_pool
    if _openrouter_env_pool is None:
        _openrouter_env_pool = KeyPool.from_env("OPENROUTER_API_KEYS", "OPENROUTER_API_KEY")
    return _openrouter_env_pool


class RateLimiter:
    """Async sliding-window rate limiter shared across all CrawlerClient instances.

    The Lock is created lazily on first use so that it is always bound to the
    event loop that is actually running (avoids issues when the module is imported
    before asyncio.run() / the gRPC server starts its loop).
    """

    def __init__(self, max_calls: int, period: float = 60.0):
        self._max_calls = max_calls
        self._period = period
        self._timestamps: deque = deque()
        self._lock: Optional[asyncio.Lock] = None

    async def acquire(self):
        if self._lock is None:
            self._lock = asyncio.Lock()
        async with self._lock:
            now = time.monotonic()
            # Evict timestamps that have left the window
            while self._timestamps and now - self._timestamps[0] >= self._period:
                self._timestamps.popleft()

            if len(self._timestamps) >= self._max_calls:
                wait = self._period - (now - self._timestamps[0])
                if wait > 0:
                    print(
                        f"[RateLimiter] window full ({len(self._timestamps)}/{self._max_calls}) "
                        f"— sleeping {wait:.1f}s"
                    )
                    await asyncio.sleep(wait)
                    now = time.monotonic()
                    while self._timestamps and now - self._timestamps[0] >= self._period:
                        self._timestamps.popleft()

            self._timestamps.append(time.monotonic())
            print(
                f"[RateLimiter] slot acquired — "
                f"{len(self._timestamps)}/{self._max_calls} req in last {self._period:.0f}s window"
            )


# One shared limiter for all CrawlerClient instances; configurable via LLM_RPM env var.
_llm_rate_limiter = RateLimiter(
    # Default below OpenRouter's 8 RPM free cap so chunk retries + litellm don't exhaust the window.
    max_calls=int(os.getenv("LLM_RPM", "4")),
    period=60.0,
)

# Ограничивает одновременные LLM-вызовы (HTTP/краул может быть параллельнее через CRAWL_CONCURRENCY).
_llm_concurrency_sem: Optional[asyncio.Semaphore] = None
# Минимальный интервал между завершением одного LLM и стартом следующего (burst у free-провайдеров).
_llm_last_completed_at: float = 0.0
_llm_circuit_open_until: float = 0.0
_llm_429_streak: int = 0


def _llm_circuit_is_open() -> bool:
    return time.monotonic() < _llm_circuit_open_until


def _llm_record_success() -> None:
    global _llm_429_streak
    _llm_429_streak = 0


def _llm_record_429_after_chain() -> None:
    """После исчерпания цепочки моделей с 429 — счётчик к circuit breaker."""
    global _llm_circuit_open_until, _llm_429_streak
    _llm_429_streak += 1
    try:
        thr = max(1, int(os.getenv("CRAWL_LLM_429_CIRCUIT_THRESHOLD", "3")))
    except ValueError:
        thr = 3
    try:
        cd = float(os.getenv("CRAWL_LLM_CIRCUIT_COOLDOWN_SEC", "120"))
    except ValueError:
        cd = 120.0
    if _llm_429_streak >= thr:
        _llm_circuit_open_until = time.monotonic() + cd
        _llm_429_streak = 0
        print(
            f"[CrawlerClient] LLM circuit: cooldown {cd:.0f}s after {thr} consecutive 429s"
        )


def _get_llm_concurrency_sem() -> asyncio.Semaphore:
    global _llm_concurrency_sem
    if _llm_concurrency_sem is None:
        try:
            n = int(os.getenv("LLM_CONCURRENCY", "1"))
        except ValueError:
            n = 1
        n = max(1, min(16, n))
        _llm_concurrency_sem = asyncio.Semaphore(n)
    return _llm_concurrency_sem


@asynccontextmanager
async def _llm_request_slot():
    """Семафор LLM → min spacing → jitter → sliding-window RPM (снимает burst)."""
    global _llm_last_completed_at
    sem = _get_llm_concurrency_sem()
    await sem.acquire()
    try:
        try:
            spacing = float(os.getenv("CRAWL_LLM_MIN_SPACING_SEC", "2.0"))
        except ValueError:
            spacing = 2.0
        if spacing > 0 and _llm_last_completed_at > 0:
            gap = time.monotonic() - _llm_last_completed_at
            if gap < spacing:
                await asyncio.sleep(spacing - gap)
        try:
            jmin = float(os.getenv("CRAWL_LLM_PRE_JITTER_MIN_SEC", "0.5"))
            jmax = float(os.getenv("CRAWL_LLM_PRE_JITTER_MAX_SEC", "2.0"))
        except ValueError:
            jmin, jmax = 0.5, 2.0
        jmax = max(jmin, jmax)
        if jmax > 0:
            await asyncio.sleep(random.uniform(min(jmin, jmax), jmax))
        await _llm_rate_limiter.acquire()
        yield
    finally:
        _llm_last_completed_at = time.monotonic()
        sem.release()


# Shared httpx client for HTTP-first HTML fetch (keep-alive / HTTP2 if negotiated).
_httpx_crawl_client: Optional[httpx.AsyncClient] = None

# Initial and max backoff for upstream rate limits (e.g. Venice behind OpenRouter free tier).
# Venice's window is longer than a few seconds — start at 60s, cap at 5 min.
_RATE_LIMIT_INITIAL_DELAY = float(os.getenv("RATE_LIMIT_INITIAL_DELAY", "60"))
_RATE_LIMIT_MAX_DELAY     = float(os.getenv("RATE_LIMIT_MAX_DELAY",     "300"))

# Prefer single-chunk extraction by default — crawl4ai multi-chunk merge can raise '.usage on list'.
_DEFAULT_CHUNK_TOKEN_THRESHOLD = int(os.getenv("CRAWL_CHUNK_TOKEN_THRESHOLD", "200000"))
_CHUNK_TOKEN_THRESHOLD_SINGLE_PASS = int(os.getenv("CRAWL_CHUNK_TOKEN_THRESHOLD_SINGLE_PASS", "200000"))
_CHUNK_TOKEN_THRESHOLD_LAST_RESORT = max(
    _CHUNK_TOKEN_THRESHOLD_SINGLE_PASS + 1,
    int(os.getenv("CRAWL_CHUNK_TOKEN_THRESHOLD_LAST_RESORT", "2000000")),
)
# After LAST_RESORT, crawl4ai can still split; one more tier (HTML pages stay well below this).
_CHUNK_TOKEN_THRESHOLD_MEGA = max(
    _CHUNK_TOKEN_THRESHOLD_LAST_RESORT + 1,
    int(os.getenv("CRAWL_CHUNK_TOKEN_THRESHOLD_MEGA", "50000000")),
)


def _next_chunk_threshold_for_merge_bug(current: int) -> Optional[int]:
    """Escalate chunk_token_threshold until single-document extraction; None = no further step."""
    if current < _CHUNK_TOKEN_THRESHOLD_SINGLE_PASS:
        return _CHUNK_TOKEN_THRESHOLD_SINGLE_PASS
    if current < _CHUNK_TOKEN_THRESHOLD_LAST_RESORT:
        return _CHUNK_TOKEN_THRESHOLD_LAST_RESORT
    if current < _CHUNK_TOKEN_THRESHOLD_MEGA:
        return _CHUNK_TOKEN_THRESHOLD_MEGA
    return None


def _direct_llm_max_chars() -> int:
    try:
        return max(8000, int(os.getenv("CRAWL_DIRECT_LLM_MAX_CHARS", "120000")))
    except ValueError:
        return 120000


def _truncate_page_text(text: str, max_chars: int) -> str:
    """Сохраняем начало и конец страницы (списки публикаций часто внизу)."""
    t = (text or "").strip()
    if len(t) <= max_chars:
        return t
    head = int(max_chars * 0.42)
    tail = int(max_chars * 0.42)
    mid = max_chars - head - tail - 80
    if mid < 0:
        return t[: max_chars // 2] + "\n\n[... truncated ...]\n\n" + t[-max_chars // 2 :]
    return (
        t[:head]
        + "\n\n[... omitted middle of page ...]\n\n"
        + t[-tail:]
    )


def _two_step_extract_enabled() -> bool:
    return (os.getenv("CRAWL_TWO_STEP_EXTRACT", "0") or "0").strip().lower() in (
        "1",
        "true",
        "yes",
        "on",
    )


def _pdf_max_pages() -> int:
    try:
        return max(1, int(os.getenv("CRAWL_PDF_MAX_PAGES", "40")))
    except ValueError:
        return 40


def _strip_llm_json_fences(raw: str) -> str:
    s = (raw or "").strip()
    if s.startswith("```"):
        lines = s.split("\n")
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        s = "\n".join(lines)
    return s.strip()


def _direct_llm_extract_enabled() -> bool:
    v = (os.getenv("CRAWL_DIRECT_LLM_EXTRACT", "1") or "1").strip().lower()
    return v not in ("0", "false", "no", "off")


def _http_first_enabled() -> bool:
    """Быстрый GET через httpx до Playwright; при пустом/SPA — fallback на crawl4ai."""
    v = (os.getenv("CRAWL_HTTP_FIRST", "1") or "1").strip().lower()
    return v not in ("0", "false", "no", "off")


def _looks_like_html(content: str) -> bool:
    s = (content or "")[:12000].lower()
    if len(s) < 80:
        return False
    return (
        "<html" in s or "<body" in s or "<article" in s or "<main" in s or "<div" in s
    ) and ("<" in s and ">" in s)


def _get_crawl_httpx_client() -> httpx.AsyncClient:
    global _httpx_crawl_client
    if _httpx_crawl_client is None:
        try:
            read_sec = float(os.getenv("CRAWL_HTTP_FIRST_TIMEOUT_SEC", "28"))
        except ValueError:
            read_sec = 28.0
        timeout = httpx.Timeout(connect=12.0, read=read_sec, write=12.0, pool=8.0)
        limits = httpx.Limits(max_keepalive_connections=32, max_connections=64)
        _httpx_crawl_client = httpx.AsyncClient(
            timeout=timeout,
            limits=limits,
            follow_redirects=True,
            headers={
                "User-Agent": (
                    "ResearchActivityMonitor/1.0 "
                    "(compatible; research crawler; +https://github.com/)"
                ),
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "ru,en;q=0.9",
                "Accept-Encoding": "gzip, deflate, br",
            },
        )
    return _httpx_crawl_client


def _apply_rate_limit_jitter(base: float) -> float:
    """Случайная добавка к паузе при 429 — снижает thundering herd."""
    try:
        jmax = float(os.getenv("CRAWL_RATE_LIMIT_JITTER_SEC", "4"))
    except ValueError:
        jmax = 4.0
    if jmax <= 0:
        return base
    return base + random.uniform(0, jmax)


def _rate_limit_sleep_seconds_core(message: str) -> float:
    """Базовая пауза без jitter (см. _rate_limit_sleep_seconds)."""
    m = re.search(r'"X-RateLimit-Reset"\s*:\s*"(\d+)"', message or "")
    if m:
        reset_ms = int(m.group(1))
        wait = reset_ms / 1000.0 - time.time()
        return max(8.0, min(120.0, wait))
    if "429" in (message or "") or "rate limit" in (message or "").lower():
        return 45.0
    return 10.0


def _rate_limit_sleep_seconds(message: str) -> float:
    """Sleep until OpenRouter window reset when X-RateLimit-Reset is present (ms epoch)."""
    return _apply_rate_limit_jitter(_rate_limit_sleep_seconds_core(message))


def _direct_llm_backoff_seconds(message: str) -> float:
    """Пауза перед повтором direct LLM: Venice/upstream 429 — дольше, чем фиксированные 2 с."""
    msg = message or ""
    base = _rate_limit_sleep_seconds_core(msg)
    if re.search(r'"X-RateLimit-Reset"\s*:\s*"(\d+)"', msg):
        return _apply_rate_limit_jitter(base)
    low = msg.lower()
    if "429" in msg or "ratelimit" in low.replace(" ", "") or "temporarily rate-limited" in low:
        try:
            extra = float(os.getenv("CRAWL_UPSTREAM_429_SLEEP_SEC", "75"))
        except ValueError:
            extra = 75.0
        out = max(base, max(30.0, extra))
        return _apply_rate_limit_jitter(out)
    return _apply_rate_limit_jitter(base)


def _crawl_page_timeout_ms() -> int:
    """Таймаут goto Playwright; на тяжёлых сайтах (закупки, SPA) networkidle часто не наступает."""
    try:
        return max(15000, int(os.getenv("CRAWL_PAGE_TIMEOUT_MS", "75000")))
    except ValueError:
        return 75000


def _crawl_wait_until() -> str:
    """load / domcontentloaded — надёжнее, чем networkidle (вечные запросы аналитики)."""
    v = (os.getenv("CRAWL_WAIT_UNTIL", "load") or "load").strip().lower()
    if v not in ("load", "domcontentloaded", "commit", "networkidle"):
        return "load"
    return v


def _is_chunk_merge_usage_bug(raw: str) -> bool:
    """crawl4ai bug when merging multi-chunk LLM responses — not HTTP 429."""
    return bool(raw and "'list' object has no attribute 'usage'" in raw)


def _is_openrouter_model_gone(raw: str) -> bool:
    """True when LiteLLM/OpenRouter rejected the model (deprecated free tier, 404, etc.)."""
    if not raw:
        return False
    r = raw.lower()
    if "openrouter" not in r and "notfounderror" not in r:
        return False
    return (
        "deprecated" in r
        or "404" in r
        or '"code":404' in r
        or "free model" in r
        or "invalid model" in r
        or "model not found" in r
    )

def _next_rate_limit_delay(current: float) -> float:
    return max(_RATE_LIMIT_INITIAL_DELAY, min(_RATE_LIMIT_MAX_DELAY, (current or _RATE_LIMIT_INITIAL_DELAY) * 2))


# Handle LLMConfig import variations
try:
    from crawl4ai.config import LLMConfig
except ImportError:
    try:
        from crawl4ai.models import LLMConfig
    except ImportError:
        try:
            from crawl4ai import LLMConfig
        except ImportError:
            LLMConfig = None

if LLMConfig is None or isinstance(LLMConfig, typing.ForwardRef):
    from dataclasses import dataclass
    @dataclass
    class LLMConfig:
        provider: str = ""
        api_key: str = ""
        base_url: str = None


# Подстроки в id моделей, которые не подходят для text completion (чат/JSON) в краулере.
_NON_TEXT_COMPLETION_MODEL_HINTS = (
    "lyria",  # Google — генерация музыки, не LLM для текста
    "imagen-",
    "dall-e",
    "gpt-image",
    "/tts",
    "text-to-speech",
)


def _looks_like_non_text_completion_model(model_id: str) -> bool:
    m = (model_id or "").lower()
    return any(h in m for h in _NON_TEXT_COMPLETION_MODEL_HINTS)


def _default_text_model_fallback() -> str:
    """Не читает LLM_MODEL_NAME — там может быть та же ошибочная Lyria и т.п."""
    explicit = (os.getenv("CRAWL_LLM_TEXT_MODEL_FALLBACK") or "").strip()
    if explicit and not _looks_like_non_text_completion_model(explicit):
        return explicit
    return "google/gemini-2.0-flash-001"


def _resolve_llm_api_base(llm_provider: str) -> str:
    """HTTP endpoint для LiteLLM. Приоритет: LLM_API_BASE → OPENROUTER_BASE_URL → дефолт по провайдеру."""
    explicit = (
        (os.getenv("LLM_API_BASE") or "").strip()
        or (os.getenv("OPENROUTER_BASE_URL") or "").strip()
    )
    if explicit:
        return explicit.rstrip("/")
    p = (llm_provider or "openrouter").lower().strip()
    if p == "deepseek":
        return "https://api.deepseek.com/v1"
    if p == "openai":
        return "https://api.openai.com/v1"
    return "https://openrouter.ai/api/v1"


class CrawlerClient:
    def __init__(self, model: str = None, settings: dict = None, **_ignored):
        s = settings or {}
        self.model_name = (
            (model or "").strip()
            or (s.get("llm_model_name") or "").strip()
            or os.getenv("LLM_MODEL_NAME", "google/gemini-2.0-flash-001")
        )
        if _looks_like_non_text_completion_model(self.model_name):
            fb = _default_text_model_fallback()
            print(
                f"[CrawlerClient] WARNING: '{self.model_name}' не текстовая chat-модель "
                f"(например Lyria — музыка). Подставляем текстовую: {fb}. "
                f"Задайте LLM_MODEL_NAME или CRAWL_LLM_TEXT_MODEL_FALLBACK."
            )
            self.model_name = fb
        self._llm_provider = (
            s.get("llm_provider") or
            os.getenv("LLM_PROVIDER", "openrouter")
        ).strip()
        self._settings = s
        self.warnings: List[str] = []
        # Build key pool: DB value > ENV
        db_key = s.get("openrouter_api_key")
        self._key_pool: KeyPool = (
            KeyPool.from_value(db_key) if db_key
            else _get_openrouter_env_pool()
        )
        self.provider_string = f"{self._llm_provider}/{self.model_name}"
        self.base_url = _resolve_llm_api_base(self._llm_provider)
        self.api_key = self._key_pool.current()
        print(
            f"[CrawlerClient] provider={self._llm_provider} model={self.model_name} → "
            f"{self.provider_string} | api_base={self.base_url}"
        )
        # LiteLLM маршрутизирует по первому сегменту model: deepseek/… → native DeepSeek API,
        # openrouter/… → OpenRouter. Суффикс :free и «короткие» id — это OpenRouter, не native DeepSeek.
        lp = self._llm_provider.lower()
        if lp == "deepseek" and ":free" in (self.model_name or "").lower():
            print(
                "[CrawlerClient] WARNING: :free — модели бесплатного тира OpenRouter. "
                "С префиксом deepseek/ LiteLLM шлёт на API DeepSeek, где такого id нет. "
                "Для OpenRouter задайте llm_provider=openrouter и полный slug модели "
                "(например deepseek/deepseek-chat:free в имени модели в каталоге OR)."
            )
        if lp == "deepseek" and "openrouter" in self.base_url.lower():
            print(
                "[CrawlerClient] WARNING: LLM_PROVIDER=deepseek при api_base OpenRouter — "
                "строка model всё равно начинается с deepseek/… и LiteLLM может направлять "
                "вызов на native DeepSeek. Используйте llm_provider=openrouter для маршрута через OpenRouter."
            )
        self._build_llm_config()
        self.extraction_stats: Dict[str, Any] = {
            "urls_attempted": 0,
            "pdf_attempts": 0,
            "pdf_text_ok": 0,
            "http_first_attempts": 0,
            "http_first_ok": 0,
            "http_first_errors": 0,
            "direct_llm_skip_playwright": 0,
            "cheap_prefilter_skip_llm": 0,
            "domains": {},
        }
        self._last_llm_cache_key: str = ""
        # Последняя причина неуспеха direct LLM (для текста предупреждения пользователю).
        self._direct_llm_last_failure: Optional[str] = None

    def _build_llm_config(self):
        import inspect
        config_kwargs = {}
        model = self.model_name

        try:
            sig = inspect.signature(LLMConfig.__init__)
            params = sig.parameters

            if "provider" in params:
                config_kwargs["provider"] = self.provider_string
            # Always pass the full provider/model string so litellm routes correctly
            # regardless of whether crawl4ai uses `provider` or `model` internally.
            if "model" in params:
                config_kwargs["model"] = self.provider_string
            elif "model_name" in params:
                config_kwargs["model_name"] = self.provider_string
            if "api_key" in params:
                config_kwargs["api_key"] = self.api_key
            elif "api_token" in params:
                config_kwargs["api_token"] = self.api_key
            if "base_url" in params:
                config_kwargs["base_url"] = self.base_url
            elif "api_base" in params:
                config_kwargs["api_base"] = self.base_url
            if "custom_llm_provider" in params:
                config_kwargs["custom_llm_provider"] = self._llm_provider

            self.llm_config = LLMConfig(**config_kwargs)
        except Exception as e:
            print(f"[CrawlerClient] Error building LLMConfig: {e}. Falling back to default.")
            self.llm_config = LLMConfig()
            for k, v in config_kwargs.items():
                if hasattr(self.llm_config, k):
                    setattr(self.llm_config, k, v)
            if hasattr(self.llm_config, "provider") and not getattr(self.llm_config, "provider"):
                self.llm_config.provider = self.provider_string

    def _litellm_model_strings(self) -> List[str]:
        """Цепочка моделей для litellm: основная + LLM_FALLBACK_MODELS (при 429 — следующая)."""
        out: List[str] = [self.provider_string]
        raw = (os.getenv("LLM_FALLBACK_MODELS") or "").strip()
        for part in raw.split(","):
            p = (part or "").strip()
            if not p:
                continue
            full = p if p.startswith(f"{self._llm_provider}/") else f"{self._llm_provider}/{p}"
            mid = p.split("/")[-1] if "/" in p else p
            if _looks_like_non_text_completion_model(mid):
                print(
                    f"[CrawlerClient] skip LLM_FALLBACK_MODELS entry (non-text model): {p}"
                )
                continue
            out.append(full)
        seen = set()
        uniq: List[str] = []
        for m in out:
            if m not in seen:
                seen.add(m)
                uniq.append(m)
        return uniq

    def _append_crawl_user_notice(self, reason: str, url: str) -> None:
        u = (url or "").strip()
        if len(u) > 90:
            u = u[:87] + "..."
        msg = f"{reason} — {u}"
        if msg not in self.warnings:
            self.warnings.append(msg)

    def _stat_inc(self, key: str, n: int = 1) -> None:
        self.extraction_stats[key] = int(self.extraction_stats.get(key, 0)) + n

    def _record_domain(self, url: str) -> None:
        try:
            host = urlparse(url or "").netloc or ""
        except Exception:
            host = ""
        if not host:
            return
        dom = self.extraction_stats.setdefault("domains", {})
        dom[host] = dom.get(host, 0) + 1

    def _crawler_run_config_base(self, extraction_strategy: Any) -> CrawlerRunConfig:
        return CrawlerRunConfig(
            cache_mode=CacheMode.BYPASS,
            extraction_strategy=extraction_strategy,
            excluded_tags=["nav", "footer", "aside", "script", "style",
                           "header", "form", "iframe"],
            word_count_threshold=30,
            page_timeout=_crawl_page_timeout_ms(),
            wait_until=_crawl_wait_until(),
        )

    @staticmethod
    def _page_text_from_crawl_result(result: Any) -> str:
        """Prefer markdown; fall back to cleaned HTML (crawl4ai CrawlResult)."""
        try:
            md = getattr(result, "markdown", None)
            if md is not None:
                s = str(md).strip()
                if s:
                    return s
        except Exception:
            pass
        ch = getattr(result, "cleaned_html", None) or ""
        if isinstance(ch, str) and ch.strip():
            return ch.strip()
        html = getattr(result, "html", None) or ""
        return html.strip() if isinstance(html, str) else ""

    def _extract_readable_text(self, result: Any) -> str:
        """Raw crawl → trafilatura/main text + dedupe (LLM does not see nav/HTML noise)."""
        html = getattr(result, "html", None) or ""
        if not isinstance(html, str):
            html = ""
        fallback = self._page_text_from_crawl_result(result)
        return main_text_from_html_and_fallback(html, fallback)

    async def _http_fetch_html_and_text(self, url: str) -> Optional[Tuple[str, str]]:
        """GET через httpx → (cleaned_text, raw_html) или None."""
        if not _http_first_enabled():
            return None
        u = (url or "").strip()
        if not u.startswith(("http://", "https://")):
            return None
        self._stat_inc("http_first_attempts")
        try:
            client = _get_crawl_httpx_client()
            resp = await client.get(u)
            if resp.status_code != 200:
                return None
            ct = (resp.headers.get("content-type") or "").lower()
            if ct and "text/html" not in ct and "application/xhtml" not in ct and "xml" not in ct:
                if "pdf" in ct or "octet-stream" in ct or "msword" in ct:
                    return None
            raw = resp.text
            if not raw or len(raw) < 400:
                return None
            if not _looks_like_html(raw):
                return None
            text = main_text_from_html_and_fallback(raw, "")
            text = clean_flat_text(text) if text else ""
            if not text or len(text.strip()) < 80:
                return None
            self._stat_inc("http_first_ok")
            print(f"[CrawlerClient] HTTP-first text ok for {url} ({len(text)} chars)")
            return (text, raw)
        except Exception as e:
            self._stat_inc("http_first_errors")
            print(f"[CrawlerClient] HTTP-first failed for {url}: {e}")
            return None

    async def _try_http_first_page_text(self, url: str) -> Optional[str]:
        """GET HTML через httpx; извлечение текста как в pipeline. Не подходит для тяжёлого JS."""
        pair = await self._http_fetch_html_and_text(url)
        return pair[0] if pair else None

    async def _scrape_page_text_only(self, url: str) -> Optional[str]:
        """Fetch page without LLMExtractionStrategy (avoids crawl4ai chunk-merge path)."""
        hit = cache_get_text("page_text", url)
        if hit:
            print(f"[CrawlerClient] page text cache hit for {url}")
            return hit
        http_text = await self._try_http_first_page_text(url)
        if http_text:
            cache_set_text("page_text", url, http_text)
            record_page_snapshot(url, http_text)
            return http_text
        browser_config = BrowserConfig(
            headless=True,
            extra_args=["--disable-gpu", "--disable-dev-shm-usage", "--no-sandbox"],
        )
        cfg = self._crawler_run_config_base(extraction_strategy=None)
        async with AsyncWebCrawler(config=browser_config) as crawler:
            result = await crawler.arun(url=url, config=cfg)
        if not getattr(result, "success", False):
            print(f"[CrawlerClient] scrape-only failed for {url}: {getattr(result, 'error_message', None)}")
            return None
        text = self._extract_readable_text(result)
        if text:
            cache_set_text("page_text", url, text)
            record_page_snapshot(url, text)
        return text if text else None

    async def _fetch_pdf_text(self, url: str) -> Optional[str]:
        """Скачивание PDF и извлечение текста (pypdf)."""
        hit = cache_get_text("pdf_text", url)
        if hit:
            print(f"[CrawlerClient] PDF text cache hit for {url}")
            return hit
        try:
            timeout = float(os.getenv("CRAWL_PDF_DOWNLOAD_TIMEOUT_SEC", "90"))
        except ValueError:
            timeout = 90.0
        headers = {
            "User-Agent": (
                "ResearchActivityMonitor/1.0 "
                "(compatible; +https://github.com/; research crawler)"
            ),
        }
        try:
            async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
                r = await client.get(url, headers=headers)
                if r.status_code != 200:
                    print(f"[CrawlerClient] PDF GET {url} status={r.status_code}")
                    return None
                data = r.content
        except Exception as e:
            print(f"[CrawlerClient] PDF download error for {url}: {e}")
            return None
        try:
            from pypdf import PdfReader
        except ImportError:
            print("[CrawlerClient] pypdf not installed — cannot extract PDF text")
            return None
        try:
            reader = PdfReader(io.BytesIO(data))
            n = min(len(reader.pages), _pdf_max_pages())
            parts: List[str] = []
            for i in range(n):
                try:
                    t = reader.pages[i].extract_text() or ""
                except Exception:
                    t = ""
                if t.strip():
                    parts.append(t)
            out = "\n\n".join(parts).strip()
            if len(out) >= 40:
                cache_set_text("pdf_text", url, out)
                record_page_snapshot(url, out)
                return out
            return None
        except Exception as e:
            print(f"[CrawlerClient] PDF parse error for {url}: {e}")
            return None

    async def _direct_llm_completion_json(
        self,
        page_text: str,
        instruction: str,
        url: str,
        *,
        json_contract: str = "",
        retrieval_queries: Optional[List[str]] = None,
    ) -> Optional[str]:
        """Single-shot LLM call with page text — no crawl4ai merge."""
        max_chars = _direct_llm_max_chars()
        text_in = clean_flat_text(page_text) if page_text else ""
        fp = hashlib.sha256(text_in.encode("utf-8", errors="replace")).hexdigest()
        llm_key = llm_cache_key_material(
            url,
            instruction,
            fp,
            retrieval_queries,
            json_contract=json_contract or "",
            completion_model=self.provider_string,
        )
        self._last_llm_cache_key = llm_key
        cached_json = cache_get_text("llm_json", llm_key)
        if cached_json is not None:
            print(f"[CrawlerClient] direct LLM response cache hit for {url}")
            return cached_json
        if cache_get_text("llm_empty", llm_key) == "1":
            print(f"[CrawlerClient] llm_empty cache hit for {url}")
            return '{"achievements":[]}'
        if not cheap_relevance_pass(text_in, retrieval_queries or []):
            self._stat_inc("cheap_prefilter_skip_llm")
            cache_set_text("llm_empty", llm_key, "1")
            return '{"achievements":[]}'
        body, _stats = await prepare_text_for_llm_async(
            text_in,
            retrieval_queries,
            embedding_api_key=self.api_key,
            embedding_api_base=self.base_url,
        )
        if len(body) > max_chars:
            body = body[:max_chars] + "\n\n[... обрезано по лимиту CRAWL_DIRECT_LLM_MAX_CHARS ...]"
        contract = (json_contract or "").strip() or (
            'Ответь ОДНИМ JSON-объектом без markdown-ограждений и без комментариев. '
            'Форма: {"achievements": [ ... ]} — массив объектов достижений как выше.'
        )
        prompt = (
            f"{instruction}\n\n"
            "Правила: используй только факты из фрагментов ниже; не выдумывай достижений; "
            "поля description заполняй кратко.\n\n"
            f"{contract}\n\n"
            "Фрагменты страницы (после очистки и отбора по релевантности):\n---\n"
            f"{body}\n---"
        )
        try:
            max_tokens = int(os.getenv("CRAWL_DIRECT_LLM_MAX_TOKENS", "8192"))
        except ValueError:
            max_tokens = 8192
        try:
            llm_timeout = float(os.getenv("CRAWL_LLM_TIMEOUT_SEC", "120"))
        except ValueError:
            llm_timeout = 120.0
        self._direct_llm_last_failure = None
        last_err: Optional[Exception] = None

        if _llm_circuit_is_open():
            self._direct_llm_last_failure = "rate_limit"
            self._append_crawl_user_notice(
                "Обход chunk-merge: пауза после повторных лимитов API — остальные URL без LLM",
                url,
            )
            self._direct_llm_circuit_skip = True
            return '{"achievements":[]}'

        models_chain = self._litellm_model_strings()
        try:
            async with _llm_request_slot():
                inner_err: Optional[Exception] = None
                for model_str in models_chain:
                    try:
                        resp = await litellm.acompletion(
                            model=model_str,
                            api_key=self.api_key,
                            api_base=self.base_url,
                            messages=[{"role": "user", "content": prompt}],
                            temperature=0.2,
                            max_tokens=max_tokens,
                            timeout=llm_timeout,
                        )
                        choice = resp.choices[0].message
                        content = getattr(choice, "content", None) or ""
                        if isinstance(content, list):
                            content = "".join(
                                getattr(p, "text", str(p)) for p in content
                            )
                        text = _strip_llm_json_fences(str(content))
                        if not (text or "").strip():
                            self._direct_llm_last_failure = "empty"
                            print(f"[CrawlerClient] direct LLM empty content for {url}")
                            return None
                        self._direct_llm_last_failure = None
                        _llm_record_success()
                        cache_set_text("llm_json", llm_key, text)
                        return text
                    except Exception as e:
                        inner_err = e
                        msg = str(e)
                        if self._is_rate_limit_error(msg) and model_str != models_chain[-1]:
                            print(
                                f"[CrawlerClient] direct LLM 429 on {model_str}, "
                                f"fallback next model for {url}"
                            )
                            continue
                        raise
                if inner_err:
                    raise inner_err
        except Exception as e:
            last_err = e
            msg = str(e)
            print(f"[CrawlerClient] direct LLM completion error for {url}: {e}")
            if self._is_rate_limit_error(msg):
                self._direct_llm_last_failure = "rate_limit"
                _llm_record_429_after_chain()
            else:
                self._direct_llm_last_failure = "error"
        if last_err:
            print(f"[CrawlerClient] direct LLM exhausted for {url}: {last_err}")
        if self._is_rate_limit_error(str(last_err or "")):
            self._direct_llm_last_failure = "rate_limit"
        return None

    def _direct_llm_parse_raw_response(
        self, raw_json: Optional[str], url: str
    ) -> Optional[List[Dict[str, Any]]]:
        if not raw_json:
            reason = getattr(self, "_direct_llm_last_failure", None) or ""
            if reason == "rate_limit":
                self._append_crawl_user_notice(
                    "Обход chunk-merge: лимит запросов к модели (OpenRouter/провайдер); "
                    "повторите позже или смените модель",
                    url,
                )
            elif reason == "error":
                self._append_crawl_user_notice(
                    "Обход chunk-merge: ошибка вызова модели",
                    url,
                )
            else:
                self._append_crawl_user_notice(
                    "Обход chunk-merge: пустой ответ модели",
                    url,
                )
            return None
        if self._is_rate_limit_error(raw_json):
            self._append_crawl_user_notice(
                "Обход chunk-merge: лимит запросов к модели",
                url,
            )
            return None
        if _is_openrouter_model_gone(raw_json):
            if LLM_MODEL_UNAVAILABLE_USER_RU not in self.warnings:
                self.warnings.append(LLM_MODEL_UNAVAILABLE_USER_RU)
            return None
        parsed = self._parse_extracted(raw_json)
        if parsed is not None:
            print(f"[CrawlerClient] direct LLM parse ok for {url} ({len(parsed)} items)")
            circuit_skip = getattr(self, "_direct_llm_circuit_skip", False)
            self._direct_llm_circuit_skip = False
            if (
                len(parsed) == 0
                and not circuit_skip
                and getattr(self, "_last_llm_cache_key", "")
                and (os.getenv("CRAWL_LLM_EMPTY_CACHE", "1") or "1").strip().lower()
                not in ("0", "false", "no", "off")
            ):
                cache_set_text("llm_empty", self._last_llm_cache_key, "1")
            return parsed
        self._append_crawl_user_notice(
            "Обход chunk-merge: не удалось разобрать JSON ответа модели",
            url,
        )
        return None

    async def _direct_llm_two_step(
        self,
        page_text: str,
        instruction: str,
        url: str,
        retrieval_queries: Optional[List[str]] = None,
    ) -> Optional[List[Dict[str, Any]]]:
        """Два вызова LLM: кандидаты → финальная схема achievements (снижает пустые ответы)."""
        step1 = (
            "Шаг 1. По тексту страницы выпиши кандидаты в достижения исследователя "
            "(публикации, гранты, конференции, РИД, награды и т.д.). "
            'Верни ОДИН JSON: {"candidates": [{"title": "...", "evidence": "цитата из текста", "type_hint": "..."}]}. '
            'Если ничего нет — {"candidates": []}.'
        )
        raw1 = await self._direct_llm_completion_json(
            page_text,
            step1,
            url,
            json_contract='Форма: {"candidates": [ ... ]}',
            retrieval_queries=retrieval_queries,
        )
        cands: Any = None
        if raw1:
            try:
                data = json.loads(_strip_llm_json_fences(raw1))
                cands = data.get("candidates") if isinstance(data, dict) else None
            except (json.JSONDecodeError, TypeError):
                cands = None
        if not isinstance(cands, list) or len(cands) == 0:
            raw = await self._direct_llm_completion_json(
                page_text, instruction, url, retrieval_queries=retrieval_queries
            )
            return self._direct_llm_parse_raw_response(raw, url)
        summary = json.dumps(cands, ensure_ascii=False)[:8000]
        step2 = (
            f"{instruction}\n\n"
            "Кандидаты из шага 1 — преобразуй в финальную схему (только они, без выдумок):\n"
            f"{summary}"
        )
        raw2 = await self._direct_llm_completion_json(
            page_text, step2, url, retrieval_queries=retrieval_queries
        )
        return self._direct_llm_parse_raw_response(raw2, url)

    async def _direct_llm_from_page_text(
        self,
        page_text: str,
        instruction: str,
        url: str,
        retrieval_queries: Optional[List[str]] = None,
    ) -> Optional[List[Dict[str, Any]]]:
        if _two_step_extract_enabled():
            return await self._direct_llm_two_step(
                page_text, instruction, url, retrieval_queries=retrieval_queries
            )
        raw_json = await self._direct_llm_completion_json(
            page_text, instruction, url, retrieval_queries=retrieval_queries
        )
        return self._direct_llm_parse_raw_response(raw_json, url)

    async def _extract_via_direct_llm(
        self,
        url: str,
        _schema: Dict[str, Any],
        instruction: str,
        retrieval_queries: Optional[List[str]] = None,
    ) -> Optional[List[Dict[str, Any]]]:
        """Bypass crawl4ai LLM merge: scrape → litellm.acompletion → same JSON parsing."""
        print(f"[CrawlerClient] chunk-merge bypass: scrape + direct LLM for {url}")
        page_text = await self._scrape_page_text_only(url)
        if not page_text:
            self._append_crawl_user_notice(
                "Обход chunk-merge: не удалось получить текст страницы",
                url,
            )
            return None
        return await self._direct_llm_from_page_text(
            page_text, instruction, url, retrieval_queries=retrieval_queries
        )

    async def crawl_and_extract(
        self,
        url: str,
        schema: Dict[str, Any],
        instruction: str,
        retries: int = 3,
        _rate_limit_delay: float = 0.0,
        chunk_token_threshold: int = _DEFAULT_CHUNK_TOKEN_THRESHOLD,
        retrieval_queries: Optional[List[str]] = None,
    ) -> List[Dict[str, Any]]:
        if AsyncWebCrawler is None:
            print("Error: AsyncWebCrawler is not installed.")
            return []

        self._stat_inc("urls_attempted")
        self._record_domain(url)
        if is_pdf_url(url) and _direct_llm_extract_enabled():
            self._stat_inc("pdf_attempts")
            pdf_text = await self._fetch_pdf_text(url)
            if pdf_text:
                self._stat_inc("pdf_text_ok")
                direct = await self._direct_llm_from_page_text(
                    pdf_text, instruction, url, retrieval_queries=retrieval_queries
                )
                if direct is not None:
                    return direct
            self._append_crawl_user_notice(
                "PDF: не удалось извлечь текст или пустой/невалидный ответ модели",
                url,
            )
            return []

        if is_forced_download_url(url) and not is_pdf_url(url):
            self._append_crawl_user_notice(
                "Ссылка на скачивание файла, не HTML-страница — пропуск",
                url,
            )
            return []

        if _rate_limit_delay > 0:
            print(f"[CrawlerClient] Rate-limit backoff: sleeping {_rate_limit_delay:.0f}s before retry")
            await asyncio.sleep(_rate_limit_delay)

        if (
            skip_playwright_after_http_enabled()
            and _direct_llm_extract_enabled()
            and not is_pdf_url(url)
        ):
            pair = await self._http_fetch_html_and_text(url)
            if pair:
                text, raw_html = pair
                if not html_requires_playwright(raw_html, text):
                    self._stat_inc("direct_llm_skip_playwright")
                    direct = await self._direct_llm_from_page_text(
                        text,
                        instruction,
                        url,
                        retrieval_queries=retrieval_queries,
                    )
                    if direct is not None:
                        return direct

        extraction_strategy = LLMExtractionStrategy(
            llm_config=self.llm_config,
            schema=schema,
            extraction_type="schema",
            instruction=instruction,
            chunk_token_threshold=chunk_token_threshold,
        )

        browser_config = BrowserConfig(
            headless=True,
            extra_args=["--disable-gpu", "--disable-dev-shm-usage", "--no-sandbox"]
        )
        async with AsyncWebCrawler(config=browser_config) as crawler:
            try:
                async with _llm_request_slot():
                    result = await crawler.arun(
                        url=url,
                        config=self._crawler_run_config_base(extraction_strategy),
                    )
            except Exception as e:
                print(f"[CrawlerClient] arun exception for {url}: {e} (retries left: {retries})")
                if retries > 0:
                    msg = str(e)
                    retry_delay = (
                        _rate_limit_sleep_seconds(msg)
                        if self._is_rate_limit_error(msg)
                        else 2.0
                    )
                    await asyncio.sleep(retry_delay)
                    return await self.crawl_and_extract(
                        url,
                        schema,
                        instruction,
                        retries - 1,
                        0.0,
                        chunk_token_threshold,
                        retrieval_queries=retrieval_queries,
                    )
                self._append_crawl_user_notice("Не удалось загрузить страницу после повторов", url)
                return []

            print(f"[CrawlerClient] url={url} success={result.success} extracted_content={repr(result.extracted_content)[:300]} error={result.error_message}")
            if result.success and result.extracted_content:
                if _is_chunk_merge_usage_bug(result.extracted_content):
                    nxt = _next_chunk_threshold_for_merge_bug(chunk_token_threshold)
                    if retries > 0 and nxt is not None:
                        pause = (
                            1.5
                            if nxt == _CHUNK_TOKEN_THRESHOLD_SINGLE_PASS
                            else 2.5
                        )
                        print(
                            f"[CrawlerClient] crawl4ai chunk-merge bug (.usage on list); "
                            f"raising chunk_token_threshold {chunk_token_threshold} -> {nxt} "
                            f"(retries left after this: {retries - 1}) for {url}"
                        )
                        await asyncio.sleep(pause)
                        return await self.crawl_and_extract(
                            url,
                            schema,
                            instruction,
                            retries - 1,
                            0.0,
                            nxt,
                            retrieval_queries=retrieval_queries,
                        )
                    if _direct_llm_extract_enabled():
                        reused = self._extract_readable_text(result)
                        if reused and len(reused.strip()) >= 80:
                            print(
                                f"[CrawlerClient] chunk-merge bypass: reuse crawled text "
                                f"({len(reused)} chars) for {url}"
                            )
                            direct = await self._direct_llm_from_page_text(
                                reused, instruction, url, retrieval_queries=retrieval_queries
                            )
                            if direct is not None:
                                return direct
                        else:
                            direct = await self._extract_via_direct_llm(
                                url, schema, instruction, retrieval_queries=retrieval_queries
                            )
                            if direct is not None:
                                return direct
                    print(f"[CrawlerClient] crawl4ai chunk-merge bug persists for {url}")
                    if getattr(self, "_direct_llm_last_failure", None) != "rate_limit":
                        self._append_crawl_user_notice(
                            "Сбой извлечения (chunk-merge), страница пропущена",
                            url,
                        )
                    return []

                if self._is_rate_limit_error(result.extracted_content):
                    print(f"[CrawlerClient] Rate limit hit for key index {self._key_pool._index}")
                    if len(self._key_pool) > 1 and self._key_pool.rotate():
                        self.api_key = self._key_pool.current()
                        self._build_llm_config()
                        next_delay = _next_rate_limit_delay(_rate_limit_delay)
                        return await self.crawl_and_extract(
                            url,
                            schema,
                            instruction,
                            retries,
                            next_delay,
                            chunk_token_threshold,
                            retrieval_queries=retrieval_queries,
                        )
                    # All keys exhausted — wait and retry if budget allows
                    self._key_pool.reset_rotations()
                    next_delay = _next_rate_limit_delay(_rate_limit_delay)
                    if retries > 0:
                        return await self.crawl_and_extract(
                            url,
                            schema,
                            instruction,
                            retries - 1,
                            next_delay,
                            chunk_token_threshold,
                            retrieval_queries=retrieval_queries,
                        )
                    print(f"[CrawlerClient] Rate limit retries exhausted for {url}")
                    self._append_crawl_user_notice("Исчерпан лимит запросов к модели для URL", url)
                    return []

                parsed = self._parse_extracted(result.extracted_content)
                if parsed is not None:
                    return parsed
                if _is_openrouter_model_gone(result.extracted_content):
                    if LLM_MODEL_UNAVAILABLE_USER_RU not in self.warnings:
                        self.warnings.append(LLM_MODEL_UNAVAILABLE_USER_RU)
                    print(f"[CrawlerClient] LLM model unavailable for {url} (see warnings for user)")
                print(f"[CrawlerClient] Invalid extraction result for {url}")
                self._append_crawl_user_notice(
                    "Не удалось разобрать ответ модели (часто PDF/DOCX или неверный JSON)",
                    url,
                )
                return []

            if not result.success:
                print(f"[CrawlerClient] Crawl failed for {url}: {result.error_message} (retries left: {retries})")
                if "ACS-GOTO" in (result.error_message or "") and retries > 0:
                    await asyncio.sleep(2)
                    return await self.crawl_and_extract(
                        url,
                        schema,
                        instruction,
                        retries - 1,
                        0.0,
                        chunk_token_threshold,
                        retrieval_queries=retrieval_queries,
                    )
                err = (result.error_message or "").strip()
                hint = err[:140] + ("…" if len(err) > 140 else "")
                self._append_crawl_user_notice(
                    f"Ошибка загрузки или краула{f': {hint}' if hint else ''}",
                    url,
                )
            elif not result.extracted_content:
                print(f"[CrawlerClient] LLM extraction returned empty result for {url}")
                self._append_crawl_user_notice("Пустой ответ модели (для PDF/документов извлечение часто недоступно)", url)
            return []

    def _is_rate_limit_error(self, raw: str) -> bool:
        # Do not treat crawl4ai's 'list' / .usage chunk-merge bug as rate limit — see _is_chunk_merge_usage_bug.
        return (
            "RateLimitError" in raw
            or "rate_limit" in raw.lower()
            or "429" in raw
        )

    def _parse_extracted(self, raw: str) -> List[Dict[str, Any]]:
        """Пустой список или achievements: [] — валидный ответ «ничего не извлечено», не ошибка парсинга."""
        try:
            data = json.loads(raw)
            if isinstance(data, list):
                return [item for item in data if not item.get("error")]
            if isinstance(data, dict):
                ach = data.get("achievements")
                if isinstance(ach, list):
                    return [item for item in ach if not item.get("error")]
                for value in data.values():
                    if isinstance(value, list):
                        return [item for item in value if not item.get("error")]
                return [data]
        except (json.JSONDecodeError, Exception) as e:
            print(f"[CrawlerClient] JSON parse error: {e}")
        return None
