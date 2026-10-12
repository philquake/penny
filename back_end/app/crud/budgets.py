import calendar
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.budgets import Budget, BudgetPeriod
from app.models.transactions import Transaction, TransactionType


def create_budget(
    db: Session,
    user_id: int,
    category_id: int,
    amount: Decimal,
    period: BudgetPeriod,
    period_start: date,
    alert_threshold_percent: int,
    period_end: date | None = None,
) -> Budget:
    budget = Budget(
        user_id=user_id,
        category_id=category_id,
        amount=amount,
        period=period,
        period_start=period_start,
        period_end=resolve_period_end(period, period_start, period_end),
        alert_threshold_percent=alert_threshold_percent,
    )

    db.add(budget)
    db.commit()
    db.refresh(budget)

    return budget

def list_budgets(db: Session, user_id: int) -> list[Budget]:
    statement = (
        select(Budget)
        .where(Budget.user_id == user_id)
        .order_by(Budget.period_start.desc())
    )
    return list(db.scalars(statement).all())

def get_budget(db: Session, budget_id: int, user_id: int) -> Budget | None:
    statement = select(Budget).where(
        Budget.id == budget_id,
        Budget.user_id == user_id,
    )
    return db.scalar(statement)


def delete_budget(db: Session, budget: Budget) -> None:
    db.delete(budget)
    db.commit()

def compute_budget_status(
    db: Session,
    budget: Budget,
    as_of: date | None = None,
) -> dict:
    window_start, window_end = current_window(budget, as_of)

    statement = select(
        func.coalesce(func.sum(Transaction.amount), 0)
    ).where(
        Transaction.user_id == budget.user_id,
        Transaction.category_id == budget.category_id,
        Transaction.type == TransactionType.EXPENSE,
        Transaction.transaction_date >= window_start,
        Transaction.transaction_date <= window_end,
    )

    spent = db.scalar(statement) or 0
    remaining = budget.amount - spent

    percentage_used = (
        (spent / budget.amount) * Decimal("100")
        if budget.amount > 0
        else Decimal("0")
    )

    threshold_amount = (
        budget.amount
        * Decimal(budget.alert_threshold_percent)
        / Decimal("100")
    )

    threshold_crossed = (
        budget.alert_threshold_percent > 0 and spent >= threshold_amount
    )

    if percentage_used >= Decimal("100"):
        budget_status = "exceeded"
    elif threshold_crossed:
        budget_status = "alert"
    else:
        budget_status = "normal"

    return {
        "budget_id": budget.id,
        "spent_amount": spent,
        "remaining_amount": remaining,
        "percentage_used": percentage_used,
        "status": budget_status,
        "threshold_crossed": threshold_crossed,
    }

def update_budget(db: Session, budget: Budget, **fields) -> Budget:
    for key, value in fields.items():
        setattr(budget, key, value)

    budget.period_end = resolve_period_end(
        budget.period,
        budget.period_start,
        budget.period_end,
    )

    db.commit()
    db.refresh(budget)
    return budget

def _add_months(d: date, months: int) -> date:
    y, m = divmod(d.year * 12 + d.month - 1 + months, 12)
    m += 1
    return date(y, m, min(d.day, calendar.monthrange(y, m)[1]))


def _window(
    period: BudgetPeriod,
    anchor: date,
    today: date,
    custom_end: date | None = None,
) -> tuple[date, date]:
    """Return the (start, end) window of `period` that contains `today`.

    Rolling periods are measured from `anchor`. Custom periods never roll
    and return [anchor, custom_end].
    """
    if period == BudgetPeriod.CUSTOM:
        return anchor, custom_end

    if period == BudgetPeriod.WEEKLY:
        n = max(0, (today - anchor).days // 7)
        start = anchor + timedelta(days=7 * n)
        return start, start + timedelta(days=6)

    step = 1 if period == BudgetPeriod.MONTHLY else 12
    months = (today.year - anchor.year) * 12 + (today.month - anchor.month)
    n = max(0, months // step)
    start = _add_months(anchor, n * step)
    if start > today and n > 0:  # today falls before this period's anchor day
        n -= 1
        start = _add_months(anchor, n * step)
    end = _add_months(anchor, (n + 1) * step) - timedelta(days=1)
    return start, end


def current_window(budget: Budget, as_of: date | None = None) -> tuple[date, date]:
    return _window(
        budget.period,
        budget.period_start,
        as_of or date.today(),
        budget.period_end,
    )


def resolve_period_end(
    period: BudgetPeriod,
    period_start: date,
    period_end: date | None = None,
) -> date:
    """The end date to store for a budget.

    Custom budgets keep the caller's end date. Rolling budgets derive it from
    the anchor, so the stored value describes the first period and never
    goes stale. Raises ValueError for an invalid custom range.
    """
    if period == BudgetPeriod.CUSTOM:
        if period_end is None or period_end < period_start:
            raise ValueError("period_end must be on or after period_start")
        return period_end
    return _window(period, period_start, period_start)[1]
