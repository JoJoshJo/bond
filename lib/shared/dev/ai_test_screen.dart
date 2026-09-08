import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai/application/ai_providers.dart';
import '../../features/ai/data/ai_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/widgets.dart';

/// TEMPORARY dev proof: sends a prompt through the ai-router Edge Function →
/// Gemini → and shows the response + which provider/model served it. Confirms
/// the whole pipeline end-to-end before the creature (Piece 2) builds on it.
class AiTestScreen extends ConsumerStatefulWidget {
  const AiTestScreen({super.key});

  @override
  ConsumerState<AiTestScreen> createState() => _AiTestScreenState();
}

class _AiTestScreenState extends ConsumerState<AiTestScreen> {
  final _controller = TextEditingController(text: 'Say hi to a couple in one warm sentence.');
  bool _loading = false;
  AiResponse? _response;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    setState(() {
      _loading = true;
      _error = null;
      _response = null;
    });
    try {
      final res = await ref
          .read(aiRepositoryProvider)
          .getAI('assistant', _controller.text.trim());
      setState(() => _response = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BondScaffold(
      title: 'AI router test',
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text('Sends a prompt through the ai-router Edge Function → Gemini.',
              style: AppText.bodySmall),
          const SizedBox(height: AppSpacing.md),
          BondTextField(controller: _controller, label: 'Prompt'),
          const SizedBox(height: AppSpacing.md),
          BondButton(label: 'Ask the router', loading: _loading, onPressed: _ask),
          const SizedBox(height: AppSpacing.xl),
          if (_error != null)
            BondCard(
              color: AppColors.errorBg,
              elevated: false,
              child: Text(_error!, style: AppText.bodyMedium),
            ),
          if (_response != null) ...[
            BondCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RESPONSE',
                      style: AppText.bodySmall.copyWith(
                          color: AppColors.mintDeep,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_response!.text, style: AppText.bodyLarge),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            BondChip(
              label: 'served by ${_response!.provider} · ${_response!.model}',
              tone: BondChipTone.mint,
            ),
          ],
        ],
      ),
    );
  }
}
