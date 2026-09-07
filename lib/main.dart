import 'package:flutter/material.dart';

import 'core/supabase/supabase_client.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseInit.ensureInitialized();
  runApp(const BondApp());
}

class BondApp extends StatelessWidget {
  const BondApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOND',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _FoundationScreen(),
    );
  }
}

/// Layer 1 placeholder. Confirms the app builds, the theme applies, and
/// Supabase initialized. Auth + couple-linking replace this next.
class _FoundationScreen extends StatelessWidget {
  const _FoundationScreen();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('BOND', style: textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Foundation ready — Supabase connected.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
