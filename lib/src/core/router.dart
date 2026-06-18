import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/auth_user.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/budgets/presentation/budgets_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/family/presentation/family_screen.dart';
import '../features/invitations/presentation/add_member_screen.dart';
import '../features/invitations/presentation/invitations_inbox_screen.dart';
import '../features/invitations/presentation/invite_screen.dart';
import '../../l10n/app_localizations.dart';
import '../features/legal/presentation/privacy_policy_screen.dart';
import '../features/legal/presentation/web_page_screen.dart';
import 'config.dart';
import '../features/members/presentation/members_screen.dart';
import '../features/rates/presentation/currency_converter_screen.dart';
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/stats/presentation/stats_screen.dart';
import '../features/transactions/domain/transaction.dart';
import '../features/transactions/presentation/add_transaction_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';
import '../features/wallets/presentation/transfer_screen.dart';

/// The app router. It watches the auth session and redirects:
/// - while the session is still bootstrapping → a splash spinner;
/// - signed out → `/login` (except the auth pages themselves);
/// - signed in → away from the auth/splash pages, into the dashboard.
final routerProvider = Provider<GoRouter>((ref) {
  // Bridge the Riverpod auth state into a Listenable for go_router.
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  ref.listen<AsyncValue<AuthUser?>>(
    authControllerProvider,
    (_, __) => refresh.value++,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final AsyncValue<AuthUser?> auth = ref.read(authControllerProvider);
      final String at = state.matchedLocation;

      // True only during the initial bootstrap (no value resolved yet).
      final bool bootstrapping = !auth.hasValue && auth.isLoading;
      if (bootstrapping) {
        return at == '/splash' ? null : '/splash';
      }

      final AuthUser? user = auth.valueOrNull;
      final bool signedIn = user != null;
      // The invite landing page is public (the invitee registers there).
      final bool onInvite = at.startsWith('/invite');
      final bool onAuthPage = at == '/login' || at == '/register' || onInvite;

      if (!signedIn) {
        return onAuthPage ? null : '/login';
      }

      // Signed in. A brand-new account with no family lands in the app on the
      // personal tab; it creates or joins a family on demand (the Family tab and
      // family-only features prompt for it). Just keep them off the auth/splash
      // pages.
      if (onAuthPage || at == '/splash') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (_, state) =>
            InviteScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'members',
            builder: (_, __) => const MembersScreen(),
          ),
          GoRoute(
            path: 'family',
            builder: (_, __) => const FamilyScreen(),
          ),
          GoRoute(
            path: 'members/add',
            builder: (_, __) => const AddMemberScreen(),
          ),
          GoRoute(
            path: 'invitations',
            builder: (_, __) => const InvitationsInboxScreen(),
          ),
          GoRoute(
            path: 'transactions',
            builder: (_, __) => const TransactionsScreen(),
          ),
          GoRoute(
            path: 'transactions/new',
            builder: (_, __) => const AddTransactionScreen(),
          ),
          GoRoute(
            path: 'transactions/edit',
            builder: (_, state) =>
                AddTransactionScreen(existing: state.extra as Transaction?),
          ),
          GoRoute(
            path: 'transfers/new',
            builder: (_, __) => const TransferScreen(),
          ),
          GoRoute(
            path: 'budgets',
            builder: (_, __) => const BudgetsScreen(),
          ),
          GoRoute(
            path: 'calendar',
            builder: (_, __) => const CalendarScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'change-password',
            builder: (_, __) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (_, __) => const PrivacyPolicyScreen(),
          ),
          GoRoute(
            path: 'community',
            builder: (context, __) => WebPageScreen(
              title: AppLocalizations.of(context).community,
              url: AppConfig.communityUrl,
            ),
          ),
          GoRoute(
            path: 'about',
            builder: (_, __) => const AboutScreen(),
          ),
          GoRoute(
            path: 'stats',
            builder: (_, __) => const StatsScreen(),
          ),
          GoRoute(
            path: 'categories',
            builder: (_, __) => const CategoriesScreen(),
          ),
          GoRoute(
            path: 'currency-converter',
            builder: (_, __) => const CurrencyConverterScreen(),
          ),
        ],
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
