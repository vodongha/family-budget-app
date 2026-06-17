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

  /// Google OAuth **web** client ID — used on every platform:
  /// - on **web** it configures Google Identity Services directly (it can also
  ///   come from the `google-signin-client_id` meta tag in `web/index.html`);
  /// - on **mobile** it is passed as `serverClientId` so the returned ID token's
  ///   audience matches the backend's `GOOGLE_CLIENT_ID` check (the native
  ///   Android/iOS OAuth client is matched separately by package name + SHA-1).
  ///
  /// Overridable with `--dart-define=GOOGLE_CLIENT_ID=...`. The default is the
  /// production web client ID, which is a public identifier (it already appears
  /// in the backend Dockerfile and `web/index.html`), so mobile release builds
  /// get Google Sign-In working without an extra dart-define.
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '692858320760-0n5vkifgkqjoktqigpsjrhr8jqphjdka.apps.googleusercontent.com',
  );

  /// Community & support forum, opened from the account menu (in-app WebView on
  /// mobile, a new browser tab on web).
  static const String communityUrl = 'https://vodongha.forumvi.com';
}
