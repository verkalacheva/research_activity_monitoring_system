import os
import json
import time
import typing
import asyncio
import litellm
from collections import deque
from typing import List, Dict, Any, Optional
from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode
from crawl4ai.extraction_strategy import LLMExtractionStrategy
from translations.ru import LLM_MODEL_UNAVAILABLE_USER_RU

# Retry up to 3 times with increasing backoff before surfacing errors to crawl4ai
litellm.num_retries = 3
litellm.retry_on = ["RateLimitError", "ServiceUnavailableError", "Timeout"]
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
    max_calls=int(os.getenv("LLM_RPM", "8")),
    period=60.0,
)

# Initial and max backoff for upstream rate limits (e.g. Venice behind OpenRouter free tier).
# Venice's window is longer than a few seconds — start at 60s, cap at 5 min.
_RATE_LIMIT_INITIAL_DELAY = float(os.getenv("RATE_LIMIT_INITIAL_DELAY", "60"))
_RATE_LIMIT_MAX_DELAY     = float(os.getenv("RATE_LIMIT_MAX_DELAY",     "300"))

_DEFAULT_CHUNK_TOKEN_THRESHOLD = int(os.getenv("CRAWL_CHUNK_TOKEN_THRESHOLD", "8000"))
_CHUNK_TOKEN_THRESHOLD_SINGLE_PASS = int(os.getenv("CRAWL_CHUNK_TOKEN_THRESHOLD_SINGLE_PASS", "200000"))


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


class CrawlerClient:
    def __init__(self, model: str = None, settings: dict = None, **_ignored):
        s = settings or {}
        self.model_name = (
            (model or "").strip() or
            s.get("llm_model_name") or
            os.getenv("LLM_MODEL_NAME", "google/gemini-2.0-flash-001")
        )
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
        self.base_url = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
        self.api_key = self._key_pool.current()
        print(f"[CrawlerClient] provider={self._llm_provider} model={self.model_name} → {self.provider_string}")
        self._build_llm_config()

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

    async def crawl_and_extract(
        self,
        url: str,
        schema: Dict[str, Any],
        instruction: str,
        retries: int = 2,
        _rate_limit_delay: float = 0.0,
        chunk_token_threshold: int = _DEFAULT_CHUNK_TOKEN_THRESHOLD,
    ) -> List[Dict[str, Any]]:
        if AsyncWebCrawler is None:
            print("Error: AsyncWebCrawler is not installed.")
            return []

        if _rate_limit_delay > 0:
            print(f"[CrawlerClient] Rate-limit backoff: sleeping {_rate_limit_delay:.0f}s before retry")
            await asyncio.sleep(_rate_limit_delay)

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
            await _llm_rate_limiter.acquire()
            try:
                result = await crawler.arun(
                    url=url,
                    config=CrawlerRunConfig(
                        cache_mode=CacheMode.BYPASS,
                        extraction_strategy=extraction_strategy,
                        # Strip boilerplate HTML — nav, sidebar, footer, scripts, ads —
                        # so that only the main article text reaches the LLM.
                        excluded_tags=["nav", "footer", "aside", "script", "style",
                                       "header", "form", "iframe"],
                        word_count_threshold=30,
                        page_timeout=60000,
                        wait_until="networkidle"
                    )
                )
            except Exception as e:
                print(f"[CrawlerClient] arun exception for {url}: {e} (retries left: {retries})")
                if retries > 0:
                    retry_delay = 10.0 if self._is_rate_limit_error(str(e)) else 2.0
                    await asyncio.sleep(retry_delay)
                    return await self.crawl_and_extract(
                        url, schema, instruction, retries - 1, 0.0, chunk_token_threshold
                    )
                return []

            print(f"[CrawlerClient] url={url} success={result.success} extracted_content={repr(result.extracted_content)[:300]} error={result.error_message}")
            if result.success and result.extracted_content:
                if _is_chunk_merge_usage_bug(result.extracted_content):
                    if retries > 0 and chunk_token_threshold < _CHUNK_TOKEN_THRESHOLD_SINGLE_PASS:
                        print(
                            f"[CrawlerClient] crawl4ai chunk-merge bug (.usage on list); "
                            f"retrying with single-chunk threshold={_CHUNK_TOKEN_THRESHOLD_SINGLE_PASS} for {url}"
                        )
                        await asyncio.sleep(1.5)
                        return await self.crawl_and_extract(
                            url,
                            schema,
                            instruction,
                            retries - 1,
                            0.0,
                            _CHUNK_TOKEN_THRESHOLD_SINGLE_PASS,
                        )
                    print(f"[CrawlerClient] crawl4ai chunk-merge bug persists for {url}")
                    return []

                if self._is_rate_limit_error(result.extracted_content):
                    print(f"[CrawlerClient] Rate limit hit for key index {self._key_pool._index}")
                    if len(self._key_pool) > 1 and self._key_pool.rotate():
                        self.api_key = self._key_pool.current()
                        self._build_llm_config()
                        next_delay = _next_rate_limit_delay(_rate_limit_delay)
                        return await self.crawl_and_extract(
                            url, schema, instruction, retries, next_delay, chunk_token_threshold
                        )
                    # All keys exhausted — wait and retry if budget allows
                    self._key_pool.reset_rotations()
                    next_delay = _next_rate_limit_delay(_rate_limit_delay)
                    if retries > 0:
                        return await self.crawl_and_extract(
                            url, schema, instruction, retries - 1, next_delay, chunk_token_threshold
                        )
                    print(f"[CrawlerClient] Rate limit retries exhausted for {url}")
                    return []

                parsed = self._parse_extracted(result.extracted_content)
                if parsed is not None:
                    return parsed
                if _is_openrouter_model_gone(result.extracted_content):
                    if LLM_MODEL_UNAVAILABLE_USER_RU not in self.warnings:
                        self.warnings.append(LLM_MODEL_UNAVAILABLE_USER_RU)
                    print(f"[CrawlerClient] LLM model unavailable for {url} (see warnings for user)")
                print(f"[CrawlerClient] Invalid extraction result for {url}")
                return []

            if not result.success:
                print(f"[CrawlerClient] Crawl failed for {url}: {result.error_message} (retries left: {retries})")
                if "ACS-GOTO" in (result.error_message or "") and retries > 0:
                    await asyncio.sleep(2)
                    return await self.crawl_and_extract(
                        url, schema, instruction, retries - 1, 0.0, chunk_token_threshold
                    )
            elif not result.extracted_content:
                print(f"[CrawlerClient] LLM extraction returned empty result for {url}")
            return []

    def _is_rate_limit_error(self, raw: str) -> bool:
        # Do not treat crawl4ai's 'list' / .usage chunk-merge bug as rate limit — see _is_chunk_merge_usage_bug.
        return (
            "RateLimitError" in raw
            or "rate_limit" in raw.lower()
            or "429" in raw
        )

    def _parse_extracted(self, raw: str) -> List[Dict[str, Any]]:
        try:
            data = json.loads(raw)
            if isinstance(data, list):
                valid = [item for item in data if not item.get("error")]
                return valid if valid else None
            if isinstance(data, dict):
                for value in data.values():
                    if isinstance(value, list):
                        valid = [item for item in value if not item.get("error")]
                        return valid if valid else None
                return [data]
        except (json.JSONDecodeError, Exception) as e:
            print(f"[CrawlerClient] JSON parse error: {e}")
        return None
