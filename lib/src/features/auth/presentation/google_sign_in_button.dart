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
    _gsi = GoogleSignIn(
      clientId:
          AppConfig.googleClientId.isEmpty ? null : AppConfig.googleClientId,
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
      // Full-width GIS button, sized to the surrounding column so it lines up
      // with the other buttons. GIS caps the width at 400.
      return LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: 48,
          width: double.infinity,
          child: Align(
            alignment: Alignment.center,
            child: googleRenderButton(constraints.maxWidth),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _gsi.signIn(),
      icon: const Icon(Icons.login),
      label: Text(t.continueWithGoogle),
    );
  }
}
