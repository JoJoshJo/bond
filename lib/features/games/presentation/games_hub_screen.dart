import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/game_controller.dart';
import '../../../shared/utils/error_messages.dart';
import '../data/game_definitions.dart';
import 'game_play_screen.dart';

/// The Games hub: the launch catalog. Tapping a game starts a fresh session or
/// resumes the couple's unfinished one, then opens play.
class GamesHubScreen extends ConsumerStatefulWidget {
  const GamesHubScreen({super.key});

  @override
  ConsumerState<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends ConsumerState<GamesHubScreen> {
  String? _starting;

  Future<void> _open(GameDefinition def) async {
    setState(() => _starting = def.type);
    try {
      final session =
          await ref.read(gameRepositoryProvider).startOrResume(def.type);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GamePlayScreen(sessionId: session.id),
      ));
    } catch (error, stack) {
      // Keep the real error in logs; show the user a clean message.
      debugPrint('start_or_resume_game failed: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _starting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BondScaffold(
      title: 'Games',
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text('Play together — on your own time.',
              style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.lg),
          for (final def in GameCatalog.all) ...[
            BondCard(
              onTap: _starting == null ? () => _open(def) : null,
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.mintWash,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(def.icon, color: AppColors.mint),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(def.title, style: AppText.title),
                        Text(def.tagline, style: AppText.bodySmall),
                      ],
                    ),
                  ),
                  if (_starting == def.type)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.mint),
                    )
                  else
                    const Icon(Icons.chevron_right, color: AppColors.inkFaint),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
