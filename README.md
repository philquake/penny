# Penny

Penny is a personal finance and budgeting application. It combines a Flutter
client with a FastAPI backend for authentication, transaction tracking,
categories, budgets, and financial reports.

## Features

- Email and password authentication with bcrypt password hashing and JWTs
- Dashboard with an overview of spending and budget status
- Create, edit, and delete income and expense transactions
- Default and user-managed transaction categories
- Budget tracking by expense category
- Reports and spending summaries
- Cupertino-style Flutter interface with separate tabs for Home, Transactions,
  Budgets, Reports, and Settings

## Project Structure

```text
Penny/
├── back_end/              # FastAPI application and backend tests
│   ├── app/
│   │   ├── core/          # Configuration, dependencies, and security
│   │   ├── crud/          # Database operations
│   │   ├── db/            # SQLAlchemy engine and sessions
│   │   ├── models/        # SQLAlchemy models
│   │   └── routers/       # HTTP API routes
│   └── tests/
└── front_end/             # Flutter application
	├── lib/api/            # API clients
	├── lib/models/         # Dart data models
	├── lib/providers/      # Riverpod state providers
	├── lib/screens/        # Application screens
	└── lib/widgets/        # Shared widgets
```

## Requirements

- Python 3.10 or newer
- Flutter SDK compatible with Dart `3.13.1`
- A supported Flutter target such as Chrome, Android, iOS, macOS, Linux, or
  Windows

## Backend Setup

From the repository root:

```powershell
cd back_end
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Create `back_end/.env` with the required settings:

```dotenv
PENNY_DATABASE_URL=sqlite:///./penny.db
PENNY_SECRET_KEY=replace-with-a-long-random-secret
PENNY_ALGORITHM=HS256
PENNY_ACCESS_TOKEN_EXPIRE_MINUTES=30
```

Start the development API server from `back_end`:

```powershell
uvicorn app.main:app --reload
```

The API is available at `http://localhost:8000`. Interactive OpenAPI
documentation is available at `http://localhost:8000/docs`, and the health
check is available at `http://localhost:8000/health`.

The application creates its database tables and seeds default categories when
the API starts. SQLite is the current database configuration used by the
application.

## Frontend Setup

With the backend running, open a second terminal:

```powershell
cd front_end
flutter pub get
flutter run
```

The API base URL is selected automatically by `front_end/lib/core/api_config.dart`:

- Web, Windows, macOS, and Linux: `http://localhost:8000`
- Android emulator: `http://10.0.2.2:8000`

For a physical device, update the API configuration to use the development
machine's local network address and ensure the device can reach port `8000`.

## Tests

Run the backend test suite from `back_end`:

```powershell
pytest
```

Run Flutter tests from `front_end`:

```powershell
flutter test
```

Static analysis can be run with:

```powershell
flutter analyze
```

## API Overview

The backend provides REST routes for:

- Authentication and user accounts
- Categories
- Transactions
- Budgets
- Reports

Authenticated routes expect a bearer token returned by the login flow. Use the
Swagger UI at `/docs` for the complete request and response schemas.

## Architecture

```text
Flutter UI
	↓
FastAPI routers
	↓
Pydantic schemas and authentication dependencies
	↓
CRUD operations
	↓
SQLAlchemy models and database
```

The Flutter app uses Riverpod for state management, Dio/HTTP for API access,
secure storage for the authentication token, and `fl_chart` for visual reports.
