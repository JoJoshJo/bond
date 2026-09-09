import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/error_messages.dart';
import '../../../shared/widgets/widgets.dart';

/// Sends a Supabase password-reset email. Completing the reset (entering a new
/// password in-app) needs deep-link recovery, which lands with the OAuth task —
/// for now this sends the email and confirms it was sent.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail ?? '');
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
          child: _sent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Icon(Icons.mark_email_read_outlined,
                        size: 64, color: AppColors.mint),
                    const SizedBox(height: 24),
                    Text('Check your email', style: textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text(
                      'If an account exists for ${_email.text.trim()}, we sent a '
                      'link to reset your password.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    BondButton(
                      label: 'Back to sign in',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text('Reset your password',
                          style: textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Text(
                        'Enter your email and we\'ll send you a reset link.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      BondTextField(
                        controller: _email,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) =>
                            (v == null || !v.contains('@') || !v.contains('.'))
                                ? 'Enter a valid email'
                                : null,
                        onFieldSubmitted: (_) => _send(),
                      ),
                      const SizedBox(height: 24),
                      BondButton(
                        label: 'Send reset link',
                        loading: _sending,
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
