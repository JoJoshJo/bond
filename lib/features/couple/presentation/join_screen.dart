import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/error_messages.dart';
import '../../../shared/utils/haptics.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/couple_providers.dart';

/// Partner B joins here: scan A's QR (zero-typing, in person) or type the
/// 6-digit code (remote). Both paths normalize to digits and call join_couple().
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  // QR-only controller; scanning any other barcode format is ignored.
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _scanner.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Pull the 6-digit code out of any scanned/typed value: strip non-digits
  /// (so "1 2 3 4 5 6", "usora:123456", or a bare "123456" all normalize) and
  /// take the first 6 digits.
  String _sanitize(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length > 6 ? digits.substring(0, 6) : digits;
  }

  Future<void> _onScan(BarcodeCapture capture) async {
    if (_busy) return; // The busy flag alone gates re-fires (no manual stop()).
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    final code = _sanitize(raw);
    if (code.length != 6) return; // Not a Usora invite QR — keep scanning.
    await _join(code);
  }

  Future<void> _submitCode() async {
    final code = _sanitize(_codeController.text);
    if (code.length != 6) return;
    await _join(code);
  }

  Future<void> _join(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(coupleRepositoryProvider).joinCouple(code);
      if (!mounted) return;
      if (result.ok) {
        Haptics.success(); // you're linked 🎉
        await _scanner.stop(); // Free the camera right before we leave.
        if (!mounted) return;
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
      // Camera keeps running (never stopped on failure), so re-scanning just
      // works once _busy clears — the v7 lifecycle stays with the widget.
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(String? reason) {
    switch (reason) {
      case 'consumed':
      case 'already_complete':
        return 'This couple is already complete.';
      case 'revoked':
        return 'This invite code is no longer active — ask for a new one.';
      case 'expired':
        return 'This invite has expired — ask for a fresh code.';
      case 'already_in_couple':
        return 'You\'re already linked with someone.';
      case 'invalid':
        return 'That invite code isn\'t valid. Double-check and try again.';
      default:
        return 'Couldn\'t join with that code. Try again.';
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
            // Rebuild on each keystroke so "Join" enables at exactly 6 digits.
            StatefulBuilder(
              builder: (ctx, setSheetState) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BondTextField(
                    controller: _codeController,
                    label: '6-digit code',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (_) => setSheetState(() {}),
                    onFieldSubmitted: (_) {
                      if (_sanitize(_codeController.text).length == 6) {
                        Navigator.of(ctx).pop();
                        _submitCode();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  BondButton(
                    label: 'Join',
                    onPressed: _sanitize(_codeController.text).length == 6
                        ? () {
                            Navigator.of(ctx).pop();
                            _submitCode();
                          }
                        : null,
                  ),
                ],
              ),
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
                      errorBuilder: (context, error) => _CameraError(
                        onRetry: () => _scanner.start(),
                      ),
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
                  if (_busy) const CircularProgressIndicator(),
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

/// Shown when the camera can't start (permission denied, unavailable, etc.).
class _CameraError extends StatelessWidget {
  const _CameraError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_rounded,
              color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Camera unavailable — enable camera access in Settings, '
            'or enter the code instead.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
