import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/error_messages.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/couple_providers.dart';

/// Partner B joins here: scan A's QR (zero-typing, in person) or paste the code
/// (long-distance, until deep links land). Both paths call join_couple().
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _scanner = MobileScannerController();
  final _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _scanner.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Accepts a raw token or an invite URL; returns the bare token.
  String _extractToken(String raw) {
    final value = raw.trim();
    if (value.contains('/invite/')) {
      return value.split('/invite/').last.split(RegExp(r'[/?#]')).first;
    }
    return value;
  }

  Future<void> _onScan(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    await _join(_extractToken(raw));
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    await _join(_extractToken(code));
  }

  Future<void> _join(String token) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _scanner.stop();
    try {
      final result = await ref.read(coupleRepositoryProvider).joinCouple(token);
      if (!mounted) return;
      if (result.ok) {
        ref.invalidate(myMembershipProvider); // CoupleGate → Home.
        Navigator.of(context).pop();
        return;
      }
      await _showDeadLink(_messageFor(result.reason));
    } catch (error) {
      if (mounted) {
        await _showDeadLink(friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _scanner.start();
      }
    }
  }

  String _messageFor(String? reason) {
    switch (reason) {
      case 'consumed':
      case 'already_complete':
        return 'This couple is already complete.';
      case 'revoked':
        return 'This invite link is no longer active — ask for a new one.';
      case 'expired':
        return 'This invite has expired — ask for a fresh link.';
      case 'already_in_couple':
        return 'You\'re already linked with someone.';
      case 'invalid':
        return 'That invite code isn\'t valid. Double-check and try again.';
      default:
        return 'Couldn\'t join with that invite. Try again.';
    }
  }

  Future<void> _showDeadLink(String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _enterCodeSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enter invite code',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            BondTextField(
              controller: _codeController,
              label: 'Invite code',
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                Navigator.of(ctx).pop();
                _submitCode();
              },
            ),
            const SizedBox(height: 16),
            BondButton(
              label: 'Join',
              onPressed: () {
                Navigator.of(ctx).pop();
                _submitCode();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Join your partner'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: MobileScanner(
                      controller: _scanner,
                      onDetect: _onScan,
                    ),
                  ),
                  // Simple reticle.
                  Container(
                    height: 240,
                    width: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.mint, width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  if (_busy)
                    const CircularProgressIndicator(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Point at your partner\'s QR code.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _enterCodeSheet,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Enter code instead'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
