import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_providers.dart';
import '../../couple/application/couple_providers.dart';
import '../data/subscription_repository.dart';
import 'purchase_providers.dart';

/// Free tier keeps up to this many memories; Usora+ is unlimited.
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
  final repo = ref.watch(subscriptionRepositoryProvider);

  // Realtime: when the RC webhook writes the couple's subscription row, refresh
  // this provider so BOTH partners flip to premium within seconds.
  final channel =
      repo.channel(membership.coupleId, onChange: ref.invalidateSelf)
        ..subscribe();
  ref.onDispose(() => repo.removeChannel(channel));

  return repo.entitlementFor(membership.coupleId);
});

/// DEV ONLY — a local override so premium can be tested on-device without a real
/// RevenueCat purchase. `null` = use the real entitlement; `true`/`false` =
/// force. In-memory (resets on app restart). Remove this together with the dev
/// toggle in the Us tab when RevenueCat purchase is wired in.
final premiumDevOverrideProvider = StateProvider<bool?>((ref) => null);

/// THE SINGLE SOURCE OF TRUTH for "is this couple Usora+?". Every gate reads this.
///
/// Order: dev override → RevenueCat (`usora` entitlement, the buyer's instant
/// unlock) → the subscriptions table (couple-shared, written by the RC webhook,
/// so BOTH partners unlock). Defaults to **false while loading** so gates fail
/// locked (never accidentally unlock premium).
final isPremiumProvider = Provider<bool>((ref) {
  // The dev override only has power in DEBUG builds — in a release build it can
  // never force premium true (the toggle is also compiled out of the UI).
  final override = ref.watch(premiumDevOverrideProvider);
  if (kDebugMode && override != null) return override;
  if (ref.watch(revenueCatPremiumProvider)) return true;
  final entitlement = ref.watch(entitlementProvider);
  return entitlement.asData?.value == SubscriptionRepository.entitlementPlus;
});
