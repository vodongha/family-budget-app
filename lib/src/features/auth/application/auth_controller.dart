import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
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
    } on ApiException catch (e) {
      // Only a real 401 means the token is actually rejected — drop it and sign
      // out. Any other failure (offline, timeout, or the backend waking from
      // suspend / a 5xx) is transient: keep the token and resume from the last
      // cached profile so the user isn't logged out by a momentary hiccup. With
      // no cache, stay signed out for now but keep the token so a later launch
      // can recover.
      if (e.statusCode == 401) {
        await _repo.logout();
        return null;
      }
      return _repo.cachedUser();
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
    String? phone,
  }) async {
    state = const AsyncValue<AuthUser?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
        phone: phone,
      );
      return _repo.me();
    });
  }

  /// Create the signed-in account's family (onboarding) and refresh the session
  /// with the new family scope. Throws [ApiException] on failure (e.g. 409 if a
  /// family already exists) — the caller shows it.
  Future<void> createFamily(String name) async {
    state = const AsyncValue<AuthUser?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _repo.createFamily(name);
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

  /// Update the display name and phone, reflecting it in the session immediately.
  Future<void> updateProfile({
    required String displayName,
    String? phone,
  }) async {
    final AuthUser updated =
        await _repo.updateProfile(displayName: displayName, phone: phone);
    state = AsyncValue.data(updated);
  }

  /// Re-read the current user (e.g. after joining a different family changes the
  /// stored token). Keeps the session but refreshes role/family scope.
  Future<void> refreshUser() async {
    state = await AsyncValue.guard(() => _repo.me());
  }

  /// Change or set the account password. Refreshes the user afterwards so
  /// `hasPassword` flips true for a Google-only account that just set one.
  /// Throws [ApiException] on failure (e.g. 400 wrong current password).
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    await _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await refreshUser();
  }

  /// Delete the family (owner-only, sole member) and refresh the session, which
  /// becomes family-less. Throws [ApiException] (e.g. 409 if members remain).
  Future<void> deleteFamily() async {
    await _repo.deleteFamily();
    await refreshUser();
  }

  /// Leave the current family and refresh the session (now family-less). Throws
  /// [ApiException] (e.g. 409 if an owner must transfer ownership first).
  Future<void> leaveFamily() async {
    await _repo.leaveFamily();
    await refreshUser();
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
