from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.core.validators import ensure_usable_category
from app.crud import debts as debts_crud
from app.crud.categories import is_debt_payment_category
from app.crud.transactions import (
    create_transaction,
    delete_transaction,
    get_transaction,
    list_transactions,
    update_transaction,
)
from app.db.database import get_db
from app.models import User
from app.models.transactions import TransactionType
from app.schemas import (
    TransactionCreate,
    TransactionOut,
    TransactionUpdate,
)

router = APIRouter(
    prefix="/transactions",
    tags=["Transactions"],
)


def _resolve_debt_id(db: Session, user: User, category_id: int,
                     tx_type: TransactionType, debt_id: int | None) -> int | None:
    """Only expense transactions in the Debt Payment category link to a debt.
    Anything else clears the link, which is how switching category unlinks it."""
    category = ensure_usable_category(db, category_id=category_id, user_id=user.id,  expected_type=tx_type)
    if category is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Category not found")

    if not (is_debt_payment_category(category) and tx_type == TransactionType.EXPENSE):
        return None

    if debt_id is None:
        raise HTTPException(422, "debt_id is required for debt payments")

    debt = debts_crud.get_debt(db, debt_id, user.id)
    if debt is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Debt not found")

    debts_crud.accrue_interest(db, debt) 
    return debt.id


@router.post("", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
def create_new_transaction(
    transaction_data: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    debt_id = _resolve_debt_id(
        db, current_user, transaction_data.category_id,
        transaction_data.type, transaction_data.debt_id,
    )
    transaction = create_transaction(
        db=db,
        user_id=current_user.id,
        amount=transaction_data.amount,
        transaction_date=transaction_data.transaction_date,
        category_id=transaction_data.category_id,
        description=transaction_data.description,
        type=transaction_data.type,
        debt_id=debt_id,
    )
    debts_crud.sync_payment_entry(db, transaction)
    return transaction


@router.get("", response_model=list[TransactionOut])
def get_all_transactions(
    category_id: int | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_transactions(
        db=db,
        user_id=current_user.id,
        category_id=category_id,
        start_date=start_date,
        end_date=end_date,
    )


@router.get("/{transaction_id}", response_model=TransactionOut)
def get_single_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    transaction = get_transaction(
        db=db, transaction_id=transaction_id, user_id=current_user.id,
    )
    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )
    return transaction


@router.put("/{transaction_id}", response_model=TransactionOut)
def update_existing_transaction(
    transaction_id: int,
    transaction_data: TransactionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    transaction = get_transaction(
        db=db, transaction_id=transaction_id, user_id=current_user.id
    )
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")

    fields = transaction_data.model_dump(exclude_unset=True)
    for required in ("category_id", "amount", "type", "transaction_date"):
        if required in fields and fields[required] is None:
            raise HTTPException(422, f"{required} cannot be null")
    requested_debt = fields.pop("debt_id", transaction.debt_id)

    # Validate against the values the transaction will have *after* the update.
    debt_id = _resolve_debt_id(
        db, current_user,
        fields.get("category_id", transaction.category_id),
        fields.get("type", transaction.type),
        requested_debt,
    )

    updated = update_transaction(db=db, transaction=transaction, **fields)
    updated.debt_id = debt_id
    db.commit()
    db.refresh(updated)

    debts_crud.sync_payment_entry(db, updated)
    return updated


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    transaction = get_transaction(
        db=db, transaction_id=transaction_id, user_id=current_user.id
    )
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")

    debts_crud.delete_payment_entry(db, transaction.id)
    delete_transaction(db=db, transaction=transaction)