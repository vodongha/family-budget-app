// Platform-dispatched WebView for the privacy policy.
//
// On Android / iOS this resolves to a real `webview_flutter` view; on the web
// it resolves to an `<iframe>`. Both expose the same `PrivacyWebView` widget so
// callers don't care which platform they're on.
export 'privacy_web_view_mobile.dart'
    if (dart.library.html) 'privacy_web_view_web.dart';
