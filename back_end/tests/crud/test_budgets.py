from datetime import date

from app.crud.budgets import (
    compute_budget_status,
    create_budget,
    delete_budget,
    get_budget,
    list_budgets,
)
from app.crud.categories import create_category
from app.crud.transactions import create_transaction
from app.models.budgets import BudgetPeriod
from app.models.transactions import TransactionType


def test_create_budget(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    result = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=80,
    )

    assert result.id is not None
    assert result.user_id == 1
    assert result.category_id == category.id
    assert result.amount == 500
    assert result.period_start == date(2026, 8, 1)
    assert result.period_end == date(2026, 8, 31)

def test_create_custom_period_budget(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    result = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.CUSTOM,
        period_start=date(2026, 8, 12),
        period_end=date(2026, 9, 6),
        alert_threshold_percent=80,
    )

    assert result.period == BudgetPeriod.CUSTOM
    assert result.period_start == date(2026, 8, 12)
    assert result.period_end == date(2026, 9, 6)
    
def test_get_budget(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,        
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=80,
    )

    result = get_budget(
        db,
        budget_id=budget.id,
        user_id=1,
    )

    assert result is not None
    assert result.id == budget.id

    
def test_get_budget_of_another_user(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=80,
    )

    result = get_budget(
        db,
        budget_id=budget.id,
        user_id=2,
    )

    assert result is None
    
def test_list_budgets(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.WEEKLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=50,
    )

    create_budget(
        db,
        user_id=2,
        category_id=category.id,
        amount=1000,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=30,
    )

    result = list_budgets(
        db,
        user_id=1,
    )

    assert len(result) == 1
    assert result[0].user_id == 1
    
def test_delete_budget(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=39,
    )

    delete_budget(
        db,
        budget,
    )

    result = get_budget(
        db,
        budget_id=budget.id,
        user_id=1,
    )

    assert result is None
    
def test_compute_budget_status_under_budget(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=80,
    )

    create_transaction(
        db,
        user_id=1,
        amount=300,
        transaction_date=date(2026, 8, 15),
        category_id=category.id,
        type=TransactionType.EXPENSE
    )

    result = compute_budget_status(
        db,
        budget,
    )

    assert result["percentage_used"] == 60
    assert result["spent_amount"] == 300
    assert result["remaining_amount"] == 200
    assert result["threshold_crossed"] is False

def test_compute_budget_status_counts_expenses_only(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=80,
    )

    create_transaction(
        db,
        user_id=1,
        amount=450,
        transaction_date=date(2026, 8, 15),
        category_id=category.id,
        type=TransactionType.INCOME,
    )

    result = compute_budget_status(db, budget)

    assert result["spent_amount"] == 0
    assert result["threshold_crossed"] is False

def test_zero_alert_threshold_is_disabled(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=0,
    )

    result = compute_budget_status(db, budget)

    assert result["threshold_crossed"] is False
    
def test_compute_budget_status_at_budget(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=40,
    )

    create_transaction(
        db,
        user_id=1,
        amount=500,
        transaction_date=date(2026, 8, 15),
        category_id=category.id,
        type=TransactionType.EXPENSE,
    )

    result = compute_budget_status(
        db,
        budget,
    )

    assert result["spent_amount"] == 500
    assert result["remaining_amount"] == 0
    assert result["threshold_crossed"] is True
    
def test_compute_budget_status_over_budget(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=80,
    )

    create_transaction(
        db,
        user_id=1,
        amount=600,
        transaction_date=date(2026, 8, 15),
        category_id=category.id,
        type=TransactionType.EXPENSE
    )

    result = compute_budget_status(
        db,
        budget,
    )

    assert result["spent_amount"] == 600
    assert result["remaining_amount"] == -100
    assert result["threshold_crossed"] is True
    
def test_compute_budget_status_with_no_transactions(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.WEEKLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=80,
    )

    result = compute_budget_status(
        db,
        budget,
    )

    assert result["spent_amount"] == 0
    assert result["remaining_amount"] == 500
    assert result["threshold_crossed"] is False
    
def test_compute_budget_status_ignores_transactions_outside_date_range(db):
        category = create_category(
            db,
            name="Food",
            user_id=None,
            type=TransactionType.EXPENSE,
        )

        budget = create_budget(
            db,
            user_id=1,
            category_id=category.id,
            amount=500,
            period=BudgetPeriod.MONTHLY,
            period_start=date(2026, 8, 1),
            period_end=date(2026, 8, 31),
            alert_threshold_percent=80,
        )

        # Inside budget period
        create_transaction(
            db,
            user_id=1,
            amount=100,
            transaction_date=date(2026, 8, 15),
            category_id=category.id,
            type=TransactionType.EXPENSE
        )

        # Before budget
        create_transaction(
            db,
            user_id=1,
            amount=200,
            transaction_date=date(2026, 7, 31),
            category_id=category.id,
            type=TransactionType.EXPENSE
        )

        # After budget
        create_transaction(
            db,
            user_id=1,
            amount=300,
            transaction_date=date(2026, 9, 1),
            category_id=category.id,
            type=TransactionType.EXPENSE
        )

        result = compute_budget_status(
            db,
            budget,
        )

        assert result["spent_amount"] == 100
        assert result["remaining_amount"] == 400
        
def test_compute_budget_status_ignores_other_categories(db):
    food = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    transport = create_category(
        db,
        name="Transport",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=food.id,
        amount=500,
        period=BudgetPeriod.WEEKLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=80,
    )

    create_transaction(
        db,
        user_id=1,
        amount=100,
        transaction_date=date(2026, 8, 15),
        category_id=food.id,
        type=TransactionType.EXPENSE,
    )

    create_transaction(
        db,
        user_id=1,
        amount=300,
        transaction_date=date(2026, 8, 15),
        category_id=transport.id,
        type=TransactionType.EXPENSE,
    )

    result = compute_budget_status(
        db,
        budget,
    )

    assert result["spent_amount"] == 100
    
AS_OF = date(2026, 8, 15)
def test_monthly_budget_rolls_to_current_window(db):
    category = create_category(
        db, name="Food", user_id=None, type=TransactionType.EXPENSE
    )

    # Anchored in August, with the stale end date the PUT endpoint leaves behind.
    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.MONTHLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        alert_threshold_percent=80,
    )

    create_transaction(
        db, user_id=1, amount=100, transaction_date=date(2026, 8, 15),
        category_id=category.id, type=TransactionType.EXPENSE,
    )
    create_transaction(
        db, user_id=1, amount=40, transaction_date=date(2026, 10, 5),
        category_id=category.id, type=TransactionType.EXPENSE,
    )

    result = compute_budget_status(db, budget, as_of=date(2026, 10, 9))

    # Only October counts, not August through now.
    assert result["spent_amount"] == 40
    assert result["remaining_amount"] == 460


def test_weekly_budget_rolls_forward(db):
    category = create_category(
        db, name="Food", user_id=None, type=TransactionType.EXPENSE
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=100,
        period=BudgetPeriod.WEEKLY,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 7),
        alert_threshold_percent=80,
    )

    # Aug 1 + 10 weeks = Oct 10, so Oct 9 is still in the Oct 3 to Oct 9 week.
    create_transaction(
        db, user_id=1, amount=30, transaction_date=date(2026, 10, 4),
        category_id=category.id, type=TransactionType.EXPENSE,
    )
    create_transaction(
        db, user_id=1, amount=70, transaction_date=date(2026, 10, 2),
        category_id=category.id, type=TransactionType.EXPENSE,
    )

    result = compute_budget_status(db, budget, as_of=date(2026, 10, 9))

    assert result["spent_amount"] == 30


def test_custom_budget_does_not_roll(db):
    category = create_category(
        db, name="Food", user_id=None, type=TransactionType.EXPENSE
    )

    budget = create_budget(
        db,
        user_id=1,
        category_id=category.id,
        amount=500,
        period=BudgetPeriod.CUSTOM,
        period_start=date(2026, 8, 12),
        period_end=date(2026, 9, 6),
        alert_threshold_percent=80,
    )

    create_transaction(
        db, user_id=1, amount=80, transaction_date=date(2026, 8, 20),
        category_id=category.id, type=TransactionType.EXPENSE,
    )

    # Long after the window ended, it still reports on that fixed window.
    result = compute_budget_status(db, budget, as_of=date(2026, 10, 9))

    assert result["spent_amount"] == 80