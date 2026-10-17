from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db

router = APIRouter(tags=["health"])


@router.get("/healthz")
def healthz():
    """Liveness: the process is up and serving requests."""
    return {"status": "ok", "version": settings.app_version}


@router.get("/readyz")
def readyz(db: Session = Depends(get_db)):
    """Readiness: the database is reachable."""
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001
        return JSONResponse({"status": "unavailable", "detail": type(exc).__name__}, 503)
    return {"status": "ready"}
