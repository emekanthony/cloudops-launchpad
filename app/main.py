from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

from app.config import settings
from app.routers import equipment, health, maintenance

app = FastAPI(title="CloudOps Launchpad", version=settings.app_version)
app.include_router(health.router)
app.include_router(equipment.router)
app.include_router(maintenance.router)

Instrumentator(excluded_handlers=["/healthz", "/readyz", "/metrics"]).instrument(app).expose(
    app, include_in_schema=False
)
