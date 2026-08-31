from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from app.main import app
from app.db.database import Base, get_db

TEST_DB = Path(__file__).parent / "test_smoke.db"
if TEST_DB.exists():
    TEST_DB.unlink()

test_engine = create_engine(
    f"sqlite:///{TEST_DB}",
    connect_args={"check_same_thread": False},
)
TestSessionLocal = sessionmaker(bind=test_engine, autocommit=False, autoflush=False)

def override_get_db():
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db
Base.metadata.create_all(bind=test_engine)


def test_smoke_workflow():

    with TestClient(app) as client:

        # --------------------------------------------------
        # 1. Health check
        # --------------------------------------------------

        response = client.get("/health")

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

        # --------------------------------------------------
        # 2. Signup
        # --------------------------------------------------

        user = {
            "email": "smoke@example.com",
            "password": "SmokeTest123!",
            "full_name": "Phillip Cole",
        }

        response = client.post("/auth/signup", json=user)
        print(response.status_code, response.json())
        assert response.status_code == 201
        
        created_user = response.json()

        assert created_user["email"] == user["email"]

        # Duplicate signup must fail
        response = client.post("/auth/signup", json=user)

        assert response.status_code == 400

        # --------------------------------------------------
        # 3. Login -> JWT
        # --------------------------------------------------

        response = client.post(
            "/auth/login",
            data={
                "username": user["email"],
                "password": user["password"],
            },
        )

        assert response.status_code == 200

        token_data = response.json()

        assert "access_token" in token_data
        assert token_data["token_type"] == "bearer"

        token = token_data["access_token"]

        headers = {
            "Authorization": f"Bearer {token}"
        }

        # --------------------------------------------------
        # 4. Default categories
        # --------------------------------------------------

        response = client.get(
            "/categories",
            headers=headers,
        )

        assert response.status_code == 200

        categories = response.json()

        assert len(categories) > 0

        category_names = {
            category["name"]
            for category in categories
        }

        assert "Food" in category_names

        # Find a category to use for the transaction
        food_category = next(
            category
            for category in categories
            if category["name"] == "Food"
        )

        # --------------------------------------------------
        # 5. Create transaction -> list it
        # --------------------------------------------------

        transaction = {
            "amount": 50.00,
            "transaction_date": "2026-08-29",
            "category_id": food_category["id"],
            "description": "Smoke test grocery purchase",
        }

        response = client.post(
            "/transactions",
            json=transaction,
            headers=headers,
        )

        assert response.status_code == 201

        created_transaction = response.json()

        assert created_transaction["amount"] == 50.00
        assert created_transaction["category_id"] == food_category["id"]

        # List transactions
        response = client.get(
            "/transactions",
            headers=headers,
        )

        assert response.status_code == 200

        transactions = response.json()

        assert len(transactions) == 1
        assert transactions[0]["amount"] == 50.00

        # --------------------------------------------------
        # 6. Negative amount must be rejected
        # --------------------------------------------------

        negative_transaction = {
            "amount": -25.00,
            "transaction_date": "2026-08-29",
            "category_id": food_category["id"],
            "description": "Invalid transaction",
        }

        response = client.post(
            "/transactions",
            json=negative_transaction,
            headers=headers,
        )

        assert response.status_code == 422

        # --------------------------------------------------
        # 7. Budget -> status reflects real spending
        # --------------------------------------------------

        budget = {
            "category_id": food_category["id"],
            "amount": 100.00,
            "start_date": "2026-08-01",
            "end_date": "2026-08-31",
            "threshold": 50.00,
        }

        response = client.post(
            "/budgets",
            json=budget,
            headers=headers,
        )

        assert response.status_code == 201

        created_budget = response.json()

        budget_id = created_budget["id"]

        # Check budget status
        response = client.get(
            f"/budgets/{budget_id}/status",
            headers=headers,
        )
        
        assert response.status_code == 200

        budget_status = response.json()

        # The transaction created above was $50.
        # The budget threshold is 50%, so the threshold
        # should be flagged.
        assert budget_status["spent"] == 50.00
        assert budget_status["percentage_used"] == 50.00
        assert budget_status["threshold_reached"] is True

        # --------------------------------------------------
        # 8. Unauthenticated request -> 401
        # --------------------------------------------------

        response = client.get("/transactions")

        assert response.status_code == 401

