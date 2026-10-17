"""initial schema: equipment and maintenance_records

Revision ID: 0001
Revises:
Create Date: 2026-10-21
"""
import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

status_enum = sa.Enum("operational", "maintenance", "out_of_service", name="equipment_status")


def upgrade() -> None:
    op.create_table(
        "equipment",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("type", sa.String(60), nullable=False),
        sa.Column("location", sa.String(120), nullable=False),
        sa.Column("status", status_enum, nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_table(
        "maintenance_records",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column(
            "equipment_id",
            sa.Integer,
            sa.ForeignKey("equipment.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("performed_at", sa.Date, nullable=False),
        sa.Column("technician", sa.String(120), nullable=False),
        sa.Column("notes", sa.Text, nullable=False),
        sa.Column("next_due", sa.Date, nullable=True),
    )


def downgrade() -> None:
    op.drop_table("maintenance_records")
    op.drop_table("equipment")
    status_enum.drop(op.get_bind(), checkfirst=True)
