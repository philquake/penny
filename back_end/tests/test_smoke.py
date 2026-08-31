import os
from pathlib import Path

# --------------------------------------------------
# Configure test database BEFORE importing the app
# --------------------------------------------------

TEST_DB = Path(__file__).parent / "test_smoke.db"

os.environ["DATABASE_URL"] = f"sqlite:///{TEST_DB}"

from fastapi.testclient import TestClient

from app.main import app


with TestClient(app) as client:


    def test_smoke_workflow():
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
        assert response.status_code == 201
        
        created_user = response.json()

        assert created_user["email"] == user["email"]

        # Duplicate signup must fail
        response = client.post("/auth/signup", json=user)

        assert response.status_code == 400
