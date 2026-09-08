import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/theme/app_colors.dart';
import 'creature_chat_sheet.dart';

/// Whether the floating assistant shows. On by default; toggled in Us settings.
/// (Session-only for now; persistence lands later.)
final assistantFloatingEnabledProvider = StateProvider<bool>((ref) => true);

/// Floating quick-access to the creature. Tap → a conversation with it (type or
/// hold-to-speak). Tap-only; it never interrupts.
class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.mint,
      foregroundColor: AppColors.onMint,
      onPressed: () => CreatureChatSheet.open(context, coupleId),
      child: const Icon(Icons.auto_awesome),
    );
  }
}
