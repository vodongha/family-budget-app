/// App-wide configuration, resolved at build time.
///
/// The API base URL is supplied with `--dart-define=API_BASE_URL=...`.
/// The default targets the FastAPI backend from an **Android emulator**, where
/// `10.0.2.2` maps to the host machine's `localhost`. For iOS simulator or web
/// use `http://localhost:8000`; for a physical device use the host's LAN IP.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Google OAuth client ID. On web it can also come from the
  /// `google-signin-client_id` meta tag in `web/index.html`; passing it here
  /// (via `--dart-define=GOOGLE_CLIENT_ID=...`) is optional. Empty hides the
  /// Google button on platforms that need it configured.
  static const String googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID');
}
