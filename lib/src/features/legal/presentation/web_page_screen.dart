import 'package:flutter/material.dart';

import 'privacy_web_view.dart';

/// A generic in-app page that shows an external [url] in a WebView (reusing the
/// same platform-dispatched widget as the privacy policy). Used for the
/// community/support forum on mobile; web opens the URL in a new tab instead.
class WebPageScreen extends StatelessWidget {
  const WebPageScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PrivacyWebView(url: url),
    );
  }
}
