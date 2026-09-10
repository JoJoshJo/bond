/// Compile-time configuration, supplied via `--dart-define-from-file=env.json`.
///
/// Values are read as `const String.fromEnvironment(...)` so nothing sensitive
/// is ever written into source or committed to git. See `env.example.json` for
/// the expected shape, and copy it to `env.json` (gitignored) with real values.
///
/// Run with:
///   flutter run --dart-define-from-file=env.json
class AppConfig {
  const AppConfig._();

  /// Supabase project URL, e.g. https://xxxx.supabase.co
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon (public) key. Safe to ship in the client — protected by RLS.
  /// The service_role key must NEVER live here or anywhere in the app.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// RevenueCat iOS (App Store) public SDK key — starts with `appl_`. Safe to
  /// ship in the client (it's a public SDK key). Empty on builds without it, in
  /// which case RevenueCat is simply not configured (premium falls back to the
  /// subscriptions table / dev override).
  static const String revenueCatAppleKey =
      String.fromEnvironment('REVENUECAT_APPLE_KEY');

  /// True when both required values were provided at build time.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
