import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Android / iOS: loads the URL in an embedded WebView.
class PrivacyWebView extends StatefulWidget {
  const PrivacyWebView({super.key, required this.url});

  final String url;

  @override
  State<PrivacyWebView> createState() => _PrivacyWebViewState();
}

class _PrivacyWebViewState extends State<PrivacyWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
