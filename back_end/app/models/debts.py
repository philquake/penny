from datetime import date, datetime
from decimal import Decimal
from enum import Enum

from sqlalchemy import (
    Boolean, Date, DateTime, ForeignKey, Integer, Numeric, String, Text,
)
from sqlalchemy import Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class DebtKind(str, Enum):
    CREDIT_CARD = "credit_card"
    LOAN = "loan"


class EntryType(str, Enum):
    CHARGE = "charge"      # adds to balance (card purchase, extra borrowing)
    PAYMENT = "payment"    # reduces balance
    INTEREST = "interest"  # adds to balance (auto-accrued or manual)
    FEE = "fee"            # adds to balance (late fee, annual fee)


class Debt(Base):
    __tablename__ = "debts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    kind: Mapped[DebtKind] = mapped_column(SQLEnum(DebtKind))

    # Balance when tracking began. Current balance = this + ledger entries.
    opening_balance: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    apr: Mapped[Decimal] = mapped_column(Numeric(6, 3))  # percent, e.g. 24.99
    minimum_payment: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    credit_limit: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    due_day: Mapped[int | None] = mapped_column(Integer, nullable=True)

    start_date: Mapped[date] = mapped_column(Date)
    last_accrued_date: Mapped[date] = mapped_column(Date)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(tz=None)
    )


class DebtEntry(Base):
    __tablename__ = "debt_entries"

    id: Mapped[int] = mapped_column(primary_key=True)
    debt_id: Mapped[int] = mapped_column(ForeignKey("debts.id"), index=True)
    type: Mapped[EntryType] = mapped_column(SQLEnum(EntryType))
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))  # always positive
    entry_date: Mapped[date] = mapped_column(Date)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(tz=None)
    )
    transaction_id: Mapped[int | None] = mapped_column(
        ForeignKey("transactions.id"), nullable=True, index=True
    )