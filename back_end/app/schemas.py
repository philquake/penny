from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.models.budgets import BudgetPeriod
from app.models.transactions import TransactionType

class UserCreate(BaseModel):
    email: str
    password: str
    full_name: str
    
class UserOut(BaseModel):
    id: int
    email: str
    full_name: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
    
class Token(BaseModel):
    access_token: str
    token_type: str
    
class CategoryCreate(BaseModel):
    name: str
    type: TransactionType
    icon: str | None = None
    is_default: bool = False
    
class CategoryOut(BaseModel):
    id: int
    user_id: int | None
    name: str
    type: TransactionType
    icon: str | None
    is_default: bool

    model_config = ConfigDict(from_attributes=True)
    
class TransactionCreate(BaseModel):
    category_id: int
    amount: Decimal = Field(gt=0)
    type: TransactionType
    description: str | None = None
    transaction_date: date
    
class TransactionUpdate(BaseModel):
    category_id: int | None = None
    amount: Decimal | None = Field(default=None, gt=0)
    type: TransactionType | None = None
    description: str | None = None
    transaction_date: date | None = None
    
class TransactionOut(BaseModel):
    id: int
    user_id: int
    category_id: int
    amount: Decimal
    type: TransactionType
    description: str | None
    transaction_date: date
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
    
class BudgetCreate(BaseModel):
    category_id: int
    amount: Decimal = Field(gt=0)
    period: BudgetPeriod
    period_start: date
    period_end: date
    alert_threshold_percent: int = Field(
        ge=0,
        le=100,
    )

class BudgetOut(BaseModel):
    id: int
    user_id: int
    category_id: int
    amount: Decimal
    period: BudgetPeriod
    period_start: date
    period_end: date
    alert_threshold_percent: int

    model_config = ConfigDict(from_attributes=True)
    
class BudgetStatus(BaseModel):
    budget_id: int
    budget_amount: Decimal
    spent_amount: Decimal
    remaining_amount: Decimal
    percentage_used: Decimal
    status: str