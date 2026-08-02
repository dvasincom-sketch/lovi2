# syntax=docker/dockerfile:1
# lovi2 — репозиторий развёртывания. Собирает единый образ:
# lovi-web (React) -> статика, insalon (FastAPI) -> рантайм, отдающий и API, и статику.
# Оба продуктовых репозитория публичные и клонируются на этапе сборки по закреплённой ссылке.

# --- Stage 1: сборка фронта lovi-web ---
FROM node:22-slim AS web
ARG LOVI_WEB_REPO=https://github.com/dvasincom-sketch/lovi-web.git
ARG LOVI_WEB_REF=main
ARG VITE_API_BASE=""
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN git clone --depth 1 --branch ${LOVI_WEB_REF} ${LOVI_WEB_REPO} .
RUN npm install --no-audit --no-fund
# single-app: фронт и API на одном origin -> относительные запросы (пустой VITE_API_BASE)
RUN printf 'VITE_API_BASE=%s\n' "${VITE_API_BASE}" > .env.production
RUN npm run build

# --- Stage 2: рантайм FastAPI (insalon) ---
FROM python:3.11-slim AS app
ARG INSALON_REPO=https://github.com/dvasincom-sketch/insalon.git
ARG INSALON_REF=main
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN git clone --depth 1 --branch ${INSALON_REF} ${INSALON_REPO} .
RUN pip install --no-cache-dir -r requirements.txt
# собранный фронт -> WEB_DIR, который читает app/main.py
COPY --from=web /build/dist /app/web
ENV WEB_DIR=/app/web
ENV PORT=8000
EXPOSE 8000
CMD ["sh","-c","uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
