from datetime import date

from app.crud.categories import create_category
from app.crud.transactions import (
    create_transaction,
    delete_transaction,
    get_transaction,
    list_transactions,
    update_transaction,
)
from app.models.transactions import TransactionType

def test_create_transaction(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    result = create_transaction(
        db,
        user_id=1,
        amount=50,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
        description="Lunch",
    )

    assert result.id is not None
    assert result.user_id == 1
    assert result.category_id == category.id
    assert result.amount == 50
    assert result.transaction_date == date(2026, 8, 28)
    assert result.type == TransactionType.EXPENSE
    assert result.description == "Lunch"
        
def test_get_transaction(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    transaction = create_transaction(
        db,
        user_id=1,
        amount=50,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
        description="Lunch",
    )

    result = get_transaction(
        db,
        transaction_id=transaction.id,
        user_id=1,
    )

    assert result is not None
    assert result.id == transaction.id
    
def test_get_transaction_of_another_user(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    transaction = create_transaction(
        db,
        user_id=1,
        amount=50,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
        description="Lunch",
    )

    result = get_transaction(
        db,
        transaction_id=transaction.id,
        user_id=2,
    )

    assert result is None
    
def test_get_nonexistent_transaction(db):
    result = get_transaction(
        db,
        transaction_id=99999,
        user_id=1,
    )

    assert result is None
    
def test_list_transactions(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    create_transaction(
        db,
        user_id=1,
        amount=25,
        transaction_date=date(2026, 8, 27),
        category_id=category.id,
        type=TransactionType.EXPENSE,
    )

    create_transaction(
        db,
        user_id=1,
        amount=50,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
    )

    create_transaction(
        db,
        user_id=2,
        amount=100,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
    )

    result = list_transactions(
        db,
        user_id=1,
    )

    assert len(result) == 2
    assert all(
        transaction.user_id == 1
        for transaction in result
    )
    
def test_list_transactions_by_category(db):
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

    create_transaction(
        db,
        user_id=1,
        amount=25,
        transaction_date=date(2026, 8, 28),
        category_id=food.id,
        type=TransactionType.EXPENSE,
    )

    create_transaction(
        db,
        user_id=1,
        amount=40,
        transaction_date=date(2026, 8, 28),
        category_id=transport.id,
        type=TransactionType.EXPENSE,
    )

    result = list_transactions(
        db,
        user_id=1,
        category_id=food.id,
    )

    assert len(result) == 1
    assert result[0].category_id == food.id
    
def test_list_transactions_by_start_date(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    create_transaction(
        db,
        user_id=1,
        amount=25,
        transaction_date=date(2026, 8, 20),
        category_id=category.id,
        type=TransactionType.EXPENSE,
    )

    create_transaction(
        db,
        user_id=1,
        amount=50,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
    )

    result = list_transactions(
        db,
        user_id=1,
        start_date=date(2026, 8, 25),
    )

    assert len(result) == 1
    assert result[0].amount == 50
    
def test_list_transactions_by_end_date(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    create_transaction(
        db,
        user_id=1,
        amount=25,
        transaction_date=date(2026, 8, 20),
        category_id=category.id,
        type=TransactionType.EXPENSE,
    )

    create_transaction(
        db,
        user_id=1,
        amount=50,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
    )

    result = list_transactions(
        db,
        user_id=1,
        end_date=date(2026, 8, 25),
    )

    assert len(result) == 1
    assert result[0].amount == 25
    
def test_update_transaction(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    transaction = create_transaction(
        db,
        user_id=1,
        amount=50,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
        description="Lunch",
    )

    result = update_transaction(
        db,
        transaction,
        amount=75,
        description="Dinner",
    )

    assert result.amount == 75
    assert result.description == "Dinner"
    assert result.user_id == 1
    assert result.category_id == category.id
    
def test_update_transaction_keeps_other_fields(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    transaction = create_transaction(
        db,
        user_id=1,
        amount=50,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
        description="Lunch",
    )

    update_transaction(
        db,
        transaction,
        amount=75,
    )

    assert transaction.amount == 75
    assert transaction.description == "Lunch"
    assert transaction.category_id == category.id
    assert transaction.user_id == 1
    
def test_delete_transaction(db):
    category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    transaction = create_transaction(
        db,
        user_id=1,
        amount=50,
        transaction_date=date(2026, 8, 28),
        category_id=category.id,
        type=TransactionType.EXPENSE,
    )

    delete_transaction(
        db,
        transaction,
    )

    result = get_transaction(
        db,
        transaction_id=transaction.id,
        user_id=1,
    )

    assert result is None