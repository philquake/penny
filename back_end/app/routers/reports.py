from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.deps import get_current_user
from app.crud import reports
from app.models import User
from app.schemas import ReportSummary, CategoryBreakdownItem, TrendBucket

router = APIRouter(
    prefix="/reports",
    tags=["Reports"],
)


@router.get("/summary", response_model=ReportSummary)
def summary(
    start_date: date | None = None,
    end_date: date | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return reports.get_summary(
        db=db,
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
    )


@router.get("/by-category", response_model=list[CategoryBreakdownItem])
def by_category(
    start_date: date | None = None,
    end_date: date | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return reports.get_by_category(
        db=db,
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
    )


@router.get("/trend", response_model=list[TrendBucket])
def trend(
    start_date: date | None = None,
    end_date: date | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return reports.get_trend(
        db=db,
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
    )