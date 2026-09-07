import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads/writes the `public.users` profile row (created by the
/// `on_auth_user_created` trigger at signup).
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  /// Silently capture the device's IANA timezone into `users.home_timezone`
  /// if it isn't set yet. No UI — called right after first sign-in. Best-effort:
  /// failures are swallowed so they never block the auth flow.
  Future<void> captureHomeTimezoneIfMissing() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final row = await _client
          .from('users')
          .select('home_timezone')
          .eq('id', user.id)
          .maybeSingle();

      final existing = row?['home_timezone'] as String?;
      if (existing != null && existing.isNotEmpty) return;

      final tz = await FlutterTimezone.getLocalTimezone();
      await _client
          .from('users')
          .update({'home_timezone': tz.identifier}).eq('id', user.id);
    } catch (_) {
      // Non-fatal: timezone can be re-captured later at couple setup.
    }
  }
}
