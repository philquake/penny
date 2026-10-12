from datetime import date

import pytest

from app.crud.budgets import create_budget, resolve_period_end
from app.crud.categories import create_category
from app.models.budgets import BudgetPeriod
from app.models.transactions import TransactionType


def _food(db):
    return create_category(
        db, name="Food", user_id=None, type=TransactionType.EXPENSE
    )


def test_monthly_end_is_derived_on_create(db):
    food = _food(db)
    budget = create_budget(
        db,
        user_id=1,
        category_id=food.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 15),
        alert_threshold_percent=80,
    )
    assert budget.period_end == date(2026, 9, 14)


def test_client_supplied_end_is_ignored_for_rolling_periods(db):
    food = _food(db)
    budget = create_budget(
        db,
        user_id=1,
        category_id=food.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2030, 1, 1),  # nonsense; must be replaced
        alert_threshold_percent=80,
    )
    assert budget.period_end == date(2026, 8, 31)


def test_custom_requires_valid_range():
    with pytest.raises(ValueError):
        resolve_period_end(
            BudgetPeriod.CUSTOM, date(2026, 8, 10), date(2026, 8, 1)
        )


def test_monthly_window_with_clamped_anchor_day():
    from app.crud.budgets import _window

    # Anchored on Jan 31; February has no 31st, so the window clamps.
    start, end = _window(
        BudgetPeriod.MONTHLY, date(2026, 1, 31), date(2026, 2, 15)
    )
    assert start == date(2026, 1, 31)
    assert end == date(2026, 2, 27)