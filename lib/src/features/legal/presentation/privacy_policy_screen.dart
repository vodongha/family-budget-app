import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/config.dart';
import 'privacy_web_view.dart';

/// Shows the privacy policy in-app via a WebView, loaded from the backend
/// (`GET /privacy`) in the user's current language. The backend stays the single
/// source of truth; this just embeds it.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final String url = '${AppConfig.apiBaseUrl}/privacy?lang=$lang';
    return Scaffold(
      appBar: AppBar(title: Text(t.privacyPolicy)),
      body: PrivacyWebView(url: url),
    );
  }
}
