from fastapi.testclient import TestClient

from app.core.deps import get_current_user
from app.db.database import get_db
from app.crud.users import create_user
from app.main import app


def test_post_category_persists_color_and_icon(db):
    user = create_user(
        db,
        email="color@example.com",
        hashed_password="not-used",
        full_name="Color Test",
    )
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user
    try:
        client = TestClient(app)  # no context manager: skips lifespan/seeding
        response = client.post(
            "/categories",
            json={
                "name": "Pet Care",
                "type": "expense",
                "icon": "bag",
                "color": "#2E9E7A",
            },
        )

        assert response.status_code == 201
        body = response.json()
        assert body["color"] == "#2E9E7A"
        assert body["icon"] == "bag"

        listed = client.get("/categories").json()
        created = next(c for c in listed if c["name"] == "Pet Care")
        assert created["color"] == "#2E9E7A"
    finally:
        app.dependency_overrides.clear()


def test_post_category_rejects_malformed_color(db):
    user = create_user(
        db,
        email="badcolor@example.com",
        hashed_password="not-used",
        full_name="Bad Color",
    )
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user
    try:
        client = TestClient(app)
        response = client.post(
            "/categories",
            json={"name": "X", "type": "expense", "color": "green"},
        )
        assert response.status_code == 422
    finally:
        app.dependency_overrides.clear()