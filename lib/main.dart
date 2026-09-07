import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/supabase/supabase_client.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseInit.ensureInitialized();
  runApp(const ProviderScope(child: BondApp()));
}

class BondApp extends StatelessWidget {
  const BondApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOND',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
