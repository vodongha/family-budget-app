import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/config.dart';
import '../application/auth_controller.dart';
import 'google/google_render_button.dart';

/// google_sign_in 7.x must be initialized exactly once per process before any
/// use. The same web client ID is passed as `clientId` on web (configures GIS
/// directly) and as `serverClientId` on mobile (so the returned ID token's
/// audience is one the backend accepts). Shared across button mounts.
Future<void>? _gsiInit;
Future<void> _ensureGsiInitialized() {
  return _gsiInit ??= () async {
    final String id = AppConfig.googleClientId;
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb && id.isNotEmpty ? id : null,
      serverClientId: !kIsWeb && id.isNotEmpty ? id : null,
    );
  }();
}

/// "Sign in with Google" entry point.
///
/// On **web**, Google Identity Services hands back an ID token only through its
/// own rendered button (`googleRenderButton`); on other platforms a normal
/// button triggers `authenticate()`. Either way the ID token arrives via the
/// `authenticationEvents` stream and is handed to the backend. We never call
/// `attemptLightweightAuthentication()`, so there is no silent auto-login: the
/// user always picks an account, and sign-in works again after logout.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _ensureGsiInitialized();
    } catch (_) {
      return; // Google not configured / unavailable — button is inert.
    }
    if (!mounted) {
      return;
    }
    _sub = GoogleSignIn.instance.authenticationEvents.listen(
      _onEvent,
      onError: (_) {}, // a cancelled/failed attempt is not fatal
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) {
      return;
    }
    final String? idToken = event.user.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      return;
    }
    await ref.read(authControllerProvider.notifier).signInWithGoogle(idToken);
    // signInWithGoogle swallows failures into the auth state; the login screen
    // surfaces the error via a snackbar and the next button tap re-prompts.
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    if (kIsWeb) {
      // GIS only hands back an ID token through its own rendered button, and
      // that button can't be sized to match the app (height caps at 40, corners
      // are fixed). So we draw our own button styled like the other ones and
      // lay the real GIS button on top, transparent, to capture the tap.
      return Stack(
        children: [
          IgnorePointer(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const _GoogleG(),
              label: Text(t.continueWithGoogle),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,
              child: LayoutBuilder(
                builder: (context, constraints) => FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: 40,
                    child: googleRenderButton(constraints.maxWidth),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: () async {
        try {
          await _ensureGsiInitialized();
          await GoogleSignIn.instance.authenticate();
        } catch (_) {
          // User cancelled the picker or Google is unavailable — ignore.
        }
      },
      icon: const _GoogleG(),
      label: Text(t.continueWithGoogle),
    );
  }
}

/// A small Google "G" mark for the sign-in button.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
