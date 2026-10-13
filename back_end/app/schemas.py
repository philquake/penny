from datetime import date, datetime
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.models.budgets import BudgetPeriod
from app.models.transactions import TransactionType
from app.models.debts import DebtKind, EntryType


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
    
HexColor = Annotated[str, StringConstraints(pattern=r"^#[0-9A-Fa-f]{6}$")]
class CategoryCreate(BaseModel):
    name: str
    type: TransactionType
    icon: str | None = None
    color: HexColor | None = None

class CategoryUpdate(BaseModel):
    name: str | None = None
    icon: str | None = None
    color: HexColor | None = None

class CategoryOut(BaseModel):
    id: int
    user_id: int | None
    name: str
    type: TransactionType
    icon: str | None
    color: str | None
    is_default: bool

    model_config = ConfigDict(from_attributes=True)
    
class TransactionCreate(BaseModel):
    category_id: int
    amount: Decimal = Field(gt=0)
    type: TransactionType
    description: str | None = None
    transaction_date: date
    debt_id: int | None = None
    
class TransactionUpdate(BaseModel):
    category_id: int | None = None
    amount: Decimal | None = Field(default=None, gt=0)
    type: TransactionType | None = None
    description: str | None = None
    transaction_date: date | None = None
    debt_id: int | None = None
    
class TransactionOut(BaseModel):
    id: int
    user_id: int
    category_id: int
    amount: Decimal
    type: TransactionType
    description: str | None
    transaction_date: date
    created_at: datetime
    debt_id: int | None = None

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
    spent_amount: Decimal
    remaining_amount: Decimal
    percentage_used: Decimal
    status: str
    threshold_crossed: bool
    
class BudgetUpdate(BaseModel):
    category_id: int | None = None
    amount: Decimal | None = Field(default=None, gt=0)
    period: BudgetPeriod | None = None
    period_start: date | None = None
    period_end: date | None = None
    alert_threshold_percent: int | None = Field(default=None, ge=0, le=100)

class ReportSummary(BaseModel):
    total_income: Decimal
    total_expense: Decimal
    net: Decimal  #income - expense only
    total_transfer: Decimal
    total_savings: Decimal   # gain: money moved into savings this period
    total_debt: Decimal      # loss: new debt taken on this period

class CategoryBreakdownItem(BaseModel):
    category_id: int
    category_name: str
    total: Decimal

class TrendBucket(BaseModel):
    month: str  # "2026-08"
    income: Decimal
    expense: Decimal
    
    
class DebtCreate(BaseModel):
    name: str
    kind: DebtKind
    opening_balance: Decimal = Field(ge=0)
    apr: Decimal = Field(ge=0, le=100)
    minimum_payment: Decimal = Field(default=Decimal("0"), ge=0)
    credit_limit: Decimal | None = Field(default=None, gt=0)
    due_day: int | None = Field(default=None, ge=1, le=31)
    start_date: date


class DebtUpdate(BaseModel):
    name: str | None = None
    apr: Decimal | None = Field(default=None, ge=0, le=100)
    minimum_payment: Decimal | None = Field(default=None, ge=0)
    credit_limit: Decimal | None = Field(default=None, gt=0)
    due_day: int | None = Field(default=None, ge=1, le=31)
    is_active: bool | None = None


class DebtOut(BaseModel):
    id: int
    name: str
    kind: DebtKind
    opening_balance: Decimal
    balance: Decimal
    apr: Decimal
    minimum_payment: Decimal
    credit_limit: Decimal | None
    utilization_percent: Decimal | None
    due_day: int | None
    next_due_date: date | None
    monthly_interest_estimate: Decimal
    start_date: date
    is_active: bool


class DebtEntryCreate(BaseModel):
    type: EntryType
    amount: Decimal = Field(gt=0)
    entry_date: date
    note: str | None = None


class DebtEntryOut(BaseModel):
    id: int
    debt_id: int
    type: EntryType
    amount: Decimal
    entry_date: date
    note: str | None
    model_config = ConfigDict(from_attributes=True)

class PayoffRow(BaseModel):
    month: int
    payment: Decimal
    interest: Decimal
    principal: Decimal
    balance: Decimal


class PayoffResult(BaseModel):
    payable: bool
    months: int | None
    total_interest: Decimal
    total_paid: Decimal
    payoff_date: date | None
    schedule: list[PayoffRow]


class PlanStep(BaseModel):
    debt_id: int
    name: str
    month: int


class PlanResult(BaseModel):
    strategy: str
    payable: bool
    months: int | None
    total_interest: Decimal | None
    payoff_date: date | None
    payoff_order: list[PlanStep]