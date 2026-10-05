from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.categories import Category
from app.models.transactions import TransactionType
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.budgets import Budget
from app.models.categories import Category
from app.models.transactions import Transaction, TransactionType

DEFAULT_CATEGORIES = [
    "Food",
    "Transportation",
    "Entertainment",
    "Bills",
    "Shopping",
    "Health",
    "Education",
    "Other",
]

# Seeded with TransactionType.INCOME instead of EXPENSE.
DEFAULT_INCOME_CATEGORIES = [
    "Income",
]

def list_categories(db: Session, user_id: int,) -> list[Category]:
    
    statement = (
        select(Category)
        .where(
            or_(
                Category.user_id.is_(None),
                Category.user_id == user_id,
            )
        )
        .order_by(Category.name)
    )

    return list(db.scalars(statement).all())

def create_category(
    db: Session,
    name: str,
    type: TransactionType,
    user_id: int | None = None,
    icon: str | None = None,
    is_default: bool = False,
) -> Category:

    category = Category(
        name=name,
        user_id=user_id,
        type=type,
        icon=icon,
        is_default=is_default,
    )

    db.add(category)
    db.commit()
    db.refresh(category)

    return category

def get_category(db: Session, category_id: int, user_id: int,) -> Category | None:
    """Fetch a single category by id, scoped to the user (or global defaults)."""
    statement = (
        select(Category)
        .where(
            Category.id == category_id,
            or_(
                Category.user_id.is_(None),
                Category.user_id == user_id,
            ),
        )
    )

    return db.scalar(statement)

def get_categories(db: Session, user_id: int,) -> list[Category]:
    """Fetch all categories visible to the user: their own + global defaults."""
    statement = select(Category).where(
        (Category.user_id == user_id) | (Category.user_id.is_(None))
    )
    return list(db.scalars(statement).all())

def get_category_usage(db: Session, category_id: int) -> tuple[int, int]:
    """Return (transaction_count, budget_count) referencing this category.

    Counts across all users on purpose: a user-owned category is only ever
    used by its owner, so this is equivalent, and it stays correct if that
    ever changes.
    """
    transaction_count = db.scalar(
        select(func.count())
        .select_from(Transaction)
        .where(Transaction.category_id == category_id)
    )
    budget_count = db.scalar(
        select(func.count())
        .select_from(Budget)
        .where(Budget.category_id == category_id)
    )
    return transaction_count or 0, budget_count or 0

def delete_category(
    db: Session,
    category: Category,
) -> None:
    
    db.delete(category)
    db.commit()
    
def seed_default_categories(db: Session) -> None:
    for name in DEFAULT_CATEGORIES:
        category = db.scalar(
            select(Category).where(Category.name == name, Category.user_id.is_(None))
        )
        if category is None:
            db.add(Category(name=name, user_id=None, type=TransactionType.EXPENSE, is_default=True))
        else:
            category.type = TransactionType.EXPENSE
            category.is_default = True

    for name in DEFAULT_INCOME_CATEGORIES:
        category = db.scalar(
            select(Category).where(Category.name == name, Category.user_id.is_(None))
        )
        if category is None:
            db.add(Category(name=name, user_id=None, type=TransactionType.INCOME, is_default=True))
        else:
            category.type = TransactionType.INCOME
            category.is_default = True

    db.commit()
    
def update_category(db: Session, category: Category, **fields) -> Category:
    for key, value in fields.items():
        setattr(category, key, value)
    db.commit()
    db.refresh(category)
    return category