import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

/// The session state. `null` user = signed out. Exposed as an [AsyncNotifier]
/// so the UI gets loading/error for free, and the router can watch it to guard
/// routes.
class AuthController extends AsyncNotifier<AuthUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthUser?> build() async {
    // Bootstrap: if a token survives from a previous session, resume it.
    final String? token = await _repo.readToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    try {
      return await _repo.me();
    } catch (_) {
      // Stale/expired token — drop it and start signed out.
      await _repo.logout();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    // Keep the previous value so the router can tell "logging in" (value
    // present, loading) apart from "bootstrapping" (no value yet → splash).
    state = const AsyncValue<AuthUser?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.login(email, password);
      return _repo.me();
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String familyName,
  }) async {
    state = const AsyncValue<AuthUser?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
        familyName: familyName,
      );
      return _repo.me();
    });
  }

  /// Sign in with a Google ID token: exchange it for our JWT and load the user.
  Future<void> signInWithGoogle(String idToken) async {
    state = const AsyncValue<AuthUser?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.googleLogin(idToken);
      return _repo.me();
    });
  }

  /// Update the display name and reflect it in the session immediately.
  Future<void> updateDisplayName(String displayName) async {
    final AuthUser updated = await _repo.updateDisplayName(displayName);
    state = AsyncValue.data(updated);
  }

  /// Delete the account, then drop the session. Throws [ApiException] on failure
  /// (e.g. 409 when an owner must transfer ownership first) — the caller shows it.
  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    state = const AsyncValue.data(null);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);

/// Convenience: are we signed in right now? (false while loading/errored.)
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).valueOrNull != null;
});
