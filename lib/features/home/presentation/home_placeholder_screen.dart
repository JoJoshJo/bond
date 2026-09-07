import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/dev/style_gallery_screen.dart';
import '../../../shared/theme/app_colors.dart';
import '../../auth/application/auth_providers.dart';

/// Temporary landing after successful auth. Couple-linking (the next task)
/// replaces this. For now it confirms the user is signed in and offers sign-out.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final email = ref.watch(sessionProvider)?.user.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 64, color: AppColors.mint),
              const SizedBox(height: 20),
              Text('You\'re linked',
                  textAlign: TextAlign.center, style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                email.isEmpty ? 'Signed in.' : 'Signed in as $email',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 8),
              Text(
                'Your space is set up. The app itself comes next.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 32),
              // TEMPORARY: on-device review of the design system.
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StyleGalleryScreen(),
                  ),
                ),
                child: const Text('View design system'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
