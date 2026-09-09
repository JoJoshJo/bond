import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/theme_repository.dart';

/// Overridden in main() with the instance loaded before runApp (so the saved
/// theme is applied on the very first frame — no cold-start flash).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => ThemeRepository(ref.watch(sharedPreferencesProvider)),
);

/// The chosen theme key (e.g. 'mint', 'sunset'). Seeded synchronously from the
/// saved value; [ThemeController.select] applies + persists. The app palette is
/// resolved from this in main() (with spicy taking precedence).
class ThemeController extends StateNotifier<String> {
  ThemeController(this._repo) : super(_repo.load());

  final ThemeRepository _repo;

  void select(String key) {
    if (key == state) return;
    state = key;
    _repo.save(key);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, String>(
  (ref) => ThemeController(ref.watch(themeRepositoryProvider)),
);
