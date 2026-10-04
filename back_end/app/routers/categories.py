from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.deps import get_current_user
from app.models import User
from app.schemas import CategoryCreate, CategoryOut
from app.crud.categories import (
    create_category,
    get_category,
    get_categories,
    delete_category,
    get_category_usage,
)


router = APIRouter(
    prefix="/categories",
    tags=["Categories"],
)


@router.get("", response_model=list[CategoryOut])
def get_all_categories(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_categories(
        db=db,
        user_id=current_user.id,
    )


@router.post("",response_model=CategoryOut,status_code=status.HTTP_201_CREATED,)
def create_new_category(
    category_data: CategoryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_category(
        db=db,
        name=category_data.name,
        user_id=current_user.id,
        type=category_data.type,
    )


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_category(
    category_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    category = get_category(
        db=db,
        category_id=category_id,
        user_id=current_user.id,
    )

    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Category not found",
        )

    # get_category also returns the global defaults (user_id is None),
    # which are shared by everyone and must not be deletable.
    if category.user_id is None or category.is_default:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Default categories cannot be deleted",
        )

    transaction_count, budget_count = get_category_usage(db, category.id)

    if transaction_count or budget_count:
        parts = []
        if transaction_count:
            parts.append(f"{transaction_count} transaction(s)")
        if budget_count:
            parts.append(f"{budget_count} budget(s)")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Category is in use by {' and '.join(parts)}. ""Move or delete them first.",
        )

    delete_category(db=db, category=category)
    