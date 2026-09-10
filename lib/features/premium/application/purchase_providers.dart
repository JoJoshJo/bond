import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/purchases/purchase_service.dart';

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => PurchaseService(),
);

/// Whether RevenueCat reports the `usora` entitlement active for the current
/// user. Seeded from `getCustomerInfo`, then kept live by the update listener.
/// Always false on Android / when RC isn't configured.
class RcPremiumController extends StateNotifier<bool> {
  RcPremiumController(this._svc) : super(false) {
    _init();
  }

  final PurchaseService _svc;

  Future<void> _init() async {
    _svc.addCustomerInfoListener((info) {
      if (mounted) state = PurchaseService.isPremiumFrom(info);
    });
    final premium = await _svc.currentPremium();
    if (mounted) state = premium;
  }
}

final revenueCatPremiumProvider =
    StateNotifierProvider<RcPremiumController, bool>(
  (ref) => RcPremiumController(ref.watch(purchaseServiceProvider)),
);

/// The `usora_plus_monthly` package (with live price) for the paywall. Null when
/// RC isn't available (Android / no offering) → the paywall uses its fallback.
final monthlyPackageProvider = FutureProvider.autoDispose<Package?>(
  (ref) => ref.watch(purchaseServiceProvider).monthlyPackage(),
);
