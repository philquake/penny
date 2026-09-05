from contextlib import asynccontextmanager

from back_end.app.routers import reports
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db.database import engine, Base
from app.crud.categories import seed_default_categories

from app.routers import transactions
from app.routers import auth, budgets, categories
from app.db import database


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create database tables
    database.Base.metadata.create_all(bind=database.engine)
    db = database.SessionLocal()
    
    # Seed default categories
    try:
        seed_default_categories(db)
    finally:
        db.close()

    yield


app = FastAPI(
    title="Penny API",
    description="Personal finance and budgeting API",
    version="1.0.0",
    lifespan=lifespan,
)


# --------------------------------------------------
# CORS
# --------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Local development only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --------------------------------------------------
# Routers
# --------------------------------------------------

app.include_router(auth.router)
app.include_router(categories.router)
app.include_router(transactions.router)
app.include_router(budgets.router)
app.include_router(reports.router)

# --------------------------------------------------
# Health check
# --------------------------------------------------

@app.get("/health")
def health_check():
    return {"status": "ok"}