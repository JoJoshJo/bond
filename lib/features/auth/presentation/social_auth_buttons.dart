import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/error_messages.dart';
import '../application/auth_providers.dart';

/// Shared "Continue with Apple / Google" buttons shown on the Welcome screen for
/// both the sign-in and sign-up tabs. On success the auth stream fires and the
/// AuthGate re-routes — no manual navigation here.
///
/// Apple's button follows the HIG (solid black, white Apple mark + label) and is
/// only shown on iOS/macOS where Sign in with Apple is available; Google is shown
/// on every platform.
class SocialAuthButtons extends ConsumerStatefulWidget {
  const SocialAuthButtons({super.key});

  @override
  ConsumerState<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends ConsumerState<SocialAuthButtons> {
  bool _appleLoading = false;
  bool _googleLoading = false;

  bool get _busy => _appleLoading || _googleLoading;

  Future<void> _apple() async {
    setState(() => _appleLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
    } on SignInWithAppleAuthorizationException catch (e) {
      // User tapped Cancel — not an error worth a snackbar.
      if (e.code != AuthorizationErrorCode.canceled) _showError(e);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _googleLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyError(error))),
    );
  }

  bool get _showApple => Platform.isIOS || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        if (_showApple) ...[
          _SocialButton(
            label: 'Continue with Apple',
            background: Colors.black,
            foreground: Colors.white,
            loading: _appleLoading,
            onPressed: _busy ? null : _apple,
            leading: const Icon(Icons.apple, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        _SocialButton(
          label: 'Continue with Google',
          background: Colors.white,
          foreground: const Color(0xFF1F1F1F),
          border: const Color(0xFFDADCE0),
          loading: _googleLoading,
          onPressed: _busy ? null : _google,
          leading: SvgPicture.string(_googleGLogo, height: 20, width: 20),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.loading,
    required this.onPressed,
    required this.leading,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final bool loading;
  final VoidCallback? onPressed;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: loading ? null : onPressed,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: border != null ? Border.all(color: border!) : null,
            ),
            child: loading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: foreground),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The official multi-color Google "G" mark, inlined as SVG so no asset file or
/// network fetch is needed.
const String _googleGLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';
