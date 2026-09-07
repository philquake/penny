from datetime import date
from decimal import Decimal

from app.crud.categories import create_category
from app.crud.transactions import create_transaction
from app.crud.reports import get_summary, get_by_category, get_trend
from app.models.transactions import TransactionType


def test_get_summary_groups_by_enum_correctly(db):
    food = create_category(db, name="Food", user_id=None, type=TransactionType.EXPENSE)
    salary = create_category(db, name="Salary", user_id=None, type=TransactionType.INCOME)

    create_transaction(
        db, user_id=1, amount=100, transaction_date=date(2026, 8, 5),
        category_id=food.id, type=TransactionType.EXPENSE,
    )
    create_transaction(
        db, user_id=1, amount=500, transaction_date=date(2026, 8, 5),
        category_id=salary.id, type=TransactionType.INCOME,
    )

    result = get_summary(db, user_id=1)

    # This assertion is the actual point of the test: it fails loudly if
    # SQLAlchemy returns Transaction.type as a raw string instead of the
    # TransactionType enum member, which would silently zero out both
    # totals in get_summary's dict lookup.
    assert result["total_income"] == Decimal("500")
    assert result["total_expense"] == Decimal("100")
    assert result["net"] == Decimal("400")


def test_get_summary_with_no_transactions(db):
    result = get_summary(db, user_id=1)

    assert result["total_income"] == Decimal("0")
    assert result["total_expense"] == Decimal("0")
    assert result["net"] == Decimal("0")


def test_get_summary_respects_date_range(db):
    food = create_category(db, name="Food", user_id=None, type=TransactionType.EXPENSE)

    create_transaction(
        db, user_id=1, amount=50, transaction_date=date(2026, 7, 15),
        category_id=food.id, type=TransactionType.EXPENSE,
    )
    create_transaction(
        db, user_id=1, amount=75, transaction_date=date(2026, 8, 15),
        category_id=food.id, type=TransactionType.EXPENSE,
    )

    result = get_summary(db, user_id=1, start_date=date(2026, 8, 1), end_date=date(2026, 8, 31))

    assert result["total_expense"] == Decimal("75")


def test_get_summary_ignores_other_users(db):
    food = create_category(db, name="Food", user_id=None, type=TransactionType.EXPENSE)

    create_transaction(
        db, user_id=2, amount=999, transaction_date=date(2026, 8, 5),
        category_id=food.id, type=TransactionType.EXPENSE,
    )

    result = get_summary(db, user_id=1)

    assert result["total_expense"] == Decimal("0")


def test_get_by_category_includes_zero_categories(db):
    """Left join must surface a category with no transactions in range —
    this is what makes future budget-vs-actual coverage possible."""
    food = create_category(db, name="Food", user_id=None, type=TransactionType.EXPENSE)
    unused = create_category(db, name="Travel", user_id=None, type=TransactionType.EXPENSE)

    create_transaction(
        db, user_id=1, amount=40, transaction_date=date(2026, 8, 5),
        category_id=food.id, type=TransactionType.EXPENSE,
    )

    result = get_by_category(db, user_id=1)
    totals = {row["category_name"]: row["total"] for row in result}

    assert totals["Food"] == Decimal("40")
    assert totals["Travel"] == Decimal("0")


def test_get_trend_buckets_by_month(db):
    food = create_category(db, name="Food", user_id=None, type=TransactionType.EXPENSE)

    create_transaction(
        db, user_id=1, amount=100, transaction_date=date(2026, 7, 10),
        category_id=food.id, type=TransactionType.EXPENSE,
    )
    create_transaction(
        db, user_id=1, amount=200, transaction_date=date(2026, 8, 10),
        category_id=food.id, type=TransactionType.EXPENSE,
    )

    result = get_trend(db, user_id=1)
    by_month = {b["month"]: b for b in result}

    assert by_month["2026-07"]["expense"] == Decimal("100")
    assert by_month["2026-08"]["expense"] == Decimal("200")
    
def test_get_summary_includes_transfer_savings_debt(db):
    transfer_cat = create_category(db, name="Checking to Savings", user_id=None, type=TransactionType.TRANSFER)
    savings_cat = create_category(db, name="Emergency Fund", user_id=None, type=TransactionType.SAVINGS)
    debt_cat = create_category(db, name="Credit Card", user_id=None, type=TransactionType.DEBT)

    create_transaction(db, user_id=1, amount=300, transaction_date=date(2026, 8, 5), category_id=transfer_cat.id, type=TransactionType.TRANSFER)
    create_transaction(db, user_id=1, amount=150, transaction_date=date(2026, 8, 5), category_id=savings_cat.id, type=TransactionType.SAVINGS)
    create_transaction(db, user_id=1, amount=80, transaction_date=date(2026, 8, 5), category_id=debt_cat.id, type=TransactionType.DEBT)

    result = get_summary(db, user_id=1)

    assert result["total_transfer"] == Decimal("300")
    assert result["total_savings"] == Decimal("150")
    assert result["total_debt"] == Decimal("80")
    # net stays income/expense only — transfer/savings/debt don't leak in
    assert result["net"] == Decimal("0")