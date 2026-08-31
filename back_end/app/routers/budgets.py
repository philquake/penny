from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.deps import get_current_user
from app.crud.budgets import (
    create_budget,
    get_budget,
    compute_budget_status,
    delete_budget,
)
from app.models import User
from app.schemas import BudgetCreate, BudgetOut, BudgetStatus

router = APIRouter(
    prefix="/budgets",
    tags=["Budgets"],
)


@router.post(
    "/",
    response_model=BudgetOut,
    status_code=status.HTTP_201_CREATED,
)
def create_new_budget(
    budget_data: BudgetCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_budget(
        db=db,
        user_id=current_user.id,
        **budget_data.model_dump(),
    )


@router.get("/", response_model=list[BudgetOut])
def get_all_budgets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_budget(
        db=db,
        user_id=current_user.id,
    )


@router.get("/{budget_id}/status", response_model=BudgetStatus)
def get_budget_alert_status(
    budget_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = compute_budget_status(
        db=db,
        budget_id=budget_id,
        user_id=current_user.id,
    )

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )

    return result


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_budget(
    budget_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    deleted = delete_budget(
        db=db,
        budget_id=budget_id,
        user_id=current_user.id,
    )

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )