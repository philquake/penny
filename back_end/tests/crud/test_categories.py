from app.crud.categories import (
    create_category,
    delete_category,
    get_category,
    list_categories,
    seed_default_categories,
    DEFAULT_CATEGORIES
    )
from app.models.transactions import TransactionType


def test_create_category(db):
    result = create_category(
        db,
        name="Grocercies",
        user_id=12,
        type=TransactionType.EXPENSE,
    )

    assert result.id is not None
    assert result.name == "Grocercies"
    assert result.user_id == 12
    assert result.type == TransactionType.EXPENSE

def test_get_category_of_current_user(db):
        category = create_category(
                db,
                name="Groceries",
                user_id=12,
                type=TransactionType.EXPENSE,
            )
        
        result = get_category(
            db,
            category_id = category.id,
            user_id = 12,
        )
        
        assert result is not None
        assert result.id == category.id
        assert result.user_id == 12
        assert result.name == "Groceries"
        assert result.type == TransactionType.EXPENSE
        
def test_get_category_of_another_user(db):
    category = create_category(
            db,
            name="Private",
            user_id=12,
            type=TransactionType.EXPENSE,
        )
    
    result = get_category(
        db,
        category_id = category.id,
        user_id = 13,
    )
    
    assert result is None
        
    
def test_list_categories(db):
    global_category = create_category(
        db,
        name="Food",
        user_id=None,
        type=TransactionType.EXPENSE,
    )

    user_category = create_category(
        db,
        name="My Gym",
        user_id=1,
        type=TransactionType.EXPENSE,
    )

    other_category = create_category(
        db,
        name="Other User",
        user_id=2,
        type=TransactionType.EXPENSE,
    )

    result = list_categories(
        db,
        user_id=1,
    )

    result_ids = {category.id for category in result}

    assert global_category.id in result_ids
    assert user_category.id in result_ids
    assert other_category.id not in result_ids

def test_get_category_that_does_not_exist(db):
    category = create_category(
            db,
            name="test",
            user_id=12,
            type=TransactionType.EXPENSE,
        )
    
    result = get_category(
        db,
        category_id = "test",
        user_id = 12,
    )
    
    assert result is None
        
def test_get_global_category(db):

    category = create_category(
            db,
            name=DEFAULT_CATEGORIES[1],
            user_id=None,
            type=TransactionType.EXPENSE,
        )
    
    result = get_category(
        db,
        category_id = category.id,
        user_id = 12,
    )
    
    assert result is not None
        
def test_get_nonexistent_category(db):
    result = get_category(
        db,
        category_id=99999,
        user_id=1,
    )

    assert result is None
    
def test_seed_default_categories(db):
    seed_default_categories(db)

    result = list_categories(
        db,
        user_id=1,
    )

    names = {category.name for category in result}

    for name in DEFAULT_CATEGORIES:
        assert name in names
        
def test_seed_default_categories_is_idempotent(db):
    seed_default_categories(db)
    seed_default_categories(db)

    result = list_categories(
        db,
        user_id=1,
    )

    default_categories = [
        category
        for category in result
        if category.user_id is None
        and category.name in DEFAULT_CATEGORIES
    ]

    assert len(default_categories) == len(DEFAULT_CATEGORIES)

def test_delete_category(db):
    category = create_category(
        db,
        name="Delete Me",
        user_id=1,
        type=TransactionType.EXPENSE,
    )

    delete_category(
        db,
        category,
    )

    result = get_category(
        db,
        category_id=category.id,
        user_id=1,
    )

    assert result is None