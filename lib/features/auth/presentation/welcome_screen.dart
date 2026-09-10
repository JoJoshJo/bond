import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'sign_in_form.dart';
import 'sign_up_form.dart';

/// The entry screen: logo + warm hero, with Sign In / Sign Up on the SAME
/// screen via a segmented toggle (no intro carousel, per spec).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _tab = 0; // 0 = sign in, 1 = sign up

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Hero / logo mark — placeholder until brand art lands (Layer 2).
              Center(
                child: Container(
                  height: 96,
                  width: 96,
                  decoration: BoxDecoration(
                    color: AppColors.mintWash,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(Icons.favorite_rounded,
                      size: 48, color: AppColors.mint),
                ),
              ),
              const SizedBox(height: 20),
              Text('Usora',
                  textAlign: TextAlign.center,
                  style: textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'One space for the two of you.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 32),
              _SegmentedToggle(
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 24),
              // Keep both forms alive so field input isn't lost when toggling.
              IndexedStack(
                index: _tab,
                children: const [
                  SignInForm(),
                  SignUpForm(),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3ECE8)),
      ),
      child: Row(
        children: [
          _segment('Sign in', 0),
          _segment('Sign up', 1),
        ],
      ),
    );
  }

  Widget _segment(String label, int i) {
    final selected = index == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.mint : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.ink : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
