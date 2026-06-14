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
| **Auth** | Sign in (OAuth2 password → JWT) or **Sign in with Google**, or register a new family (you become its **owner**). Optional **phone number** with a country-code picker on sign-up. Token stored in the OS secure store, auto-resumed on launch. |
| **Dashboard** | Net balance, total income/expense, per-wallet derived balances, and a swipeable **hub** of feature shortcuts (paged, with page dots). Pull to refresh. |
| **Add / edit / delete transaction** | Expense/income toggle, amount in đồng, wallet picker (create a wallet inline), category, note, date. Tap a transaction to edit or delete it — in a family, only the **creator** can edit/delete their own entries. |
| **Transactions** | Recent list, newest first, signed amounts (income +, expense −). A **filter** sheet narrows by type, category and date range. In family scope each row shows **which member created it** (avatar + name). |
| **Categories** | Family-scoped income/expense categories (emoji + colour) for tagging transactions. |
| **Budgets** | Per-category **monthly limit** with a progress bar and over-budget warning. |
| **Transfer** | Move money between two wallets (recorded as linked transfer legs; excluded from income/expense totals). |
| **Calendar** | Month grid showing each day's net amount; tap a day for its income/expense totals and transactions. |
| **Personal vs family** | A scope toggle (**Personal** on the left, **Family** on the right) switches the dashboard, transactions, statistics and calendar between the user's private wallets and the shared family wallets. |
| **Statistics** | Charts (`fl_chart`): monthly income/expense bars (1M/3M/6M/12M, **default 1 month**), income-vs-expense donut, balance-by-wallet bars, and a by-category donut. A scope toggle shows **personal** and **family** statistics separately. |
| **Members & invites** | A **Members** screen lists the family; an owner can **transfer ownership** to another member. Owners invite by email or phone: if the contact already has an account the invite arrives **in-app** (an **Invitations** inbox to accept/decline — no link); otherwise a shareable registration link is shown. |
| **Account menu** | Tap the avatar → a focused sheet: edit profile (incl. phone), settings, sign out, **delete account** (Google Play policy — soft-delete + 30-day purge on the backend). Feature navigation lives in the dashboard hub. |
| **Settings** | **Light / dark / system** theme and language, both persisted. Default follows the system. |
| **Localization** | English & Tiếng Việt. Follows the device language by default; selectable in Settings and persisted. |
| **Modern UI** | Material 3 with a tonal indigo palette, gradient balance hero, rounded cards, filled inputs — light & dark. |

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
| Localization | flutter_localizations + ARB (`lib/l10n`, generated `AppLocalizations`) |
| Preferences | shared_preferences (language + theme) |
| Auth | google_sign_in (web: Google Identity Services) |
| Phone input | phone_form_field (country-code picker + E.164) |
| Charts | fl_chart |
| Misc | package_info_plus (version), url_launcher (publisher link) |
| Formatting | intl |

## Architecture

A layered slice per feature, mirroring the backend's `router → service → repository`:

```
presentation (widgets)  →  application (Riverpod controllers)  →  data (repositories)  →  Dio  →  backend
```

```
lib/
├── main.dart                      # loads prefs, ProviderScope + app
├── l10n/                          # app_en.arb, app_vi.arb (generated AppLocalizations, gitignored)
└── src/
    ├── app.dart                   # MaterialApp.router + localization + locale
    ├── core/                      # config, Dio client, token storage, prefs/locale, router, theme, money
    └── features/
        ├── auth/                  # login, register, session, profile (edit name / language / delete)
        ├── dashboard/             # summary cards + wallet list
        ├── wallets/               # wallet model + repo + controller
        └── transactions/          # add + list
```

### Localization

Strings live in `lib/l10n/app_en.arb` (template) and `app_vi.arb`. `flutter gen-l10n`
generates `AppLocalizations` into `lib/l10n/` (gitignored — regenerated on build / in CI).
The active locale is held by `LocaleController` (persisted via `shared_preferences`); `null`
means "follow the device". Add a string by editing both ARB files, then `flutter gen-l10n`.

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

## License

[MIT](LICENSE)

---

## Built with

[Claude Code](https://claude.ai/code) by Anthropic. 🤖
