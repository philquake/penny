from app.crud.users import get_user_by_email, create_user
from app.models.users import User


def test_get_user_by_email(db):

        user = User(
            email="test@example.com",
            hashed_password="fake-password",
            full_name = "PC",
        )

        db.add(user)
        db.commit()
        db.refresh(user)

        result = get_user_by_email(
            db,
            "test@example.com",
        )

        assert result is not None
        assert result.email == "test@example.com"
        assert result.id == user.id


        
def test_create_user(db):
    email = "new@example.com"
    hashed_password = "hashed-password"
    full_name = "PC"

    result = create_user(
        db,
        email=email,
        hashed_password=hashed_password,
        full_name = full_name
    )

    assert result.id is not None
    assert result.email == email
    assert result.hashed_password == hashed_password


def test_create_user_is_persisted(db):
    created = create_user(
    db,
    email="persisted@example.com",
    hashed_password="hashed-password",
    full_name = "PC",
    )

    result = get_user_by_email(
        db,
        "persisted@example.com",
    )

    assert result is not None
    assert result.id == created.id