# syntax=docker/dockerfile:1
# Production image (mirrors dev stages; use multi-stage in CI to cache layers)
FROM python:3.10-slim-bookworm

# Медленные/нестабильные сети: больше таймаут и повторы PyPI (+ кеш ~/.cache/pip ниже).
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=300 \
    PIP_RETRIES=10

WORKDIR /app

RUN rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get update \
    && apt-get install -y \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install torch --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

RUN python -m playwright install --with-deps chromium

COPY . .

ENV PYTHONUNBUFFERED=1
ENV PORT=50053
ENV HEALTH_HTTP_PORT=8080

EXPOSE 50053 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD /bin/sh -c 'curl -fsS "http://$HEALTHCHECK_HOST:$HEALTH_HTTP_PORT/health/live" || exit 1'

CMD ["python", "main.py"]
