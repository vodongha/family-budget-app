# Family Budget — Mobile App

[![CI](https://github.com/vodongha/family-budget-app/actions/workflows/ci.yml/badge.svg)](https://github.com/vodongha/family-budget-app/actions/workflows/ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)](https://flutter.dev)

The Flutter client for **[family-budget](https://github.com/vodongha/family-budget)** — a
multi-member household expense tracker. This app talks to the FastAPI + Oracle ADB backend
over its REST API: sign in, see the family dashboard, add income/expense, and browse
transactions.

> Backend lives in a separate repo: **vodongha/family-budget**. This repo is the mobile
> frontend only.

## Features

| Area | What it does |
|---|---|
| **Auth** | Sign in (OAuth2 password → JWT), or register a new family (you become its **owner**). Token stored in the OS secure store, auto-resumed on launch. |
| **Dashboard** | Net balance, total income/expense, and per-wallet derived balances. Pull to refresh. |
| **Add transaction** | Expense/income toggle, amount in đồng, wallet picker (create a wallet inline), note, date. |
| **Transactions** | Recent list, newest first, signed amounts (income +, expense −). |

## Money rule

Amounts are **integer đồng** everywhere — the API sends and receives whole-number minor
units, and the app only ever *formats* them (`lib/src/core/money.dart`). Money is never a
`double`; direction comes from the transaction **type**, not the sign. Wallet balances are
**derived** on the backend, never stored client-side.

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter (Material 3) |
| State | Riverpod (`AsyncNotifier`) |
| HTTP | Dio (one configured client + bearer-token interceptor) |
| Routing | go_router (auth-aware redirect guard) |
| Secure storage | flutter_secure_storage (Keychain / Keystore) |
| Formatting | intl |

## Architecture

A layered slice per feature, mirroring the backend's `router → service → repository`:

```
presentation (widgets)  →  application (Riverpod controllers)  →  data (repositories)  →  Dio  →  backend
```

```
lib/
├── main.dart                      # ProviderScope + app
└── src/
    ├── app.dart                   # MaterialApp.router
    ├── core/                      # config, Dio client, token storage, router, theme, money
    └── features/
        ├── auth/                  # login, register, session (AuthController)
        ├── dashboard/             # summary cards + wallet list
        ├── wallets/               # wallet model + repo + controller
        └── transactions/          # add + list
```

Each feature is split `domain/` (models), `data/` (repository + Dio), `application/`
(Riverpod controller), `presentation/` (screens).

## Quick start

> **Flutter SDK is required.** This repo was scaffolded by hand, so the native platform
> folders (`android/`, `ios/`, `web/`, …) are not committed. Generate them once:

```bash
# 1. From the repo root, generate the missing platform scaffolding
#    (this keeps lib/, pubspec.yaml and test/ intact).
flutter create .

# 2. Install dependencies
flutter pub get

# 3. Run — point API_BASE_URL at your backend.
#    Android emulator → host localhost is 10.0.2.2; iOS sim / web → localhost.
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Make sure the **backend is running** first (see the family-budget repo). The app shows a
clear "Cannot reach the server" message if it isn't.

## Tests

Pure unit tests (no device, no backend) cover the money rule and transaction parsing:

```bash
flutter test
flutter analyze
dart format .
```

## CI

`.github/workflows/ci.yml` runs `dart format` check + `flutter analyze` + `flutter test`
on pushes and PRs to `master`. No device or backend secrets needed.

## Docs

Full docs live in the [Wiki](https://github.com/vodongha/family-budget-app/wiki):
Architecture · State & Data Flow · API Integration · Running the App · Testing · Git
Workflow.

---

History note: this repo was renamed from `eShopSolution` (an old .NET sample). The git
history is intentionally kept; the content was replaced.
