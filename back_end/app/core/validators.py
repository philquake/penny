from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.categories import Category
from app.models.transactions import TransactionType

#  is called from every route that accepts a category_id.

def ensure_usable_category(
    db: Session,
    category_id: int,
    user_id: int,
    expected_type: TransactionType,
) -> Category:
    """Return the category if the user may use it for `expected_type`.

    A category is usable if it is a global default (user_id is None) or
    belongs to this user. Anything else is reported as not found.
    """
    category = db.scalar(
        select(Category).where(
            Category.id == category_id,
            or_(Category.user_id.is_(None), Category.user_id == user_id),
        )
    )
    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found",
        )

    if category.type != expected_type:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                f"Category '{category.name}' is an {category.type.value} "
                f"category and cannot be used for {expected_type.value}"
            ),
        )

    return category