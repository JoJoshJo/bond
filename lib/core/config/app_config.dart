import 'package:flutter/foundation.dart' show kDebugMode;

/// Whether the in-app DEVELOPER tools are visible AND functional — the
/// "Developer" section in the Us tab, the premium dev-override, and the spicy
/// dev-unlock.
///
/// DEFAULTS TO TRUE: a normal build (no flags) SHOWS the dev tools, so any
/// build can be used to test premium / spicy. The FINAL submission build turns
/// them OFF — hidden in the UI AND the override made powerless — by passing
/// `--dart-define=USORA_DEV=false`.
///
/// Build commands (`apk` or `ipa`):
///   • Testing build (dev toggle VISIBLE — the default, no flag needed):
///       `flutter build apk --release --dart-define-from-file=env.json`
///   • SUBMISSION build (dev toggle OFF):
///       `flutter build ipa --release --dart-define-from-file=env.json
///        --dart-define=USORA_DEV=false`
const bool kShowDevTools =
    kDebugMode || bool.fromEnvironment('USORA_DEV', defaultValue: true);

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
