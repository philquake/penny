from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.transactions import Transaction, TransactionType


def create_transaction(
    db: Session,
    user_id: int,
    amount: float,
    transaction_date: date,
    category_id: int,
    type: TransactionType,
    description: str | None = None,
) -> Transaction:
    
    transaction = Transaction(
        user_id=user_id,
        amount=amount,
        transaction_date=transaction_date,
        category_id=category_id,
        type=type,
        description=description,
    )

    db.add(transaction)
    db.commit()
    db.refresh(transaction)

    return transaction

def get_transaction(
    db: Session,
    transaction_id: int,
    user_id: int,
) -> Transaction | None:
    
    statement = select(Transaction).where(
        Transaction.id == transaction_id,
        Transaction.user_id == user_id,
    )
    #scalar so it returns None instaed of execute If nothing matches, result itself is not None. It's a Result object containing zero rows.
    return db.scalar(statement)

def list_transactions(
    db: Session,
    user_id: int,
    start_date: date | None = None,
    end_date: date | None = None,
    category_id: int | None = None,
) -> list[Transaction]:

    statement = select(Transaction).where(
        Transaction.user_id == user_id
    )

    if start_date is not None:
        statement = statement.where(
            Transaction.transaction_date >= start_date
        )

    if end_date is not None:
        statement = statement.where(
            Transaction.transaction_date <= end_date
        )

    if category_id is not None:
        statement = statement.where(
            Transaction.category_id == category_id
        )

    statement = statement.order_by(
        Transaction.transaction_date.desc()
    )

    return list(db.scalars(statement).all())

def update_transaction(
    db: Session,
    transaction: Transaction,
    amount: float | None = None,
    transaction_date: date | None = None,
    category_id: int | None = None,
    description: str | None = None,
) -> Transaction:

    if amount is not None:
        transaction.amount = amount

    if transaction_date is not None:
        transaction.transaction_date = transaction_date

    if category_id is not None:
        transaction.category_id = category_id

    if description is not None:
        transaction.description = description

    db.commit()
    db.refresh(transaction)

    return transaction

def delete_transaction(
    db: Session,
    transaction: Transaction,
) -> None:
    db.delete(transaction)
    db.commit()