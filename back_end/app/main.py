from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.crud.categories import seed_default_categories
from app.db import database
from app.db.database import Base, engine
from app.routers import auth, budgets, categories, reports, transactions


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