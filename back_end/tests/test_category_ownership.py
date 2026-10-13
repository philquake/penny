import pytest
from fastapi.testclient import TestClient

from app.core.deps import get_current_user
from app.crud.categories import create_category
from app.crud.users import create_user
from app.db.database import get_db
from app.main import app
from app.models.transactions import TransactionType


@pytest.fixture
def users(db):
    owner = create_user(db, email="owner@example.com",
                        hashed_password="x", full_name="Owner")
    other = create_user(db, email="other@example.com",
                        hashed_password="x", full_name="Other")
    return owner, other


@pytest.fixture
def client_for(db):
    """Return a factory that builds a TestClient acting as `user`."""
    def _make(user):
        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = lambda: user
        return TestClient(app)  # no context manager: skips lifespan seeding

    yield _make
    app.dependency_overrides.clear()


@pytest.fixture
def categories(db, users):
    owner, other = users
    return {
        "food": create_category(db, name="Food", user_id=None,
                                type=TransactionType.EXPENSE),
        "pay": create_category(db, name="Pay", user_id=None,
                               type=TransactionType.INCOME),
        "mine": create_category(db, name="Mine", user_id=owner.id,
                                type=TransactionType.EXPENSE),
        "theirs": create_category(db, name="Theirs", user_id=other.id,
                                  type=TransactionType.EXPENSE),
    }


def _txn(category_id, type_="expense", **extra):
    body = {
        "category_id": category_id,
        "amount": 10,
        "type": type_,
        "transaction_date": "2026-08-28",
    }
    body.update(extra)
    return body


def _budget(category_id):
    return {
        "category_id": category_id,
        "amount": 100,
        "period": "monthly",
        "period_start": "2026-08-01",
        "alert_threshold_percent": 80,
    }


# --- transactions: create --------------------------------------------------

def test_create_transaction_with_global_category_succeeds(users, categories, client_for):
    client = client_for(users[0])
    r = client.post("/transactions", json=_txn(categories["food"].id))
    assert r.status_code == 201


def test_create_transaction_with_own_category_succeeds(users, categories, client_for):
    client = client_for(users[0])
    r = client.post("/transactions", json=_txn(categories["mine"].id))
    assert r.status_code == 201


def test_create_transaction_with_another_users_category_is_404(users, categories, client_for):
    client = client_for(users[0])
    r = client.post("/transactions", json=_txn(categories["theirs"].id))
    assert r.status_code == 404


def test_create_transaction_with_mismatched_type_is_422(users, categories, client_for):
    client = client_for(users[0])
    # Income category used on an expense transaction.
    r = client.post("/transactions", json=_txn(categories["pay"].id, "expense"))
    assert r.status_code == 422


# --- transactions: update --------------------------------------------------

def _create_expense(client, category_id):
    r = client.post("/transactions", json=_txn(category_id))
    assert r.status_code == 201
    return r.json()["id"]


def test_update_type_alone_is_checked_against_existing_category(users, categories, client_for):
    client = client_for(users[0])
    tid = _create_expense(client, categories["food"].id)

    # Only the type changes; the stored category is still an expense category.
    r = client.put(f"/transactions/{tid}", json={"type": "income"})
    assert r.status_code == 422


def test_update_category_to_another_users_is_404(users, categories, client_for):
    client = client_for(users[0])
    tid = _create_expense(client, categories["food"].id)

    r = client.put(f"/transactions/{tid}",
                   json={"category_id": categories["theirs"].id})
    assert r.status_code == 404


def test_update_with_valid_category_and_type_succeeds(users, categories, client_for):
    client = client_for(users[0])
    tid = _create_expense(client, categories["food"].id)

    r = client.put(f"/transactions/{tid}",
                   json={"category_id": categories["mine"].id})
    assert r.status_code == 200


def test_update_rejects_explicit_null_category(users, categories, client_for):
    client = client_for(users[0])
    tid = _create_expense(client, categories["food"].id)

    r = client.put(f"/transactions/{tid}", json={"category_id": None})
    assert r.status_code == 422


# --- budgets ---------------------------------------------------------------

def test_create_budget_with_another_users_category_is_404(users, categories, client_for):
    client = client_for(users[0])
    r = client.post("/budgets", json=_budget(categories["theirs"].id))
    assert r.status_code == 404


def test_create_budget_with_income_category_is_422(users, categories, client_for):
    client = client_for(users[0])
    r = client.post("/budgets", json=_budget(categories["pay"].id))
    assert r.status_code == 422


def test_create_budget_with_own_expense_category_succeeds(users, categories, client_for):
    client = client_for(users[0])
    r = client.post("/budgets", json=_budget(categories["mine"].id))
    assert r.status_code == 201


def test_update_budget_to_income_category_is_422(users, categories, client_for):
    client = client_for(users[0])
    bid = client.post("/budgets", json=_budget(categories["food"].id)).json()["id"]

    r = client.put(f"/budgets/{bid}", json={"category_id": categories["pay"].id})
    assert r.status_code == 422