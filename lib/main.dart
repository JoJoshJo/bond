import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/purchases/purchase_service.dart';
import 'core/push/push_service.dart';
import 'core/supabase/supabase_client.dart';
import 'features/appearance/application/theme_providers.dart';
import 'features/appearance/data/theme_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/spicy/application/spicy_providers.dart';
import 'shared/theme/app_colors.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/bond_themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseInit.ensureInitialized();

  // Load the saved theme BEFORE runApp and apply its palette up front, so the
  // first frame is already themed (no cold-start flash). Spicy isn't active at
  // cold start, so the chosen theme is the correct initial palette.
  final prefs = await SharedPreferences.getInstance();
  AppColors.active = paletteForKey(ThemeRepository(prefs).load());

  // Firebase + push. initializeApp() reads the native config files
  // (GoogleService-Info.plist / google-services.json) — no firebase_options
  // needed for iOS/Android. The background handler must be registered here.
  //
  // Defense-in-depth: a Firebase/push failure (e.g. a missing/unbundled native
  // config file) must NEVER block the app from launching. We log and continue —
  // push degrades gracefully, but the UI always renders.
  final push = PushService(supabase);
  var pushReady = false;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await push.init();
    pushReady = true;
  } catch (e, st) {
    debugPrint('Firebase/push init failed — continuing without push: $e\n$st');
  }

  // RevenueCat (iOS-only for now; no-op on Android / without a key). Identify
  // the RC user by their Supabase user id, kept in sync with auth.
  final purchases = PurchaseService();
  await purchases.configure();
  final existing = supabase.auth.currentSession?.user.id;
  if (existing != null) {
    await purchases.logIn(existing);
    if (pushReady) {
      await push.registerForCurrentUser(); // register token for an already-signed-in user
    }
  }
  supabase.auth.onAuthStateChange.listen((data) {
    final uid = data.session?.user.id;
    if (uid != null) {
      purchases.logIn(uid);
      if (pushReady) push.registerForCurrentUser();
    } else {
      purchases.logOut();
      if (pushReady) push.clearForCurrentUser();
    }
  });

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const BondApp(),
  ));
}

class BondApp extends ConsumerWidget {
  const BondApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Palette precedence: spicy mode (red room) overrides the chosen theme;
    // otherwise the chosen theme; unknown/none → mint. Setting the active
    // palette here re-themes every screen at once when either changes.
    final spicy = ref.watch(spicyActiveProvider);
    final themeKey = ref.watch(themeControllerProvider);
    AppColors.active = spicy ? redRoomPalette : paletteForKey(themeKey);

    return MaterialApp(
      title: 'Usora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const AuthGate(),
    );
  }
}
