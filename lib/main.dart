import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/supabase/supabase_client.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/spicy/application/spicy_providers.dart';
import 'shared/theme/app_colors.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseInit.ensureInitialized();
  runApp(const ProviderScope(child: BondApp()));
}

class BondApp extends ConsumerWidget {
  const BondApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Spicy mode flips the whole-app palette to the "red room". Setting the
    // active palette here (then building the theme from it) re-themes every
    // screen at once when the flag changes.
    final spicy = ref.watch(spicyActiveProvider);
    AppColors.active = spicy ? redRoomPalette : mintPalette;

    return MaterialApp(
      title: 'BOND',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const AuthGate(),
    );
  }
}
