# ---- build stage: compile wheels so the runtime image needs no build tools ----
FROM python:3.12-slim AS build
WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# ---- runtime stage ----
FROM python:3.12-slim
ARG APP_VERSION=dev
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_APP_VERSION=${APP_VERSION}
RUN groupadd --system --gid 10001 app && useradd --system --uid 10001 --gid app app \
    && apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
WORKDIR /srv
COPY --from=build /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels \
    && pip uninstall -y pip setuptools wheel || true
COPY alembic.ini .
COPY app ./app
USER 10001
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
