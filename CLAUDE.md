# family-budget-app — CLAUDE.md

Guidance for Claude (and humans) working in this repo.

## What this is

The **Flutter mobile client** for the Family Budget product. The backend (FastAPI +
SQLAlchemy + Oracle ADB) is a **separate repo**: `vodongha/family-budget`. This repo is
frontend only — it owns no business rules beyond input validation; the server is the source
of truth (especially for money).

This repo was renamed from `eShopSolution` (old .NET sample). Git history is kept on purpose
— don't recreate the repo or force-rewrite history away.

## Tech stack

- **Flutter** (Material 3), Dart `>=3.5`
- **Riverpod** (`AsyncNotifier`) for state — one controller per feature, mirrors the
  backend's service layer
- **Dio** for HTTP — a single configured client with a bearer-token interceptor
- **go_router** for navigation with an auth-aware redirect guard
- **flutter_secure_storage** for the JWT (Keychain / Keystore — never plain prefs)
- **intl** for money/date formatting

## Money rules (must follow)

- Amounts are **integer đồng** (`int`) end to end. **Never** parse money into `double`.
- The UI only **formats** money (`lib/src/core/money.dart`); it never does arithmetic on
  balances — those are **derived on the backend**.
- Direction is the transaction **type** (`expense`/`income`), not the sign of the amount.
  The amount sent to the API is always positive; the server rejects `amount <= 0` (422).

## Architecture

Layered per feature, mirroring the backend `router → service → repository`:

```
presentation (widgets) → application (Riverpod controllers) → data (repositories) → Dio → backend
```

```
lib/src/
├── core/         config · api_client (Dio) · token_storage · router · theme · money
└── features/<feature>/
    ├── domain/         immutable models with fromJson
    ├── data/           repository — the only place that touches Dio; wraps errors in ApiException
    ├── application/    Riverpod controller (AsyncNotifier) — holds state, orchestrates repos
    └── presentation/   screens (ConsumerWidget / ConsumerStatefulWidget)
```

Rules:
- **Widgets never call Dio directly.** Always go through a repository via a controller.
- **Repositories are stateless** and throw `ApiException` (see `core/api_client.dart`) — they
  never surface raw `DioException`.
- **Controllers** own state as `AsyncValue<T>`; after a mutation that changes derived
  balances, invalidate the affected providers (`walletsControllerProvider`,
  `dashboardControllerProvider`, `transactionsControllerProvider`) — see
  `TransactionsController.add`.

## Backend API (contract this app depends on)

Base URL via `--dart-define=API_BASE_URL=...` (default `http://10.0.2.2:8000`, the Android
emulator's route to host localhost).

- `POST /auth/register` `{email, password, display_name, family_name}` — creates family + owner (no auto-login; app logs in after).
- `POST /auth/login` — **form-encoded** `username` + `password` → `{access_token}`.
- `GET /auth/me` → user incl. `role` (`owner`/`member`).
- `PATCH /auth/me {display_name}` → updated user. `DELETE /auth/me` → `204` self-service
  account deletion (soft-delete; backend purges after 30 days). `409` when an owner must
  transfer ownership first — the app maps it to a localized message.
- `GET /wallets`, `POST /wallets {name}` — balances are derived.
- `GET /transactions?wallet_rid&limit`, `POST /transactions {wallet_rid, type, amount, note?, occurred_on?}`.
- `GET /dashboard/summary` → `{total_income, total_expense, net_balance, wallet_count, wallets[]}`.

Errors: 401 (no/expired token → app drops it and returns to login), 403 (owner-only), 404
(not found in this family / cross-family), 409 (duplicate), 422 (validation).

## Localization (i18n)

English + Vietnamese via the official `flutter_localizations` + ARB pipeline.

- Strings live in `lib/l10n/app_en.arb` (template) and `app_vi.arb`. `flutter gen-l10n`
  generates `AppLocalizations` into `lib/l10n/app_localizations*.dart` (**gitignored** —
  regenerated on build and in CI; never hand-edit).
- Use them in widgets: `final t = AppLocalizations.of(context);` then `t.someKey`. Placeholders
  are methods (`t.greeting(name)`, `t.walletsWithCount(count)`).
- **Add a string:** add the key to *both* ARB files, then run `flutter gen-l10n`. Don't hardcode
  user-facing text in widgets.
- The active locale is `LocaleController` (`core/prefs.dart`), persisted via
  `shared_preferences`; `null` = follow the device. `SharedPreferences` is loaded in `main()`
  and injected through `sharedPreferencesProvider`.

## Sign in with Google

- `GoogleSignInButton` (`features/auth/presentation/google_sign_in_button.dart`) gets a Google
  **ID token** and calls `POST /auth/google`. On **web**, Google Identity Services only returns
  an ID token via its own rendered button (`google_render_button*.dart`, conditional import); on
  mobile it's a normal button calling `signIn()`.
- **Web config:** add the client ID as a meta tag in `web/index.html`:
  `<meta name="google-signin-client_id" content="...apps.googleusercontent.com">`. (`web/` is a
  generated, uncommitted platform folder — re-add the tag after `flutter create .`.) The authorized
  JavaScript origin in Google Cloud must match the run origin (we use `--web-port=8080`).
- **Backend** needs `GOOGLE_CLIENT_ID` set to the same client ID (its token audience check).

## Theming & settings

- The design system lives in `core/theme.dart` (`AppTheme.light()` / `dark()`) — one seed
  colour, rounded cards, filled inputs, low elevation. Use `Theme.of(context).colorScheme`
  tokens (`primary`, `onSurfaceVariant`, …); **don't hardcode colours**.
- `ThemeController` (`core/prefs.dart`) holds `ThemeMode` (system/light/dark), persisted via
  `shared_preferences`, default `system`. `MaterialApp.router` reads it via `themeControllerProvider`.
- **Settings** (`features/settings/presentation/settings_screen.dart`, `/settings`) chooses theme
  + language. **Account menu** (`features/auth/presentation/account_menu.dart`, `showAccountSheet`)
  is the bottom sheet opened from the dashboard avatar: edit profile, settings, sign out, delete.

## Profile & account deletion

`features/auth/presentation/profile_screen.dart` (`/profile`, reached from the dashboard):
edit display name (`PATCH /auth/me`), pick language, sign out, and **delete account**. Deletion
shows a Google-Play-policy warning, calls `DELETE /auth/me`, then the auth state goes null and
the router redirects to login. A `409` (owner must transfer first) is shown as a localized
message. Keep this entry point — Google Play requires in-app account deletion.

## Conventions

- Microsoft-ish Dart style: `prefer_single_quotes`, explicit return types, **always braces**.
- `var` only when the type is obvious from the right-hand side.
- Blazor-style "code-behind" isn't a thing here, but keep widgets thin — push logic into
  controllers/repositories.
- New screens go under `features/<feature>/presentation/` and route via `core/router.dart`.
- Run `dart format .` before committing — CI fails on unformatted code.

## Build & run

```bash
flutter create .        # ONE-TIME: generate android/ios/web/ platform folders (not committed)
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter analyze
flutter test
dart format .
```

The native platform folders are intentionally **not** committed (this was a hand-written
scaffold). `flutter create .` regenerates them without touching `lib/`, `pubspec.yaml`, or
`test/`.

## Testing

- `flutter test` — pure unit tests (money parsing/formatting, transaction model). No device,
  no backend, no secrets.
- Widget/integration tests that hit the network are out of scope here; the backend repo owns
  API-level tests.

## Git workflow

- Personal repo — set the **personal identity locally** (the machine's global git defaults to
  the company email):
  ```bash
  git config --local user.name "vodongha"
  git config --local user.email "vodongha@hotmail.com"
  ```
- **AI-assisted commits are authored by Claude**, committed by the personal identity:
  ```bash
  git commit --author="Claude Opus 4.8 <noreply@anthropic.com>" -m "..."
  ```
- Branch off `master`; merge with merge commits (no squash/rebase). Reference the backend
  repo when a change tracks an API change.

## Gotchas

- **Form-encoded login.** `/auth/login` is OAuth2 password flow — send
  `application/x-www-form-urlencoded`, not JSON. (`AuthRepository.login` sets this.)
- **Emulator networking.** `localhost` inside an Android emulator is the emulator, not your
  PC. Use `10.0.2.2` for the host. iOS simulator and web can use `localhost`.
- **Derived balances.** After adding a transaction, invalidate wallets + dashboard providers
  or the displayed balances go stale.
- **No committed platform folders.** A fresh clone won't run until `flutter create .`.
