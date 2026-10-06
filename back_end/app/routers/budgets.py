from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.crud.budgets import (
    compute_budget_status,
    create_budget,
    current_window,
    delete_budget,
    get_budget,
    list_budgets,
    update_budget,
)
from app.crud.categories import (
    get_category,
)
from app.db.database import get_db
from app.models import User
from app.models.budgets import BudgetPeriod
from app.models.transactions import TransactionType
from app.schemas import BudgetCreate, BudgetOut, BudgetStatus, BudgetUpdate

router = APIRouter(
    prefix="/budgets",
    tags=["Budgets"],
)


@router.post("",response_model=BudgetOut,status_code=status.HTTP_201_CREATED,)
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


@router.get("", response_model=list[BudgetOut])
def get_all_budgets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_budgets(
        db=db,
        user_id=current_user.id,
    )


@router.get("/{budget_id}/status", response_model=BudgetStatus)
def get_budget_alert_status(
    budget_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = get_budget(
        db=db,
        budget_id=budget_id,
        user_id=current_user.id,
    )

    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )

    return compute_budget_status(
        db=db,
        budget=budget,
    )


@router.delete("/{budget_id}",status_code=status.HTTP_204_NO_CONTENT,)
def remove_budget(
    budget_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = get_budget(
        db=db,
        budget_id=budget_id,
        user_id=current_user.id,
    )

    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )

    delete_budget(
        db=db,
        budget=budget,
    )
    
def _validate_category(db, user, category_id):
    cat = get_category(db, category_id=category_id, user_id=user.id)
    if cat is None:
        raise HTTPException(404, "Category not found")
    if cat.type != TransactionType.EXPENSE:
        raise HTTPException(422, "Budgets can only target expense categories")

@router.put("/{budget_id}", response_model=BudgetOut)
def update_existing_budget(budget_id: int, data: BudgetUpdate,
                            db: Session = Depends(get_db),
                            current_user: User = Depends(get_current_user)):
    budget = get_budget(db, budget_id=budget_id, user_id=current_user.id)
    if not budget:
        raise HTTPException(404, "Budget not found")

    fields = data.model_dump(exclude_unset=True)
    for required in ("amount", "period", "period_start", "alert_threshold_percent", "category_id"):
        if required in fields and fields[required] is None:
            raise HTTPException(422, f"{required} cannot be null")

    if "category_id" in fields:
        _validate_category(db, current_user, fields["category_id"])

    start = fields.get("period_start", budget.period_start)
    end = fields.get("period_end", budget.period_end)
    period = fields.get("period", budget.period)
    if period == BudgetPeriod.CUSTOM and end < start:
        raise HTTPException(422, "period_end must be on or after period_start")

    updated = update_budget(db, budget, **fields)
    if updated.period != BudgetPeriod.CUSTOM:        # keep derived end consistent
        updated.period_end = current_window(updated)[1]
        db.commit(); db.refresh(updated)
    return updated