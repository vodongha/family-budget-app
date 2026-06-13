import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// On web, Google Identity Services provides an ID token only through its own
/// rendered button. We size it to the given width so it lines up with the
/// app's other full-width buttons.
Widget googleRenderButton(double width) => web.renderButton(
      configuration: web.GSIButtonConfiguration(
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
        text: web.GSIButtonText.continueWith,
        shape: web.GSIButtonShape.rectangular,
        logoAlignment: web.GSIButtonLogoAlignment.center,
        minimumWidth: width,
      ),
    );
