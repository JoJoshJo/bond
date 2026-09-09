import 'package:shared_preferences/shared_preferences.dart';

/// Persists the chosen theme key on-device (per-device, not per-couple) so each
/// partner keeps their own vibe. No DB, no SQL.
class ThemeRepository {
  ThemeRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'bond_theme';

  /// The saved theme key, or 'mint' if none.
  String load() => _prefs.getString(_key) ?? 'mint';

  Future<void> save(String key) => _prefs.setString(_key, key);
}
