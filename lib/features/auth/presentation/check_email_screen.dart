import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/error_messages.dart';
import '../../../shared/widgets/widgets.dart';

/// Shown right after signup. With "Confirm email" ON, the user must click the
/// link in their inbox before a session exists. They then return and sign in
/// (deep-link auto-login comes with the OAuth task).
class CheckEmailScreen extends ConsumerStatefulWidget {
  const CheckEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> {
  bool _resending = false;

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent again.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Icon(Icons.mark_email_unread_outlined,
                  size: 64, color: AppColors.mint),
              const SizedBox(height: 24),
              Text('Check your email', style: textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to ${widget.email}. '
                'Tap it to confirm your account, then come back and sign in.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              BondButton(
                label: 'Resend email',
                loading: _resending,
                onPressed: _resend,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
