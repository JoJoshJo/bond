import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Initializes Supabase for the app. Call once in `main()` before `runApp`.
///
/// Reads the URL + anon key from [AppConfig], which are supplied at build time
/// via `--dart-define-from-file=env.json` (never committed).
class SupabaseInit {
  const SupabaseInit._();

  static Future<void> ensureInitialized() async {
    if (!AppConfig.isConfigured) {
      throw StateError(
        'Supabase is not configured. Run with '
        '`--dart-define-from-file=env.json` (copy env.example.json and fill in '
        'your SUPABASE_URL and SUPABASE_ANON_KEY).',
      );
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
}

/// Convenience accessor for the Supabase client after initialization.
SupabaseClient get supabase => Supabase.instance.client;
