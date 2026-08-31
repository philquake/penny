from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.deps import get_current_user
from app.crud.transactions import (
    create_transaction,
    get_transaction,
    list_transactions,
    update_transaction,
    delete_transaction,
)
from app.models import User
from app.schemas import (
    TransactionCreate,
    TransactionOut,
    TransactionUpdate,
)

router = APIRouter(
    prefix="/transactions",
    tags=["Transactions"],
)


@router.post(
    "/",
    response_model=TransactionOut,
    status_code=status.HTTP_201_CREATED,
)
def create_new_transaction(
    transaction_data: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_transaction(
        db=db,
        user_id=current_user.id,
        amount=transaction_data.amount,
        transaction_date=transaction_data.transaction_date,
        category_id=transaction_data.category_id,
        description=transaction_data.description,
        type = transaction_data.type,
    )


@router.get("/", response_model=list[TransactionOut])
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
        db=db,
        transaction_id=transaction_id,
        user_id=current_user.id,
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
    transaction = update_transaction(
        db=db,
        transaction_id=transaction_id,
        user_id=current_user.id,
        **transaction_data.model_dump(exclude_unset=True),
    )

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    return transaction


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    deleted = delete_transaction(
        db=db,
        transaction_id=transaction_id,
        user_id=current_user.id,
    )

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )