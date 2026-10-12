from datetime import date
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.crud import debts as crud
from app.db.database import get_db
from app.models import User
from app.models.debts import DebtKind
from app.schemas import (
    DebtCreate, DebtEntryCreate, DebtEntryOut, DebtOut, DebtUpdate,
    PayoffResult, PlanResult,
)
from app.services.debt_math import amortize, payoff_plan

router = APIRouter(prefix="/debts", tags=["Debts"])


def _load(db: Session, user: User, debt_id: int):
    debt = crud.get_debt(db, debt_id, user.id)
    if not debt:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Debt not found")
    crud.accrue_interest(db, debt)  # bring interest up to date before any read/write
    return debt


def _check_card_fields(kind: DebtKind, credit_limit):
    if kind == DebtKind.LOAN and credit_limit is not None:
        raise HTTPException(422, "credit_limit only applies to credit cards")


@router.post("", response_model=DebtOut, status_code=status.HTTP_201_CREATED)
def create_new_debt(data: DebtCreate, db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):
    _check_card_fields(data.kind, data.credit_limit)
    debt = crud.create_debt(db, user_id=current_user.id, **data.model_dump())
    crud.accrue_interest(db, debt)
    return crud.summarize(db, debt)


@router.get("", response_model=list[DebtOut])
def get_all_debts(db: Session = Depends(get_db),
            current_user: User = Depends(get_current_user)):
    result = []
    for debt in crud.list_debts(db, current_user.id):
        crud.accrue_interest(db, debt)
        result.append(crud.summarize(db, debt))
    return result


# Declared before /{debt_id} routes so "payoff-plan" isn't parsed as an id.
@router.get("/payoff-plan", response_model=PlanResult)
def get_payoff_plan(
    extra: Decimal = Decimal("0"),
    strategy: Literal["avalanche", "snowball"] = "avalanche",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if extra < 0:
        raise HTTPException(422, "extra must be >= 0")
    rows = []
    for debt in crud.list_debts(db, current_user.id):
        if not debt.is_active:
            continue
        crud.accrue_interest(db, debt)
        s = crud.summarize(db, debt)
        rows.append({"id": s["id"], "name": s["name"], "balance": s["balance"],
                    "apr": s["apr"], "minimum_payment": s["minimum_payment"]})
    return payoff_plan(rows, extra, strategy, start=date.today())


@router.get("/{debt_id}", response_model=DebtOut)
def get_single_debt(debt_id: int, db: Session = Depends(get_db),
                    current_user: User = Depends(get_current_user)):
    return crud.summarize(db, _load(db, current_user, debt_id))


@router.put("/{debt_id}", response_model=DebtOut)
def update_existing_debt(debt_id: int, data: DebtUpdate, db: Session = Depends(get_db),
                        current_user: User = Depends(get_current_user)):
    debt = _load(db, current_user, debt_id)
    fields = data.model_dump(exclude_unset=True)
    for required in ("name", "apr", "minimum_payment", "is_active"):
        if required in fields and fields[required] is None:
            raise HTTPException(422, f"{required} cannot be null")
    _check_card_fields(debt.kind, fields.get("credit_limit"))
    return crud.summarize(db, crud.update_debt(db, debt, **fields))


@router.delete("/{debt_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_debt(debt_id: int, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    crud.delete_debt(db, _load(db, current_user, debt_id))


@router.get("/{debt_id}/entries", response_model=list[DebtEntryOut])
def get_entries(debt_id: int, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    return crud.list_entries(db, _load(db, current_user, debt_id).id)


@router.post("/{debt_id}/entries", response_model=DebtEntryOut,
            status_code=status.HTTP_201_CREATED)
def create_entry(debt_id: int, data: DebtEntryCreate, db: Session = Depends(get_db),
            current_user: User = Depends(get_current_user)):
    debt = _load(db, current_user, debt_id)
    return crud.add_entry(db, debt, **data.model_dump())


@router.delete("/{debt_id}/entries/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_entry(debt_id: int, entry_id: int, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    debt = _load(db, current_user, debt_id)
    entry = crud.get_entry(db, debt.id, entry_id)
    if not entry:
        raise HTTPException(404, "Entry not found")
    if entry.transaction_id is not None:
        raise HTTPException(409, "This payment comes from a transaction. Edit or delete that transaction instead.")
    crud.delete_entry(db, entry)


@router.get("/{debt_id}/payoff", response_model=PayoffResult)
def get_payoff(debt_id: int, monthly_payment: Decimal | None = None,
               db: Session = Depends(get_db),
               current_user: User = Depends(get_current_user)):
    debt = _load(db, current_user, debt_id)
    payment = monthly_payment if monthly_payment is not None else debt.minimum_payment
    if payment <= 0:
        raise HTTPException(422, "Provide a monthly_payment greater than 0")
    return amortize(crud.get_balance(db, debt), debt.apr, payment, start=date.today())