from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Equipment, EquipmentStatus, MaintenanceRecord
from app.schemas import EquipmentIn, EquipmentOut, EquipmentUpdate, OverdueOut

router = APIRouter(prefix="/equipment", tags=["equipment"])


def get_equipment_or_404(equipment_id: int, db: Session) -> Equipment:
    equipment = db.get(Equipment, equipment_id)
    if equipment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Equipment not found")
    return equipment


@router.get("", response_model=list[EquipmentOut])
def list_equipment(
    status_filter: EquipmentStatus | None = None,
    limit: int = 100,
    offset: int = 0,
    db: Session = Depends(get_db),
):
    query = select(Equipment).order_by(Equipment.id).limit(min(limit, 500)).offset(offset)
    if status_filter is not None:
        query = query.where(Equipment.status == status_filter)
    return db.scalars(query).all()


@router.post("", response_model=EquipmentOut, status_code=status.HTTP_201_CREATED)
def create_equipment(payload: EquipmentIn, db: Session = Depends(get_db)):
    equipment = Equipment(**payload.model_dump())
    db.add(equipment)
    db.commit()
    return equipment


@router.get("/{equipment_id}", response_model=EquipmentOut)
def get_equipment(equipment_id: int, db: Session = Depends(get_db)):
    return get_equipment_or_404(equipment_id, db)


@router.patch("/{equipment_id}", response_model=EquipmentOut)
def update_equipment(equipment_id: int, payload: EquipmentUpdate, db: Session = Depends(get_db)):
    equipment = get_equipment_or_404(equipment_id, db)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(equipment, field, value)
    db.commit()
    return equipment


@router.delete("/{equipment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_equipment(equipment_id: int, db: Session = Depends(get_db)):
    db.delete(get_equipment_or_404(equipment_id, db))
    db.commit()


@router.get("/{equipment_id}/overdue", response_model=OverdueOut)
def equipment_overdue(equipment_id: int, db: Session = Depends(get_db)):
    get_equipment_or_404(equipment_id, db)
    latest = db.scalars(
        select(MaintenanceRecord)
        .where(MaintenanceRecord.equipment_id == equipment_id)
        .order_by(MaintenanceRecord.performed_at.desc(), MaintenanceRecord.id.desc())
        .limit(1)
    ).first()
    next_due = latest.next_due if latest else None
    days = (date.today() - next_due).days if next_due else 0
    return OverdueOut(
        equipment_id=equipment_id, overdue=days > 0, next_due=next_due, days_overdue=max(days, 0)
    )
