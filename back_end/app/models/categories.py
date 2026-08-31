from sqlalchemy import select

from sqlalchemy import (
    Boolean,
    Enum as SQLEnum,
    ForeignKey,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.models.transactions import TransactionType

class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)

    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"),
        nullable=True,
    )

    name: Mapped[str] = mapped_column(String(100))

    type: Mapped[TransactionType] = mapped_column(
        SQLEnum(TransactionType),
    )

    icon: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )

    is_default: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )

