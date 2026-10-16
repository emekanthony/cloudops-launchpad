from datetime import date, datetime
from enum import StrEnum

from sqlalchemy import Date, DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class EquipmentStatus(StrEnum):
    operational = "operational"
    maintenance = "maintenance"
    out_of_service = "out_of_service"


class Equipment(Base):
    __tablename__ = "equipment"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    type: Mapped[str] = mapped_column(String(60))
    location: Mapped[str] = mapped_column(String(120))
    status: Mapped[EquipmentStatus] = mapped_column(
        Enum(EquipmentStatus, name="equipment_status"), default=EquipmentStatus.operational
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    records: Mapped[list["MaintenanceRecord"]] = relationship(
        back_populates="equipment", cascade="all, delete-orphan", order_by="MaintenanceRecord.id"
    )


class MaintenanceRecord(Base):
    __tablename__ = "maintenance_records"

    id: Mapped[int] = mapped_column(primary_key=True)
    equipment_id: Mapped[int] = mapped_column(ForeignKey("equipment.id", ondelete="CASCADE"))
    performed_at: Mapped[date] = mapped_column(Date)
    technician: Mapped[str] = mapped_column(String(120))
    notes: Mapped[str] = mapped_column(Text, default="")
    next_due: Mapped[date | None] = mapped_column(Date, nullable=True)

    equipment: Mapped[Equipment] = relationship(back_populates="records")
