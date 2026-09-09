import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
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
  DateTime? _dob;
  bool _agreedTerms = false;
  bool _loading = false;
  bool _obscure = true;

  /// The latest DOB that still makes someone exactly 18 today.
  static DateTime _maxDob() {
    final now = DateTime.now();
    return DateTime(now.year - 18, now.month, now.day);
  }

  /// True once a DOB is set and it clears the 18+ bar (exact, month/day aware).
  bool get _isAdult => _dob != null && !_dob!.isAfter(_maxDob());

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

  Future<void> _pickDob() async {
    final maxDob = _maxDob();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? maxDob,
      firstDate: DateTime(1920),
      lastDate: maxDob, // calendar can't offer an under-18 date
      helpText: 'Your date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _formatDob(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Declared-age gate: block anyone under 18 (belt-and-suspenders — the
    // picker already caps the selectable range).
    if (!_isAdult) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be 18 or older to use BOND.')),
      );
      return;
    }
    if (!_agreedTerms) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            data: {'birth_date': _formatDob(_dob!)},
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
          const SizedBox(height: 14),
          _DobField(
            dob: _dob,
            label: _dob == null ? 'Date of birth' : _formatDob(_dob!),
            onTap: _pickDob,
          ),
          const SizedBox(height: 4),
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
                    style: TextStyle(
                        color: AppColors.mintDeep,
                        fontWeight: FontWeight.w600),
                    recognizer: _termsTap,
                  ),
                  const TextSpan(text: ' & '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
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

/// A tappable, read-only "Date of birth" field that opens the date picker.
/// Doubles as the 18+ age gate — the picker itself caps the selectable range.
class _DobField extends StatelessWidget {
  const _DobField({
    required this.dob,
    required this.label,
    required this.onTap,
  });

  final DateTime? dob;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSet = dob != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, color: AppColors.inkFaint, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppText.bodyLarge.copyWith(
                    color: isSet ? AppColors.ink : AppColors.inkFaint),
              ),
            ),
            Icon(Icons.expand_more, color: AppColors.inkFaint),
          ],
        ),
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
