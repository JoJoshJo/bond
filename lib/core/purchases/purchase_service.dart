import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';

enum PurchaseOutcome { success, pending, cancelled, error, unavailable }

/// Thin wrapper over the RevenueCat SDK. iOS-only for now (we only hold the
/// Apple key); on Android / without a key it's inert and every call is a safe
/// no-op, so premium falls back to the subscriptions table + dev override.
///
/// Config state is static because the underlying `Purchases` API is a process
/// singleton — so `main()` and the Riverpod provider share the same state.
class PurchaseService {
  static const entitlementId = 'usora'; // RC entitlement that means Usora+
  static const monthlyProductId = 'usora_plus_monthly';

  static bool _configured = false;
  bool get available => _configured;

  /// Configure RevenueCat once, at app start. iOS-only; no-op otherwise.
  Future<void> configure() async {
    if (_configured) return;
    if (!Platform.isIOS) return;
    if (AppConfig.revenueCatAppleKey.isEmpty) return;
    await Purchases.setLogLevel(LogLevel.info);
    await Purchases.configure(
        PurchasesConfiguration(AppConfig.revenueCatAppleKey));
    _configured = true;
  }

  /// Tie the RC App User ID to the Supabase user id (stable, cross-device).
  Future<void> logIn(String userId) async {
    if (!_configured) return;
    try {
      await Purchases.logIn(userId);
    } catch (_) {/* non-fatal */}
  }

  Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (_) {/* non-fatal */}
  }

  void addCustomerInfoListener(void Function(CustomerInfo) cb) {
    if (!_configured) return;
    Purchases.addCustomerInfoUpdateListener(cb);
  }

  static bool isPremiumFrom(CustomerInfo info) =>
      info.entitlements.active.containsKey(entitlementId);

  Future<bool> currentPremium() async {
    if (!_configured) return false;
    try {
      return isPremiumFrom(await Purchases.getCustomerInfo());
    } catch (_) {
      return false;
    }
  }

  /// The `usora_plus_monthly` package from the `default` offering (or the
  /// offering's monthly slot / first package as a fallback). Null when RC isn't
  /// available or the offering can't be fetched.
  Future<Package?> monthlyPackage() async {
    if (!_configured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current ?? offerings.all['default'];
      if (offering == null) return null;
      for (final p in offering.availablePackages) {
        if (p.storeProduct.identifier == monthlyProductId) return p;
      }
      return offering.monthly ??
          (offering.availablePackages.isNotEmpty
              ? offering.availablePackages.first
              : null);
    } catch (_) {
      return null;
    }
  }

  Future<PurchaseOutcome> purchase(Package package) async {
    if (!_configured) return PurchaseOutcome.unavailable;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return isPremiumFrom(result.customerInfo)
          ? PurchaseOutcome.success
          : PurchaseOutcome.pending;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      return PurchaseOutcome.error;
    } catch (_) {
      return PurchaseOutcome.error;
    }
  }

  /// Restore prior purchases (Apple-required). Returns true if Usora+ is active
  /// afterward.
  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      return isPremiumFrom(await Purchases.restorePurchases());
    } catch (_) {
      return false;
    }
  }
}
