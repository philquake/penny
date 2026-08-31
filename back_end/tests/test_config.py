from app.core.config import settings


def test_settings_load():
    assert settings.database_url == "sqlite:///./penny.db"
    assert settings.algorithm == "HS256"
    assert settings.access_token_expire_minutes == 30


def test_secret_key_exists():
    assert settings.secret_key
    assert len(settings.secret_key) >= 32