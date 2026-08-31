from datetime import date
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.budgets import Budget, BudgetPeriod
from app.models.transactions import Transaction


def create_budget(
    db: Session,
    user_id: int,
    category_id: int,
    amount: Decimal,
    period: BudgetPeriod,
    period_start: date,
    period_end: date,
    alert_threshold_percent: int,
) -> Budget:
    
    budget = Budget(
        user_id=user_id,
        category_id=category_id,
        amount=amount,
        period=period,
        period_start=period_start,
        period_end=period_end,
        alert_threshold_percent=alert_threshold_percent,
    )

    db.add(budget)
    db.commit()
    db.refresh(budget)

    return budget

def list_budgets(
    db: Session,
    user_id: int,
) -> list[Budget]:
    
    statement = (
        select(Budget)
        .where(Budget.user_id == user_id)
        .order_by(Budget.period_start.desc())
    )

    return list(db.scalars(statement).all())

def get_budget(
    db: Session,
    budget_id: int,
    user_id: int,
) -> Budget | None:
    
    statement = select(Budget).where(
        Budget.id == budget_id,
        Budget.user_id == user_id,
    )

    return db.scalar(statement)

def delete_budget(
    db: Session,
    budget: Budget,
) -> None:
    
    db.delete(budget)
    db.commit()
    
def compute_budget_status(
    db: Session,
    budget: Budget,
) -> dict:
    
    statement = select(
        func.coalesce(func.sum(Transaction.amount), 0)
    ).where(
        Transaction.user_id == budget.user_id,
        Transaction.category_id == budget.category_id,
        Transaction.transaction_date >= budget.period_start,
        Transaction.transaction_date <= budget.period_end,
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
    
    threshold_crossed = spent >= threshold_amount
    
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