import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/auth_user.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/transactions/presentation/add_transaction_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';

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

      final bool signedIn = auth.valueOrNull != null;
      final bool onAuthPage = at == '/login' || at == '/register';

      if (!signedIn) {
        return onAuthPage ? null : '/login';
      }
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
        path: '/',
        builder: (_, __) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'transactions',
            builder: (_, __) => const TransactionsScreen(),
          ),
          GoRoute(
            path: 'transactions/new',
            builder: (_, __) => const AddTransactionScreen(),
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
