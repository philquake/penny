from datetime import date
from decimal import Decimal

from app.crud.debts import accrue_interest, create_debt, get_balance
from app.models.debts import DebtKind
from app.services.debt_math import amortize, payoff_plan
from app.crud.categories import create_category
from app.crud.debts import sync_payment_entry
from app.crud.transactions import create_transaction
from app.models.transactions import TransactionType


def test_linked_payment_follows_transaction(db):
    debt = create_debt(
        db, user_id=1, name="Visa", kind=DebtKind.CREDIT_CARD,
        opening_balance=Decimal("1000"), apr=Decimal("0"),
        minimum_payment=Decimal("25"), credit_limit=None,
        due_day=None, start_date=date(2026, 8, 1),
    )
    cat = create_category(db, name="Debt Payment", user_id=None, type=TransactionType.EXPENSE)
    tx = create_transaction(
        db, user_id=1, amount=Decimal("200"), transaction_date=date(2026, 8, 10),
        category_id=cat.id, type=TransactionType.EXPENSE, debt_id=debt.id,
    )
    sync_payment_entry(db, tx)
    assert get_balance(db, debt) == Decimal("800")

    tx.amount = Decimal("300")
    db.commit()
    sync_payment_entry(db, tx)
    assert get_balance(db, debt) == Decimal("700")

    tx.debt_id = None
    db.commit()
    sync_payment_entry(db, tx)
    assert get_balance(db, debt) == Decimal("1000")

def test_amortize_matches_known_loan():
    # $10,000 @ 12% APR, $888.49/mo is the standard 12-month schedule
    r = amortize(Decimal("10000"), Decimal("12"), Decimal("888.49"))
    assert r["payable"] and r["months"] == 12
    assert abs(r["total_interest"] - Decimal("661.88")) < Decimal("1.00")


def test_amortize_flags_payment_below_interest():
    r = amortize(Decimal("10000"), Decimal("24"), Decimal("100"))  # interest is $200/mo
    assert r["payable"] is False and r["months"] is None


def test_avalanche_beats_snowball_on_interest():
    debts = [
        {"id": 1, "name": "Card", "balance": "2000", "apr": "25", "minimum_payment": "50"},
        {"id": 2, "name": "Loan", "balance": "1000", "apr": "5", "minimum_payment": "40"},
    ]
    a = payoff_plan(debts, Decimal("100"), "avalanche")
    s = payoff_plan(debts, Decimal("100"), "snowball")
    assert a["total_interest"] <= s["total_interest"]
    assert a["payoff_order"][0]["debt_id"] == 1


def test_accrual_posts_interest_once_per_month_and_is_idempotent(db):
    debt = create_debt(
        db, user_id=1, name="Visa", kind=DebtKind.CREDIT_CARD,
        opening_balance=Decimal("1000"), apr=Decimal("24"),
        minimum_payment=Decimal("25"), credit_limit=Decimal("5000"),
        due_day=15, start_date=date(2026, 8, 1),
    )
    accrue_interest(db, debt, today=date(2026, 9, 2))
    first = get_balance(db, debt)
    assert Decimal("1019") < first < Decimal("1021")  # ~31 days at 24% APR

    accrue_interest(db, debt, today=date(2026, 9, 2))
    assert get_balance(db, debt) == first