# Penny

Penny is a self-hosted personal finance app for a small trusted group (a household or a handful of users). It pairs a **Flutter** client with a **FastAPI + SQLite** backend that you run on your own hardware.

> Your ledger. Your server. No accounts, no cloud, no per-query costs.

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Backend Setup](#backend-setup)
- [Frontend Setup](#frontend-setup)
- [Connecting the App to Your Server](#connecting-the-app-to-your-server)
- [Core Concepts](#core-concepts)
- [API Overview](#api-overview)
- [Architecture](#architecture)
- [Testing](#testing)
- [Database Migrations](#database-migrations)
- [Security Notes](#security-notes)
- [Known Limitations and Roadmap](#known-limitations-and-roadmap)

---

## Features

**Accounts and security**
- Email/password authentication with bcrypt hashing and JWT bearer tokens
- Token stored on-device with `flutter_secure_storage`; automatic sign-out when a session expires (401 handling)
- Per-user data isolation on every route (transactions, budgets, debts, custom categories)

**Transactions**
- Create, edit, and delete transactions of type `income`, `expense`, or `savings` (the backend also supports `transfer` and `debt`)
- Search by description or category, filter by All / Income / Expenses, grouped by day with daily spend totals
- **Receipt scanning**: take or pick a photo and on-device OCR (Google ML Kit) fills in merchant, amount, and date
- Server-side validation that a category belongs to the user (or is a global default) and matches the transaction type

**Categories**
- Seeded defaults: Food, Transportation, Entertainment, Bills, Shopping, Health, Education, Other, Debt Payment (expense), Income, and Savings
- Custom categories with an icon and a color; defaults are read-only
- Deleting a category that is still used by transactions or budgets is blocked with a clear message

**Budgets**
- Per-category budgets with `weekly`, `monthly`, `yearly`, or `custom` periods
- Rolling windows: weekly/monthly/yearly budgets always report on the window containing today, anchored to the start date (handles short months, e.g. an anchor on the 31st)
- Status computed server-side: `normal`, `alert` (threshold crossed), or `exceeded`
- Configurable alert threshold (0 disables it) and optional **local notifications** when a threshold is crossed

**Debts**
- Track credit cards and loans with APR, minimum payment, credit limit, and due day
- Ledger-based balances: opening balance plus charges, payments, interest, and fees
- Automatic, idempotent interest accrual (daily rate = APR / 365 on the running balance, posted at each monthly boundary)
- Credit utilization with a 30% warning on cards
- Payoff calculator for a fixed monthly payment (flags payments that do not cover interest)
- Multi-debt payoff plans using **avalanche** (highest APR first) or **snowball** (smallest balance first)
- Logging a transaction in the **Debt Payment** category links it to a debt and keeps the ledger entry in sync (edit, re-link, or delete)

**Dashboard and reports**
- Overview with total balance, this month's income and spending, budget snapshot, recent activity, and a daily spending calendar
- Reports for This Month / 3 Months / This Year: income, expenses, net, spending by category (pie), cumulative spending vs. last month with budget line, and a 6-month income vs. expense chart

**App experience**
- Material 3 design with light and dark themes (saved preference)
- Configurable server address on the login screen (supports local network and Tailscale)

## Tech Stack

| Layer | Technology |
| --- | --- |
| Client | Flutter (Dart `^3.13.1`), Material 3 |
| State management | Riverpod (`StateNotifier` providers) |
| Networking | Dio with auth/401 interceptor |
| Charts | `fl_chart` |
| On-device | `flutter_secure_storage`, `shared_preferences`, `flutter_local_notifications`, `image_picker`, `google_mlkit_text_recognition` |
| API | FastAPI, Pydantic v2, pydantic-settings |
| Data | SQLAlchemy 2.0, SQLite, Alembic |
| Auth | python-jose (JWT, HS256), passlib + bcrypt |
| Tests | pytest, FastAPI `TestClient`, Flutter widget/unit tests |

## Project Structure

```text
Penny/
├── back_end/
│   ├── alembic/               # Migration environment and versions
│   ├── app/
│   │   ├── core/              # config, security (JWT/bcrypt), deps, validators
│   │   ├── crud/              # Database operations (users, categories, transactions,
│   │   │                      #   budgets, reports, debts)
│   │   ├── db/                # SQLAlchemy engine, session, Base
│   │   ├── models/            # ORM models
│   │   ├── routers/           # auth, categories, transactions, budgets, reports, debts
│   │   ├── services/          # debt_math.py (amortization and payoff plans)
│   │   ├── schemas.py         # Pydantic request/response models
│   │   └── main.py            # App, CORS, lifespan (table creation + seeding)
│   ├── tests/                 # pytest suite (crud/ plus API and smoke tests)
│   ├── alembic.ini
│   ├── pytest.ini
│   └── .env.example
└── front_end/
    ├── lib/
    │   ├── core/              # api client/config, server settings, token storage,
    │   │                      #   theme, shared widgets
    │   ├── data/              # Repositories wrapping the REST API
    │   ├── models/            # Dart data models
    │   ├── providers/         # Riverpod providers (session, data controllers)
    │   ├── screens/           # Login, dashboard, budgets, debts, reports, settings, ...
    │   ├── services/          # Receipt parser, budget notification service
    │   ├── widgets/           # Shared widgets (e.g. transaction row)
    │   └── main.dart          # App root, session routing, tabbed shell
    ├── test/                  # Widget and unit tests
    └── android/ ios/ macos/ linux/ windows/ web/
```

## Requirements

- Python 3.10 or newer
- Flutter SDK compatible with Dart `3.13.1`
- A Flutter target: Android, iOS, macOS, Windows, Linux, or Chrome
- Receipt scanning and local notifications are mobile features (Android/iOS)

## Backend Setup

From the repository root:

**Windows (PowerShell)**

```powershell
cd back_end
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

**macOS / Linux**

```bash
cd back_end
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Create `back_end/.env` (copy `.env.example`):

```dotenv
PENNY_DATABASE_URL=sqlite:///./penny.db
PENNY_SECRET_KEY=replace-with-a-long-random-secret
PENNY_ALGORITHM=HS256
PENNY_ACCESS_TOKEN_EXPIRE_MINUTES=30
```

| Variable | Description | Default |
| --- | --- | --- |
| `PENNY_DATABASE_URL` | SQLAlchemy URL (SQLite is the supported database) | required |
| `PENNY_SECRET_KEY` | JWT signing secret. Use at least 32 random characters | required |
| `PENNY_ALGORITHM` | JWT algorithm | `HS256` |
| `PENNY_ACCESS_TOKEN_EXPIRE_MINUTES` | Token lifetime in **integer minutes** (e.g. `43200` for 30 days) | `30` |

> The expiry value must be a plain integer. A value like `30 days` will fail to load.

Generate a secret:

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Start the API from `back_end`:

```bash
uvicorn app.main:app --reload
# To reach it from a phone or another machine:
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- API: `http://localhost:8000`
- Interactive docs (Swagger UI): `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

On startup the app creates any missing tables and seeds the default categories (idempotent).

### Creating users

The mobile app has a sign-in screen only (the username is the account email). Create accounts with the signup endpoint, for example from `/docs`:

```bash
curl -X POST http://localhost:8000/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"a-strong-password","full_name":"Your Name"}'
```

## Frontend Setup

With the backend running, in a second terminal:

```bash
cd front_end
flutter pub get
flutter run
```

## Connecting the App to Your Server

Tap **Server** on the login screen to set the address; it is remembered between launches.

| Scenario | Address to enter |
| --- | --- |
| Desktop / web on the same machine | `http://localhost:8000` (default) |
| Android emulator | `http://10.0.2.2:8000` (default) |
| Physical device on your LAN | `192.168.x.x:8000` |
| Tailscale (plain HTTP) | `100.x.x.x:8000` |
| Tailscale Serve / reverse proxy with TLS | `your-host.ts.net` (no port, HTTPS assumed) |

Address rules: an explicit port means plain HTTP; no port means HTTPS on 443. A full `http://` or `https://` URL is used as typed.

**Platform notes**

- **Android** blocks cleartext HTTP except to `10.0.2.2`. For a LAN/Tailscale IP over HTTP, either use HTTPS (recommended, e.g. `tailscale serve`) or add your host to `android/app/src/main/res/xml/network_security_config.xml` (a commented example is included; it matches exact hosts, not CIDR ranges).
- **iOS** allows local-network HTTP (`NSAllowsLocalNetworking`) and prompts for local network access.
- Notification permission is requested when you enable **Budget notifications** in Settings.

## Core Concepts

### Transaction types and categories

Each transaction has a type (`income`, `expense`, `transfer`, `savings`, `debt`), and its category must be of the same type. Categories are either global defaults (`user_id` is null) or owned by a user.

### Budget windows

Rolling budgets store the first period's dates, but status is calculated for the window that contains today:

- `weekly`: 7-day windows from the start date
- `monthly`: month windows from the start day (clamped for short months)
- `yearly`: 12-month windows
- `custom`: fixed range that never rolls

Only `expense` transactions in the budget's category count toward spending.

### Debt ledger

`balance = opening_balance + charges + interest + fees - payments`

Interest is posted automatically whenever debts are read or modified, once per completed month since the start date. A transaction in the default **Debt Payment** category requires a `debt_id` and creates a linked payment entry; those entries can only be changed by editing or deleting the transaction.

## API Overview

All routes except `/auth/signup`, `/auth/login`, and `/health` require `Authorization: Bearer <token>`. Full schemas are in Swagger UI at `/docs`.

| Area | Endpoints |
| --- | --- |
| Auth | `POST /auth/signup`, `POST /auth/login` (form-encoded `username`/`password`), `GET /auth/me` |
| Categories | `GET /categories`, `POST /categories`, `PUT /categories/{id}`, `DELETE /categories/{id}` |
| Transactions | `GET /transactions` (filters: `category_id`, `start_date`, `end_date`), `POST`, `GET/PUT/DELETE /transactions/{id}` |
| Budgets | `GET /budgets`, `POST /budgets`, `PUT/DELETE /budgets/{id}`, `GET /budgets/{id}/status` |
| Reports | `GET /reports/summary`, `GET /reports/by-category`, `GET /reports/trend` (all accept `start_date`, `end_date`) |
| Debts | `GET/POST /debts`, `GET/PUT/DELETE /debts/{id}`, `GET/POST /debts/{id}/entries`, `DELETE /debts/{id}/entries/{entry_id}`, `GET /debts/{id}/payoff?monthly_payment=`, `GET /debts/payoff-plan?extra=&strategy=avalanche\|snowball` |
| Health | `GET /health` |

## Architecture

```text
Flutter UI (screens)
        ↓
Riverpod providers / controllers
        ↓
Repositories (Dio + auth interceptor)
        ↓  HTTPS / HTTP
FastAPI routers
        ↓
Pydantic schemas + auth dependencies + validators
        ↓
CRUD layer  (+ services/debt_math for payoff calculations)
        ↓
SQLAlchemy models → SQLite
```

Notes on how the client is wired:

- Data providers watch the signed-in user id, so a different user always gets fresh state.
- Mutating a transaction also refreshes budgets and debts, since both derive from transactions.
- Budget status is computed by the server; the client only renders it.
- The Reports screen currently aggregates on the client from the transaction list; the `/reports/*` endpoints are available for when that moves server-side.

## Testing

**Backend** (from `back_end`):

```bash
pytest
```

Coverage includes CRUD operations for users, categories, transactions, budgets, and reports; budget window logic; category ownership and type validation through the API; debt math, linked payments, and interest accrual; configuration; and an end-to-end smoke test (signup, login, categories, transactions, budget status, 401 handling). Unit tests use an in-memory SQLite database.

> `tests/test_config.py` expects `PENNY_DATABASE_URL=sqlite:///./penny.db` and a secret key of at least 32 characters in your `.env`.

**Frontend** (from `front_end`):

```bash
flutter test
flutter analyze
```

Tests cover the login screen, dashboard (empty budget state, daily spending calendar), budgets empty state, and receipt text parsing.

## Database Migrations

Alembic is configured against `PENNY_DATABASE_URL` with SQLite-safe batch mode and an initial schema revision.

```bash
cd back_end
alembic upgrade head                              # apply migrations
alembic revision --autogenerate -m "describe change"   # after changing models
```

The API also calls `create_all` at startup, which creates missing tables but does not alter existing ones. For schema changes to an existing database, use Alembic.

## Security Notes

- Set a strong, unique `PENNY_SECRET_KEY` and keep `.env` out of version control.
- CORS is currently open (`allow_origins=["*"]`) for development. Restrict it before exposing the API beyond a trusted network.
- Prefer HTTPS (for example Tailscale Serve or a reverse proxy) when connecting from devices; plain HTTP is intended for trusted local or Tailscale networks.
- Signup is open on the API. If the server is reachable beyond people you trust, restrict or disable `/auth/signup`.

## Known Limitations and Roadmap

- **Coming soon** (shown as disabled in Settings): CSV export, CSV import, and an AI assistant for financial insights.
- The monthly trend report uses SQLite's `strftime`; switch to `date_trunc` when moving to Postgres.
- `transfer` and `debt` transaction types exist in the API but are not yet available in the transaction form.
- Reports are computed client-side from the full transaction list.
- Single-currency (`$`) display.

## License

Add a license of your choice before distributing.