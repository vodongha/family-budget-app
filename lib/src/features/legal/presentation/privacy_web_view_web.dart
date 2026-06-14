import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web: embeds the URL in an `<iframe>` via a platform view.
class PrivacyWebView extends StatefulWidget {
  const PrivacyWebView({super.key, required this.url});

  final String url;

  @override
  State<PrivacyWebView> createState() => _PrivacyWebViewState();
}

class _PrivacyWebViewState extends State<PrivacyWebView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    // A unique view type per instance so the factory closure keeps this url.
    _viewType = 'privacy-iframe-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => web.HTMLIFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%',
    );
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
