import calendar
from datetime import date
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.debts import Debt, DebtEntry, DebtKind, EntryType
from app.services.debt_math import add_months, money
from sqlalchemy import func, select, update
from app.models.transactions import Transaction

_SIGN = {
    EntryType.CHARGE: 1,
    EntryType.INTEREST: 1,
    EntryType.FEE: 1,
    EntryType.PAYMENT: -1,
}


def create_debt(db: Session, user_id: int, **fields) -> Debt:
    debt = Debt(user_id=user_id, last_accrued_date=fields["start_date"], **fields)
    db.add(debt)
    db.commit()
    db.refresh(debt)
    return debt


def list_debts(db: Session, user_id: int) -> list[Debt]:
    stmt = select(Debt).where(Debt.user_id == user_id).order_by(Debt.name)
    return list(db.scalars(stmt).all())


def get_debt(db: Session, debt_id: int, user_id: int) -> Debt | None:
    return db.scalar(select(Debt).where(Debt.id == debt_id, Debt.user_id == user_id))


def update_debt(db: Session, debt: Debt, **fields) -> Debt:
    for key, value in fields.items():
        setattr(debt, key, value)
    db.commit()
    db.refresh(debt)
    return debt


# ---- ledger -----------------------------------------------------------

def add_entry(db: Session, debt: Debt, **fields) -> DebtEntry:
    entry = DebtEntry(debt_id=debt.id, **fields)
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry


def list_entries(db: Session, debt_id: int) -> list[DebtEntry]:
    stmt = (
        select(DebtEntry)
        .where(DebtEntry.debt_id == debt_id)
        .order_by(DebtEntry.entry_date.desc(), DebtEntry.id.desc())
    )
    return list(db.scalars(stmt).all())


def get_entry(db: Session, debt_id: int, entry_id: int) -> DebtEntry | None:
    return db.scalar(
        select(DebtEntry).where(DebtEntry.id == entry_id, DebtEntry.debt_id == debt_id)
    )


def delete_debt(db: Session, debt: Debt) -> None:
    db.execute(update(Transaction).where(Transaction.debt_id == debt.id).values(debt_id=None))
    for entry in list_entries(db, debt.id):
        db.delete(entry)
    db.delete(debt)
    db.commit()

def delete_payment_entry(db: Session, transaction_id: int) -> None:
    entry = db.scalar(select(DebtEntry).where(DebtEntry.transaction_id == transaction_id))
    if entry:
        db.delete(entry)
        db.commit()

def get_balance(db: Session, debt: Debt, upto: date | None = None) -> Decimal:
    stmt = (
        select(DebtEntry.type, func.coalesce(func.sum(DebtEntry.amount), 0))
        .where(DebtEntry.debt_id == debt.id)
        .group_by(DebtEntry.type)
    )
    if upto is not None:
        stmt = stmt.where(DebtEntry.entry_date <= upto)

    total = Decimal(debt.opening_balance)
    for entry_type, amount in db.execute(stmt).all():
        total += _SIGN[entry_type] * Decimal(str(amount))
    return total

def sync_payment_entry(db: Session, tx: Transaction) -> None:
    """Keep the ledger payment linked to `tx` matching the transaction."""
    entry = db.scalar(select(DebtEntry).where(DebtEntry.transaction_id == tx.id))

    if tx.debt_id is None:
        if entry:
            db.delete(entry)
            db.commit()
        return

    if entry is None:
        entry = DebtEntry(debt_id=tx.debt_id, type=EntryType.PAYMENT, transaction_id=tx.id)
        db.add(entry)
    entry.debt_id = tx.debt_id
    entry.amount = tx.amount
    entry.entry_date = tx.transaction_date
    entry.note = tx.description or "Payment"
    db.commit()
    
# ---- interest ---------------------------------------------------------

def _next_boundary(start: date, after: date) -> date:
    """Next monthly anchor (start_date + n months) strictly after `after`.
    Anchoring to start_date avoids day-of-month drift (31st -> 30th -> 28th)."""
    n = 1
    while True:
        boundary = add_months(start, n)
        if boundary > after:
            return boundary
        n += 1


def _interest_for_period(db: Session, debt: Debt, start: date, end: date) -> Decimal:
    """Daily interest (APR/365) on the actual running balance between start and end."""
    daily_rate = Decimal(debt.apr) / Decimal(36500)
    balance = get_balance(db, debt, upto=start)

    events = db.execute(
        select(DebtEntry.entry_date, DebtEntry.type, DebtEntry.amount)
        .where(
            DebtEntry.debt_id == debt.id,
            DebtEntry.entry_date > start,
            DebtEntry.entry_date <= end,
        )
        .order_by(DebtEntry.entry_date)
    ).all()

    interest, cursor = Decimal("0"), start
    for event_date, entry_type, amount in [*events, (end, None, 0)]:
        days = (event_date - cursor).days
        if days > 0 and balance > 0:
            interest += balance * daily_rate * days
        if entry_type is not None:
            balance += _SIGN[entry_type] * Decimal(str(amount))
        cursor = event_date
    return money(interest)


def accrue_interest(db: Session, debt: Debt, today: date | None = None) -> None:
    """Post an INTEREST entry for every completed month since the last accrual.
    Idempotent: safe to call on every read."""
    today = today or date.today()
    if not debt.is_active:
        return

    changed = False
    while True:
        boundary = _next_boundary(debt.start_date, debt.last_accrued_date)
        if boundary > today:
            break
        interest = _interest_for_period(db, debt, debt.last_accrued_date, boundary)
        if interest > 0:
            db.add(DebtEntry(
                debt_id=debt.id, type=EntryType.INTEREST, amount=interest,
                entry_date=boundary, note="Auto-accrued interest",
            ))
            db.flush()  # SessionLocal has autoflush=False; next loop must see this row
        debt.last_accrued_date = boundary
        changed = True

    if changed:
        db.commit()
        db.refresh(debt)


# ---- summary ----------------------------------------------------------

def next_due_date(due_day: int | None, today: date) -> date | None:
    if not due_day:
        return None

    def clamp(y: int, m: int) -> date:
        return date(y, m, min(due_day, calendar.monthrange(y, m)[1]))

    due = clamp(today.year, today.month)
    if due < today:
        y, m = (today.year + 1, 1) if today.month == 12 else (today.year, today.month + 1)
        due = clamp(y, m)
    return due


def summarize(db: Session, debt: Debt, today: date | None = None) -> dict:
    today = today or date.today()
    balance = get_balance(db, debt)
    utilization = None
    if debt.kind == DebtKind.CREDIT_CARD and debt.credit_limit:
        utilization = (balance / Decimal(debt.credit_limit) * 100).quantize(Decimal("0.01"))

    return {
        "id": debt.id,
        "name": debt.name,
        "kind": debt.kind,
        "opening_balance": debt.opening_balance,
        "balance": balance,
        "apr": debt.apr,
        "minimum_payment": debt.minimum_payment,
        "credit_limit": debt.credit_limit,
        "utilization_percent": utilization,
        "due_day": debt.due_day,
        "next_due_date": next_due_date(debt.due_day, today),
        "monthly_interest_estimate": money(balance * Decimal(debt.apr) / 1200) if balance > 0 else Decimal("0.00"),
        "start_date": debt.start_date,
        "is_active": debt.is_active,
    }