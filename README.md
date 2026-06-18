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
| **Auth** | Register an **account** (then an onboarding step **creates or joins** a family), or sign in (OAuth2 password → JWT) / **Sign in with Google** (links to your existing account by email). **Set or change password** in Settings (a Google-only account can set its first password). Optional **phone number** with a country-code picker. Token stored in the OS secure store, auto-resumed on launch. |
| **Dashboard** | Net balance, total income/expense (tap **Income**/**Expense** to open the filtered transaction list), per-wallet derived balances (tap a wallet → its transactions), and a swipeable **hub** of feature shortcuts. Pull to refresh. |
| **Add / edit / delete transaction** | Expense/income toggle, amount in đồng, **scope-aware** wallet picker (only the wallets of the tab you're on — family or personal; create one inline), category, note, date. Tap a transaction to edit or delete it — in a family, only the **creator** can edit/delete their own entries. |
| **Transactions** | Recent list, newest first, signed amounts (income +, expense −). A **filter** sheet narrows by type, category and date range. In family scope each row shows **which member created it** (avatar + name). |
| **Wallets** | **Family** (shared) or **personal** (private) wallets, each with an optional **icon + colour**; create and **edit** (rename / icon / colour) from the dashboard. |
| **Categories** | Family-scoped income/expense categories (emoji + colour) for tagging transactions; **edit** name and icon. |
| **Budgets** | Per-category **monthly limit** with a progress bar and over-budget warning. |
| **Transfer** | Move money between two wallets (recorded as linked transfer legs; excluded from income/expense totals). |
| **Calendar** | Month grid showing each day's net amount; tap a day for its income/expense totals and transactions. |
| **Personal vs family** | A scope toggle (**Personal** / **Family**) switches the dashboard, transactions, statistics and calendar between private and shared wallets. The app opens on **Personal**, which works **without a family**; tapping **Family** (or a family-only feature) with no family prompts to create one. |
| **Family management** | From the account menu → **Manage family**: rename, leave, or (owner, sole member) delete the family (your personal data is kept). On **Members**, the owner can remove a member; anyone can leave. |
| **Statistics** | Charts (`fl_chart`): monthly income/expense bars (1M/3M/6M/12M, **default 1 month**), income-vs-expense donut, balance-by-wallet bars, and a by-category donut. A scope toggle shows **personal** and **family** statistics separately. |
| **Members & invites** | A **Members** screen lists the family; **any member can add a member** from a button there (the owner can also **transfer ownership**). Invite by email or phone: if the contact already has an account the invite arrives **in-app** (an **Invitations** inbox to accept/decline — no link); otherwise a shareable registration link is shown. |
| **Account menu** | Tap the avatar → a focused sheet: edit profile (incl. phone), settings, **privacy policy** (shown in-app via a WebView), sign out, **delete account** (Google Play policy — soft-delete + 30-day purge on the backend). Feature navigation lives in the dashboard hub. |
| **Currencies** | Each wallet keeps its own currency; pick a **primary (display) currency** in Settings and the cross-wallet **totals** (dashboard, statistics, budgets) convert to it via the live exchange rate, while per-wallet balances stay in their own currency. Settings shows when rates were last updated (they auto-refresh every 12h) with a **manual refresh** button. |
| **Settings** | **Light / dark / system** theme, language, and **primary currency**, all persisted. Default follows the system. |
| **Localization** | English & Tiếng Việt. Follows the device language by default; selectable in Settings and persisted. |
| **Modern UI** | Material 3 with a tonal indigo palette, gradient balance hero, rounded cards, filled inputs — light & dark. **Responsive**: on wide screens (web / tablet) content is width-capped and centred instead of stretching edge-to-edge. |

## Money rule

Amounts are **integer minor units** of each wallet's currency everywhere — the API sends and
receives whole-number minor units, and the app only ever *formats* them
(`lib/src/core/money.dart`). Money is never a `double`; direction comes from the transaction
**type**, not the sign. Wallet balances and the converted display-currency totals are
**derived** on the backend, never computed client-side.

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
| Misc | package_info_plus (version), url_launcher (publisher link), webview_flutter + web (in-app privacy policy) |
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
