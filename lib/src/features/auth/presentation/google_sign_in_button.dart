import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/config.dart';
import '../application/auth_controller.dart';
import 'google/google_render_button.dart';

/// "Sign in with Google" entry point.
///
/// On **web**, Google Identity Services hands back an ID token only through its
/// own rendered button, so we show that (`googleRenderButton`). On other
/// platforms we show a normal button that triggers `signIn()`. Either way, when
/// an account arrives we pull its ID token and hand it to the backend.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  late final GoogleSignIn _gsi;
  StreamSubscription<GoogleSignInAccount?>? _sub;

  @override
  void initState() {
    super.initState();
    // The same web client ID is used on every platform, but in different roles:
    // on web it configures GIS directly (`clientId`); on mobile the native
    // OAuth client is matched by package name + SHA-1, and we pass the web ID as
    // `serverClientId` so the returned ID token's audience is one the backend
    // accepts. Passing `clientId` on Android instead leaves `idToken` null.
    final String webClientId = AppConfig.googleClientId;
    _gsi = GoogleSignIn(
      clientId: kIsWeb && webClientId.isNotEmpty ? webClientId : null,
      serverClientId: !kIsWeb && webClientId.isNotEmpty ? webClientId : null,
      scopes: const ['email', 'profile', 'openid'],
    );
    _sub = _gsi.onCurrentUserChanged.listen(_onAccount);
    if (kIsWeb) {
      // Lets GIS restore a previous session and enables the rendered button.
      unawaited(_gsi.signInSilently());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onAccount(GoogleSignInAccount? account) async {
    if (account == null) {
      return;
    }
    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;
    if (idToken != null && idToken.isNotEmpty) {
      await ref.read(authControllerProvider.notifier).signInWithGoogle(idToken);
    }
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
          // Visual layer — matches the FilledButton/OutlinedButton geometry
          // (52 high, 14 radius) from the theme. Ignores pointers so taps fall
          // through to the GIS button above it.
          IgnorePointer(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const _GoogleG(),
              label: Text(t.continueWithGoogle),
            ),
          ),
          // Click layer — the real GIS button, stretched to fill and made
          // invisible (a hair above 0 so the DOM element stays clickable).
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
      onPressed: () => _gsi.signIn(),
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
