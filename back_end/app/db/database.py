from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.config import settings

#Penny's configuration and its database
# SQLite normally restricts a database connection to the thread that created it.
# FastAPI can operate across different threads when handling requests.
# This option allows SQLAlchemy's SQLite connection to work appropriately with FastAPI's request handling. - "check_same_thread": False
engine = create_engine(
    settings.database_url,
    connect_args={"check_same_thread": False},
    )

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

class Base(DeclarativeBase):
    pass

def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()