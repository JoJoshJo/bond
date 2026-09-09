import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_providers.dart';
import '../../couple/application/couple_providers.dart';
import '../data/subscription_repository.dart';

/// Free tier keeps up to this many memories; BOND+ is unlimited.
const int kFreeMemoryCap = 30;

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ref.watch(supabaseClientProvider)),
);

/// The current couple's entitlement (`'free'` | `'bond_plus'`), read from the
/// subscriptions table. Resolves to `'free'` when there's no couple yet or on
/// any read failure (fail-locked).
final entitlementProvider = FutureProvider<String>((ref) async {
  final membership = await ref.watch(myMembershipProvider.future);
  if (membership == null) return SubscriptionRepository.entitlementFree;
  return ref
      .watch(subscriptionRepositoryProvider)
      .entitlementFor(membership.coupleId);
});

/// DEV ONLY — a local override so premium can be tested on-device without a real
/// RevenueCat purchase. `null` = use the real entitlement; `true`/`false` =
/// force. In-memory (resets on app restart). Remove this together with the dev
/// toggle in the Us tab when RevenueCat purchase is wired in.
final premiumDevOverrideProvider = StateProvider<bool?>((ref) => null);

/// THE SINGLE SOURCE OF TRUTH for "is this couple BOND+?". Every gate reads this.
///
/// Honors the dev override first; otherwise reflects the real entitlement.
/// Defaults to **false while the entitlement is still loading** so gates fail
/// locked (never accidentally unlock premium).
final isPremiumProvider = Provider<bool>((ref) {
  final override = ref.watch(premiumDevOverrideProvider);
  if (override != null) return override;
  final entitlement = ref.watch(entitlementProvider);
  return entitlement.asData?.value == SubscriptionRepository.entitlementPlus;
});
