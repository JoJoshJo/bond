import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../application/couple_providers.dart';
import '../data/couple_name_generator.dart';
import 'join_screen.dart';

/// First screen for a signed-in user with no couple: create one, or join a
/// partner's invite.
class CreateOrJoinScreen extends ConsumerStatefulWidget {
  const CreateOrJoinScreen({super.key});

  @override
  ConsumerState<CreateOrJoinScreen> createState() => _CreateOrJoinScreenState();
}

class _CreateOrJoinScreenState extends ConsumerState<CreateOrJoinScreen> {
  bool _creating = false;

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final name = CoupleNameGenerator.generate();
      await ref.read(coupleRepositoryProvider).createCouple(name);
      // Re-resolve membership → CoupleGate routes to the waiting screen.
      ref.invalidate(myMembershipProvider);
    } catch (error, stack) {
      // Keep the real error in logs for debugging; show the user a friendly one.
      debugPrint('create_couple failed: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  height: 88,
                  width: 88,
                  decoration: BoxDecoration(
                    color: AppColors.mintSoft,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(Icons.link_rounded,
                      size: 44, color: AppColors.mint),
                ),
              ),
              const SizedBox(height: 24),
              Text('Link up', textAlign: TextAlign.center,
                  style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'BOND is for two. Start your space and invite your partner, '
                'or join the invite they sent you.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
              const Spacer(),
              AuthPrimaryButton(
                label: 'Create our space',
                loading: _creating,
                onPressed: _create,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _creating
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const JoinScreen(),
                          ),
                        ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Join my partner'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
