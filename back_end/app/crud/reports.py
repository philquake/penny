from datetime import date
from decimal import Decimal

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session

from app.models.categories import Category
from app.models.transactions import Transaction, TransactionType


def _date_filtered(statement, start_date: date | None, end_date: date | None):
    if start_date is not None:
        statement = statement.where(Transaction.transaction_date >= start_date)
    if end_date is not None:
        statement = statement.where(Transaction.transaction_date <= end_date)
    return statement


def get_summary(
    db: Session,
    user_id: int,
    start_date: date | None = None,
    end_date: date | None = None,
) -> dict:

    statement = select(
        Transaction.type,
        func.coalesce(func.sum(Transaction.amount), 0),
    ).where(
        Transaction.user_id == user_id,
    ).group_by(Transaction.type)

    statement = _date_filtered(statement, start_date, end_date)

    totals = {row[0]: row[1] for row in db.execute(statement).all()}

    total_income = totals.get(TransactionType.INCOME, Decimal("0"))
    total_expense = totals.get(TransactionType.EXPENSE, Decimal("0"))
    total_transfer = totals.get(TransactionType.TRANSFER, Decimal("0"))
    total_savings = totals.get(TransactionType.SAVINGS, Decimal("0"))
    total_debt = totals.get(TransactionType.DEBT, Decimal("0"))

    return {
        "total_income": total_income,
        "total_expense": total_expense,
        "net": total_income - total_expense,
        "total_transfer": total_transfer,
        "total_savings": total_savings,
        "total_debt": total_debt,
    }


def get_by_category(
    db: Session,
    user_id: int,
    start_date: date | None = None,
    end_date: date | None = None,
) -> list[dict]:
    # LEFT JOIN so categories with zero matching transactions still show
    # up (needed for future budget-vs-actual coverage). Filters on the
    # transaction side must live in the ON clause, not WHERE — a WHERE
    # clause here would silently turn this back into an inner join by
    # dropping rows where the joined transaction columns are NULL.
    join_conditions = [
        Transaction.category_id == Category.id,
        Transaction.user_id == user_id,
        Transaction.type == TransactionType.EXPENSE,
    ]
    if start_date is not None:
        join_conditions.append(Transaction.transaction_date >= start_date)
    if end_date is not None:
        join_conditions.append(Transaction.transaction_date <= end_date)

    statement = (
        select(
            Category.id,
            Category.name,
            func.coalesce(func.sum(Transaction.amount), 0),
        )
        .outerjoin(Transaction, and_(*join_conditions))
        .where(
            (Category.user_id == user_id) | (Category.user_id.is_(None)),
            Category.type == TransactionType.EXPENSE,
        )
        .group_by(Category.id, Category.name)
        .order_by(func.sum(Transaction.amount).desc().nullslast())
    )

    rows = db.execute(statement).all()

    return [
        {"category_id": cid, "category_name": name, "total": total}
        for cid, name, total in rows
    ]

def get_trend(
    db: Session,
    user_id: int,
    start_date: date | None = None,
    end_date: date | None = None,
) -> list[dict]:
    # NOTE: strftime is SQLite-specific. If/when this moves to Postgres,
    # swap this for func.date_trunc('month', Transaction.transaction_date).
    month_bucket = func.strftime("%Y-%m", Transaction.transaction_date)

    statement = (
        select(
            month_bucket,
            Transaction.type,
            func.coalesce(func.sum(Transaction.amount), 0),
        )
        .where(Transaction.user_id == user_id)
        .group_by(month_bucket, Transaction.type)
        .order_by(month_bucket)
    )

    statement = _date_filtered(statement, start_date, end_date)

    rows = db.execute(statement).all()

    buckets: dict[str, dict] = {}
    for month, txn_type, total in rows:
        bucket = buckets.setdefault(
            month, {"month": month, "income": Decimal("0"), "expense": Decimal("0")}
        )
        if txn_type == TransactionType.INCOME:
            bucket["income"] = total
        elif txn_type == TransactionType.EXPENSE:
            bucket["expense"] = total

    return [buckets[month] for month in sorted(buckets)]