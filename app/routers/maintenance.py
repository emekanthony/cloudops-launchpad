from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import MaintenanceRecord
from app.routers.equipment import get_equipment_or_404
from app.schemas import MaintenanceIn, MaintenanceOut

router = APIRouter(prefix="/equipment/{equipment_id}/maintenance", tags=["maintenance"])


@router.get("", response_model=list[MaintenanceOut])
def list_records(equipment_id: int, db: Session = Depends(get_db)):
    get_equipment_or_404(equipment_id, db)
    return db.scalars(
        select(MaintenanceRecord)
        .where(MaintenanceRecord.equipment_id == equipment_id)
        .order_by(MaintenanceRecord.performed_at.desc())
    ).all()


@router.post("", response_model=MaintenanceOut, status_code=status.HTTP_201_CREATED)
def create_record(equipment_id: int, payload: MaintenanceIn, db: Session = Depends(get_db)):
    get_equipment_or_404(equipment_id, db)
    record = MaintenanceRecord(equipment_id=equipment_id, **payload.model_dump())
    db.add(record)
    db.commit()
    return record
