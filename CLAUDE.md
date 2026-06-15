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
- **phone_form_field** for the optional phone number (country-code picker → E.164)
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
  balances, invalidate the affected providers — `walletsControllerProvider`,
  `dashboardControllerProvider`, `monthlyStatsProvider`, `categoryStatsProvider` — see
  `TransactionsController._invalidateDerived` (add/edit/remove/transfer all call it).

## Backend API (contract this app depends on)

Base URL via `--dart-define=API_BASE_URL=...` (default `http://10.0.2.2:8000`, the Android
emulator's route to host localhost).

- `POST /auth/register` `{email, password, display_name, family_name?, phone?}` — creates an
  **account** (no auto-login; app logs in after). `family_name` is **optional**: the app omits it,
  so the new account has **no family** — it lands on the **personal** tab and creates/joins one on
  demand. `phone` optional, E.164.
- `POST /families {name}` → `{access_token}` — create a family for a family-less account (owner +
  seeded categories). The app stores the **new token** (it carries the family scope) and refreshes.
- `PATCH /families {name}` → `{name}` (rename, owner). `DELETE /families` → `{access_token}` (delete;
  owner + sole member; keeps personal data → family-less token). `POST /families/leave` →
  `{access_token}` (leave; owner with members → `409`). `DELETE /families/members/{rid}` → `204`
  (owner removes a member). Calls that change *your own* family return a fresh token (store it).
- `POST /auth/login` — **form-encoded** `username` + `password` → `{access_token}`.
- `GET /auth/me` → user incl. `role` (`owner`/`member`), `phone` (nullable), `has_family`,
  `family_name` (nullable) and `has_password` (false → "set password" instead of "change").
- `POST /auth/google {id_token}` → `{access_token}` (Sign in with Google). Links to an existing
  account by email (**case-insensitive**); a brand-new Google account has no family yet.
- `POST /auth/change-password {current_password?, new_password}` → `204`. Omit `current_password`
  to set the first password on a Google-only account; `400` if the current password is wrong.
- `PATCH /auth/me {display_name, phone}` → updated user. `phone` is always sent (blank
  clears it); `422` invalid number, `409` duplicate. `DELETE /auth/me` → `204` self-service
  account deletion (soft-delete; backend purges after 30 days). `409` when an owner must
  transfer ownership first — the app maps it to a localized message.
- `GET /members` → active family members `[{rid, display_name, email, phone?, role}]`.
- `POST /families/transfer-ownership {target_rid}` (owner-only) → new owner; the caller
  becomes a member (single-owner model).
- `GET /wallets?scope=all|family|personal`, `POST /wallets {name, visibility, icon?, color?}` —
  `visibility` is `family` (shared) or `personal` (private to creator); each wallet
  carries `visibility`, `icon` (emoji), `color` (hex) and `created_by_me` (true when you
  created it). `PATCH /wallets/{rid} {name?, icon?, color?}` edits it (a shared wallet by the
  family **owner or its creator**, a personal wallet by its owner; visibility immutable).
  `DELETE /wallets/{rid}` (same permission). Balances are derived. **Personal wallets work without
  a family**; creating a `family` wallet without one is `400`. Wallets/transactions/dashboard/stats
  all accept an optional family, so the **personal** tab works for a family-less account.
- `GET /transactions?wallet_rid&scope&limit&type&category_rid&date_from&date_to`,
  `POST /transactions {wallet_rid, type, amount, note?, category_rid?, occurred_on?}`,
  `PATCH /transactions/{rid}` (same body — full update), `DELETE /transactions/{rid}` (`204`).
  The list may include `transfer_in`/`transfer_out` legs (read-only in the UI).
- `GET /budgets` → `[{rid, category, amount, spent}]` (current-month spend per category);
  `POST /budgets {category_rid, amount}` (`409` if the category already has a budget),
  `PATCH /budgets/{rid} {amount}`, `DELETE /budgets/{rid}`.
- `POST /transfers {from_wallet_rid, to_wallet_rid, amount, note?, occurred_on?}` → moves
  money between wallets (two linked legs); `DELETE /transfers/{group_rid}`.
- `GET /dashboard/summary?scope=all|family|personal` → `{total_income, total_expense, net_balance, wallet_count, wallets[]}`.
- `GET /stats/monthly?months=N` → `[{month, income, expense}]` (statistics charts).
- `GET /stats/by-category?kind=expense|income&months=N` →
  `[{category_rid?, name?, icon?, color?, default_key?, amount}]` sorted by amount desc;
  the uncategorized bucket has `category_rid` null + `default_key` `"uncategorized"`.
- `POST /invitations {email?|phone?}` (**any member**) → invite incl. `in_app` (true when the
  contact matched an existing account); the invitee always joins as `member`. `GET /invitations/{token}` (public) → `{family_name, role,
  status, email?}`; `POST /invitations/accept {token, password, display_name, email?}` (public)
  → `{access_token}` (auto-login).
- **In-app invites** (existing accounts): `GET /invitations/inbox` (auth) → pending invites
  `[{rid, family_name, invited_by, role}]`; `POST /invitations/{rid}/accept-existing` (auth)
  → `{access_token}` (joins the family; `409` if the caller owns a family with other members);
  `POST /invitations/{rid}/decline` (auth).

Errors: 401 (no/expired token → app drops it and returns to login), 403 (owner-only), 404
(not found in this family / cross-family), 409 (duplicate), 422 (validation).

## Navigation, budgets, transfers & calendar

- **Dashboard hub** (`features/dashboard/`): the home is balance card → wallets → a swipeable
  **hub** (`_HubPager`, a `PageView` of 4×2 feature shortcuts with page dots). The account
  sheet (`account_menu.dart`) is account-only (profile / settings / **privacy policy** /
  sign out / delete); all feature navigation lives in the hub. **Adding a member** is a
  button on the Members screen, not a hub shortcut.
- **Privacy policy** (`features/legal/`): the account sheet entry (below Settings) opens
  `/privacy`, an in-app **WebView** that loads the backend's bilingual page
  (`${AppConfig.apiBaseUrl}/privacy?lang=<locale>`). `privacy_web_view.dart` is a conditional
  export — `webview_flutter` on Android/iOS, an `<iframe>` (`package:web` + `dart:ui_web`) on
  web. The backend is the single source of truth; the app just embeds it.
- **No-family flow (personal-first).** There is no forced onboarding screen. A signed-in account
  with **no family** (`AuthUser.hasFamily` false) lands on the app with the scope toggle defaulting
  to **Personal** (`walletScopeProvider` default = personal), which works without a family. Tapping
  the **Family** tab, or a **family-only hub item** (Budgets / Categories / Members), opens
  `showCreateFamilyDialog` (`features/family/presentation/create_family_dialog.dart`) — create a
  family (`POST /families`) or jump to Invitations — instead of navigating into a 403. The
  create-wallet sheet hides the shared/private toggle (forces personal) when there's no family.
- **Family management** (`features/family/presentation/family_screen.dart`, `/family`, from the
  account menu when `hasFamily`): rename, leave, and (owner + sole member) delete the family; the
  Members screen adds owner **remove-member** (per-row menu) and a **Leave family** app-bar action.
  Leaving/deleting resets the scope to personal and goes home. The family controllers store the
  fresh token (delete/leave) via `authController.deleteFamily`/`leaveFamily` then `refreshUser`.
- **Change/set password** (`features/auth/presentation/change_password_screen.dart`,
  `/change-password`, from Settings): `POST /auth/change-password`; for a Google-only account
  (`hasPassword` false) it's "set password" with no current-password field.
- **Add transaction is scope-aware** (`add_transaction_screen.dart`): the wallet picker lists only
  wallets of the current `walletScopeProvider` (family→shared, personal→private) and defaults to
  one in that scope, so an entry can't land in the wrong scope. The inline "new wallet" defaults to
  the current scope. Edit keeps the transaction's own wallet selectable.
- **Transaction edit/filter** (`features/transactions/`): tap a row → `AddTransactionScreen`
  in edit mode (delete from its app bar). `txnFilterProvider` (type/category/**walletRid**/date)
  feeds the list controller; the filter sheet lives in `transactions_screen.dart`. The dashboard
  drills in here: tapping the hero **Income/Expense** sets the `type` filter, tapping a **wallet
  tile** sets the `walletRid` filter, then pushes `/transactions`. In **family scope** each row
  shows its creator; edit/delete are gated by `Transaction.canEdit` so only the creator can change
  their own entries (others get 403).
- **Wallet create/edit** (`features/wallets/presentation/wallet_edit_sheet.dart`,
  `showWalletEditSheet`): one bottom sheet for both — name, shared/private (create only), emoji
  **icon** and a **colour** swatch. Reached from the dashboard wallet tile's ⋮ menu (Edit) and the
  add-transaction "+" / empty-state. The ⋮ menu shows for a wallet the user can manage —
  `isOwner || wallet.isPersonal || wallet.createdByMe` (the family owner, a personal wallet's owner,
  or a shared wallet's creator). `WalletsController.edit` (not `update` — that name collides
  with `AsyncNotifier.update`).
- **Responsive** (`core/responsive.dart`, `ResponsiveCenter`): wraps the body of the main screens
  (dashboard, transactions, stats, settings, members, budgets, calendar, profile) to cap width
  (~720) and centre on wide screens. It keeps height tight (LayoutBuilder + SizedBox) so inner
  `ListView`/`Expanded` still get bounded height — don't replace it with a bare `Center`/`Align`.
- **Budgets** (`features/budgets/`): `/budgets` lists per-category monthly limits with a
  progress bar + over-budget warning; add/edit/delete.
- **Transfers** (`features/wallets/presentation/transfer_screen.dart`): `/transfers/new` moves
  money between two wallets via `TransactionsController.transfer`.
- **Calendar** (`features/calendar/`): `/calendar` shows a month grid (each day's net amount)
  via `monthTransactionsProvider`; tap a day for its totals + transactions. Scope-aware.

## Members, invites & statistics

- **Members** (`features/members/`): the `/members` screen (hub) lists active
  members with their role; an owner sees a transfer-ownership action per member that calls
  `POST /families/transfer-ownership` (the caller is demoted to member). `MembersController`
  refreshes the list and the auth user (role changed) after a transfer. **Every member** gets an
  **Add member** FAB here (→ `/members/add`) — this replaced the old hub shortcut.
- **Invites** (`features/invitations/`): the Add-member screen (`/members/add`, open to any
  member) creates an invitation by email or phone (the invitee joins as `member`).
  The invite link is built from `AppConfig.apiBaseUrl` (the web app is served same-origin), not
  `Uri.base` — on mobile `Uri.base` is `file://`. If the contact matches an **existing account** the response
  is `in_app` and the screen shows an "invitation sent" card (no link); otherwise it shows a
  shareable link `<origin>/#/invite/<token>`. The **public** `/invite/:token` landing (router
  whitelists it when signed-out) registers a brand-new invitee. **In-app invites** land in the
  invitee's **Invitations** inbox (`/invitations`, `InboxController`): accepting calls
  `accept-existing`, stores the new token, refreshes the user, and invalidates family-scoped
  providers (dashboard/wallets/transactions/stats/members) before going home. One user belongs
  to one family — accepting moves them (their now-empty old family is soft-deleted server-side).
- **Statistics** (`features/stats/`): `/stats` (dashboard bar-chart icon) draws `fl_chart`
  charts from `GET /stats/monthly` + the dashboard summary. A `1M/3M/6M/12M` selector drives
  `monthlyStatsProvider(months)`, defaulting to **1 month**. A **by-category** donut card (expense/income toggle) reads
  `categoryStatsProvider((kind, months))` from `GET /stats/by-category`; slices reuse the
  category colour/emoji and `defaultCategoryLabel` for localized names, with a fallback palette.

## Personal vs family spending

Wallets are **shared (family)** or **private (personal)**. A `WalletScope`
(`features/wallets/application/wallet_scope.dart`) `StateProvider` holds the
current view, defaulting to **family**; the dashboard's segmented toggle
(`_ScopeToggle`) flips it. The dashboard, transactions, and stats read providers
**watch** `walletScopeProvider` and pass `scope` to the API, so the whole UI
switches between shared and private spending at once. The add-transaction
"new wallet" dialog chooses shared/private; the wallet picker, wallet tiles, and
the scope toggle mark personal wallets with a lock icon. A personal wallet can be
deleted by its owner even if they aren't the family owner (`walletsController`
keeps `scope=all` so the picker always lists every wallet you can see).

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
- **Client ID roles:** the same **web** client ID (`AppConfig.googleClientId`, defaulted to the
  public production web client) is passed as `clientId` on web, but as **`serverClientId`** on
  mobile — that makes the returned ID token's audience one the backend accepts. Passing it as
  `clientId` on Android leaves `idToken` null (a past bug). The native Android OAuth client is
  matched separately by package name + SHA-1 (must match the running build's signing cert).
- **Web config:** add the client ID as a meta tag in `web/index.html`:
  `<meta name="google-signin-client_id" content="...apps.googleusercontent.com">`. (`web/` is a
  generated, uncommitted platform folder — re-add the tag after `flutter create .`.) The authorized
  JavaScript origin in Google Cloud must match the run origin (we use `--web-port=8080`).
- **Backend** needs `GOOGLE_CLIENT_ID` set to the same client ID (its token audience check); it
  links Google to an existing account by email **case-insensitively**.

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
edit display name and **phone** (optional, via `AppPhoneField` → E.164; `PATCH /auth/me`),
pick language, sign out, and **delete account**. Deletion
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
flutter create . --platforms=ios,web,windows   # ONE-TIME: generate the still-uncommitted folders
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter analyze
flutter test
dart format .
```

**`android/` is committed** (needed for the Play release: `applicationId = vn.famo.budget`,
INTERNET permission, and release signing config in `android/app/build.gradle.kts`). Secrets stay
out via `android/.gitignore` + the root `.gitignore` — `key.properties`, `*.jks`/`*.keystore`,
`local.properties`, and `gradle-wrapper.jar`/`gradlew` are **not** committed (the wrapper is
present locally after `flutter create`). The other platform folders (`ios/`, `web/`, `windows/`)
remain uncommitted and are regenerated by `flutter create .` without touching `lib/`,
`pubspec.yaml`, or `test/`.

**Release signing:** create `android/key.properties` (gitignored) with `storeFile`, `storePassword`,
`keyAlias`, `keyPassword` pointing at your keystore; `build.gradle.kts` uses it for release builds
and falls back to debug signing when it's absent (so `flutter run` works without a keystore).

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
- **AI-assisted commits are authored by vodongha, committed by Claude** (the committer
  override records that Claude made the commit while attributing authorship to the owner):
  ```bash
  GIT_COMMITTER_NAME="Claude Opus 4.8" GIT_COMMITTER_EMAIL="noreply@anthropic.com" \
    git commit --author="vodongha <vodongha@hotmail.com>" -m "..."
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
- **Only `android/` is committed.** A fresh clone still needs `flutter create . --platforms=ios,web,windows` to regenerate the other platform folders before running on those targets.
