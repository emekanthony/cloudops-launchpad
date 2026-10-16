from datetime import date

from pydantic import BaseModel, ConfigDict, Field

from app.models import EquipmentStatus


class EquipmentIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    type: str = Field(min_length=1, max_length=60)
    location: str = Field(min_length=1, max_length=120)
    status: EquipmentStatus = EquipmentStatus.operational


class EquipmentUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    type: str | None = Field(default=None, min_length=1, max_length=60)
    location: str | None = Field(default=None, min_length=1, max_length=120)
    status: EquipmentStatus | None = None


class EquipmentOut(EquipmentIn):
    model_config = ConfigDict(from_attributes=True)
    id: int


class MaintenanceIn(BaseModel):
    performed_at: date
    technician: str = Field(min_length=1, max_length=120)
    notes: str = ""
    next_due: date | None = None


class MaintenanceOut(MaintenanceIn):
    model_config = ConfigDict(from_attributes=True)
    id: int
    equipment_id: int


class OverdueOut(BaseModel):
    equipment_id: int
    overdue: bool
    next_due: date | None
    days_overdue: int
