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
from app.models.transactions import TransactionType
from app.models.budgets import BudgetPeriod

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
        alert_threshold_percent=50,
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

    assert result["budget_amount"] == 500
    assert result["spent"] == 300
    assert result["remaining"] == 200
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

    assert result["spent"] == 500
    assert result["remaining"] == 0
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

    assert result["spent"] == 600
    assert result["remaining"] == -100
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

    assert result["spent"] == 0
    assert result["remaining"] == 500
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

        assert result["spent"] == 100
        assert result["remaining"] == 400
        
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

    assert result["spent"] == 100