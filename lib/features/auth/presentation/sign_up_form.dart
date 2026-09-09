import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/error_messages.dart';
import '../../../shared/widgets/widgets.dart';
import '../../legal/presentation/legal_screen.dart';
import '../application/auth_providers.dart';
import 'check_email_screen.dart';

/// Email + password sign-up with an 18+ age gate and terms agreement.
/// With "Confirm email" ON, signup creates the user but no session; we route to
/// [CheckEmailScreen]. The `on_auth_user_created` trigger creates the profile row.
class SignUpForm extends ConsumerStatefulWidget {
  const SignUpForm({super.key});

  @override
  ConsumerState<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _isAdult = false;
  bool _agreedTerms = false;
  bool _loading = false;
  bool _obscure = true;

  final _termsTap = TapGestureRecognizer();
  final _privacyTap = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _termsTap.onTap = () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LegalScreen.terms()));
    _privacyTap.onTap = () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LegalScreen.privacy()));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  bool get _canSubmit => _isAdult && _agreedTerms && !_loading;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isAdult || !_agreedTerms) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
          );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CheckEmailScreen(email: _email.text.trim()),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BondTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: (v) =>
                (v == null || !v.contains('@') || !v.contains('.'))
                    ? 'Enter a valid email'
                    : null,
          ),
          const SizedBox(height: 14),
          BondTextField(
            controller: _password,
            label: 'Password',
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => (v == null || v.length < 6)
                ? 'At least 6 characters'
                : null,
            suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 14),
          BondTextField(
            controller: _confirm,
            label: 'Confirm password',
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            validator: (v) =>
                (v != _password.text) ? 'Passwords don\'t match' : null,
            onFieldSubmitted: (_) => _canSubmit ? _submit() : null,
          ),
          const SizedBox(height: 8),
          _CheckRow(
            value: _isAdult,
            onChanged: (v) => setState(() => _isAdult = v ?? false),
            child: const Text('I confirm I am 18 or older'),
          ),
          _CheckRow(
            value: _agreedTerms,
            onChanged: (v) => setState(() => _agreedTerms = v ?? false),
            child: Text.rich(
              TextSpan(
                style: AppText.bodyMedium,
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                        color: AppColors.mintDeep,
                        fontWeight: FontWeight.w600),
                    recognizer: _termsTap,
                  ),
                  const TextSpan(text: ' & '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                        color: AppColors.mintDeep,
                        fontWeight: FontWeight.w600),
                    recognizer: _privacyTap,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          BondButton(
            label: 'Create account',
            loading: _loading,
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.onChanged,
    required this.child,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.mint,
              checkColor: AppColors.ink,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
