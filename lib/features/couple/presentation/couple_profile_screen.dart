import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';

import '../../../shared/dev/ai_test_screen.dart';
import '../../../shared/dev/style_gallery_screen.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/utils/error_messages.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../creature/presentation/assistant_stub.dart';
import '../../legal/presentation/credits_screen.dart';
import '../../legal/presentation/legal_screen.dart';
import '../../appearance/presentation/appearance_screen.dart';
import '../../calendar/presentation/calendar_screen.dart';
import '../../insights/presentation/insights_screen.dart';
import '../../premium/application/entitlement_providers.dart';
import '../../premium/presentation/paywall_screen.dart';
import '../../spicy/presentation/spicy_section.dart';
import '../application/couple_providers.dart';

/// The "Us" tab: couple identity + settings. Rename the space, set the start
/// date, the privacy promise, the floating-assistant toggle, dev tools, sign out.
class CoupleProfileScreen extends ConsumerStatefulWidget {
  const CoupleProfileScreen({
    super.key,
    required this.coupleId,
    required this.coupleName,
  });

  final String coupleId;
  final String coupleName;

  @override
  ConsumerState<CoupleProfileScreen> createState() =>
      _CoupleProfileScreenState();
}

class _CoupleProfileScreenState extends ConsumerState<CoupleProfileScreen> {
  late String _name = widget.coupleName;
  bool _deleting = false;

  Future<void> _rename() async {
    final controller = TextEditingController(text: _name);
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenPad,
          right: AppSpacing.screenPad,
          top: AppSpacing.xxl,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Name your space', style: AppText.title),
            const SizedBox(height: AppSpacing.md),
            BondTextField(controller: controller, label: 'Couple name'),
            const SizedBox(height: AppSpacing.lg),
            BondButton(
              label: 'Save',
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    if (newName == null || newName.isEmpty || newName == _name) return;
    setState(() => _name = newName);
    try {
      await ref
          .read(coupleRepositoryProvider)
          .updateCoupleName(widget.coupleId, newName);
      ref.invalidate(myMembershipProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1990),
      lastDate: now,
    );
    if (picked == null) return;
    try {
      await ref
          .read(coupleRepositoryProvider)
          .updateRelationshipStartDate(widget.coupleId, picked);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Start date saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final floating = ref.watch(assistantFloatingEnabledProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('Us', style: AppText.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPad),
          children: [
            BondCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Our space', style: AppText.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_name, style: AppText.headline),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _section('Settings'),
            BondCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  BondListTile(
                    leadingIcon: Icons.favorite_border_rounded,
                    title: 'Rename our space',
                    onTap: _rename,
                    trailing: Icon(Icons.chevron_right,
                        color: AppColors.inkFaint),
                  ),
                  const Divider(),
                  BondListTile(
                    leadingIcon: Icons.calendar_today_rounded,
                    title: 'Relationship start date',
                    onTap: _pickStartDate,
                    trailing: Icon(Icons.chevron_right,
                        color: AppColors.inkFaint),
                  ),
                  const Divider(),
                  SwitchListTile(
                    value: floating,
                    title: Text('Floating assistant', style: AppText.bodyLarge),
                    subtitle: Text('Quick-access creature button',
                        style: AppText.bodySmall),
                    onChanged: (v) => ref
                        .read(assistantFloatingEnabledProvider.notifier)
                        .state = v,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _section('Privacy'),
            BondCard(
              color: AppColors.mintWash,
              elevated: false,
              child: Text(
                'We never sell your data, never train AI on it, and only the two '
                'of you can ever see your stuff. 🤍',
                style: AppText.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _section('Membership'),
            BondCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: BondListTile(
                leadingIcon: Icons.workspace_premium_rounded,
                title: isPremium ? 'Usora+ · active' : 'Upgrade to Usora+',
                subtitle: isPremium
                    ? 'Thanks for supporting Usora 🤍'
                    : 'Unlimited memories, a fully custom creature & more',
                onTap: () => PaywallScreen.open(context),
                trailing: Icon(Icons.chevron_right,
                    color: AppColors.inkFaint),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _section('Planning'),
            BondCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  BondListTile(
                    leadingIcon: Icons.calendar_month_rounded,
                    title: 'Shared calendar',
                    subtitle: isPremium
                        ? 'Your dates, anniversaries & plans'
                        : 'Plan your dates together · Usora+',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            CalendarScreen(coupleId: widget.coupleId))),
                    trailing:
                        Icon(Icons.chevron_right, color: AppColors.inkFaint),
                  ),
                  const Divider(),
                  BondListTile(
                    leadingIcon: Icons.insights_rounded,
                    title: 'Relationship insights',
                    subtitle: isPremium
                        ? 'Your bond over time'
                        : 'See your bond over time · Usora+',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            InsightsScreen(coupleId: widget.coupleId))),
                    trailing:
                        Icon(Icons.chevron_right, color: AppColors.inkFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _section('Personalize'),
            BondCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: BondListTile(
                leadingIcon: Icons.palette_rounded,
                title: 'Appearance',
                subtitle: isPremium
                    ? 'Pick your theme'
                    : 'Premium color themes · Usora+',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AppearanceScreen())),
                trailing: Icon(Icons.chevron_right, color: AppColors.inkFaint),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _section('Spicy'),
            const SpicySection(),
            const SizedBox(height: AppSpacing.lg),
            // BETA-ONLY dev tools — shown in debug + TestFlight (kBetaBuild),
            // compiled out of the App Store production build.
            if (kBetaBuild) ...[
            _section('Developer'),
            BondCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  BondListTile(
                    leadingIcon: Icons.palette_outlined,
                    title: 'Design system',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const StyleGalleryScreen())),
                  ),
                  const Divider(),
                  BondListTile(
                    leadingIcon: Icons.smart_toy_outlined,
                    title: 'AI router test',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AiTestScreen())),
                  ),
                  const Divider(),
                  // DEV ONLY — forces the premium entitlement so both states are
                  // testable without a real purchase. Remove with the paywall's
                  // RevenueCat wiring (see premiumDevOverrideProvider).
                  SwitchListTile(
                    value: isPremium,
                    title: Text('DEV: Usora+ override', style: AppText.bodyLarge),
                    subtitle: Text('Force premium on/off (dev only)',
                        style: AppText.bodySmall),
                    onChanged: (v) => ref
                        .read(premiumDevOverrideProvider.notifier)
                        .state = v,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ],
            _section('Legal'),
            BondCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  BondListTile(
                    leadingIcon: Icons.description_outlined,
                    title: 'Terms of Service',
                    trailing: Icon(Icons.chevron_right,
                        color: AppColors.inkFaint),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LegalScreen.terms())),
                  ),
                  const Divider(),
                  BondListTile(
                    leadingIcon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    trailing: Icon(Icons.chevron_right,
                        color: AppColors.inkFaint),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LegalScreen.privacy())),
                  ),
                  const Divider(),
                  BondListTile(
                    leadingIcon: Icons.workspace_premium_outlined,
                    title: 'Credits',
                    trailing: Icon(Icons.chevron_right,
                        color: AppColors.inkFaint),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CreditsScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            BondButton(
              label: 'Sign out',
              variant: BondButtonVariant.secondary,
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _deleting ? null : _confirmDeleteAccount,
              child: Text(
                _deleting ? 'Deleting…' : 'Delete account',
                style: AppText.bodyMedium.copyWith(
                    color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }

  /// Two-step, explicit confirmation before a permanent, irreversible delete.
  Future<void> _confirmDeleteAccount() async {
    // Step 1 — the warning.
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete account?'),
        content: Text(
          'This permanently deletes your account and removes you from your '
          'shared space. This can\'t be undone.',
          style: AppText.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Continue', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    // Step 2 — the final, explicit confirm.
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Are you absolutely sure?'),
        content: Text(
          'Your account and your couple space will be deleted for good. Your '
          'partner\'s space will be closed and they can start over.',
          style: AppText.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete my account',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (step2 != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // On success the auth stream fires signed-out → AuthGate → WelcomeScreen.
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyError(e)),
        ));
      }
    }
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.xs),
        child: Text(label.toUpperCase(),
            style: AppText.bodySmall.copyWith(
                color: AppColors.mintDeep,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
      );
}
