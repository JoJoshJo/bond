import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../auth/application/auth_providers.dart';
import '../../couple/application/couple_providers.dart';
import '../../premium/application/entitlement_providers.dart';
import '../data/spicy_repository.dart';

final spicyRepositoryProvider = Provider<SpicyRepository>(
  (ref) => SpicyRepository(ref.watch(supabaseClientProvider)),
);

/// The result of a toggle-on attempt, so the UI can react (open paywall, etc.).
enum SpicyActivateOutcome { activated, unlimited, cooldown, error }

class SpicyState {
  const SpicyState({
    this.loading = true,
    this.on = false,
    this.unlimited = false,
    this.expiresAt,
    this.cooldownUntil,
    this.justEnded = false,
    this.busy = false,
  });

  /// Whether spicy mode is currently ON in the app (drives the red-room theme,
  /// spicy games, and the flirty steer).
  final bool on;

  /// Premium: unlimited, no server window.
  final bool unlimited;

  /// Server-authoritative end of the current free session.
  final DateTime? expiresAt;

  /// Server-authoritative end of the cooldown (when locked out).
  final DateTime? cooldownUntil;

  /// Set true when a session just auto-expired, so the UI can show the prompt.
  final bool justEnded;

  final bool loading;
  final bool busy; // an activate() call is in flight

  bool get inCooldown =>
      !on && !unlimited && cooldownUntil != null &&
      cooldownUntil!.isAfter(DateTime.now());

  SpicyState copyWith({
    bool? loading,
    bool? on,
    bool? unlimited,
    Object? expiresAt = _s,
    Object? cooldownUntil = _s,
    bool? justEnded,
    bool? busy,
  }) =>
      SpicyState(
        loading: loading ?? this.loading,
        on: on ?? this.on,
        unlimited: unlimited ?? this.unlimited,
        expiresAt: expiresAt == _s ? this.expiresAt : expiresAt as DateTime?,
        cooldownUntil:
            cooldownUntil == _s ? this.cooldownUntil : cooldownUntil as DateTime?,
        justEnded: justEnded ?? this.justEnded,
        busy: busy ?? this.busy,
      );

  static const _s = Object();
}

/// Owns spicy-mode on/off, restoring the server's authoritative window on load
/// and auto-reverting when a free session expires. The server is always the
/// authority; the local timer is only UX.
class SpicyController extends StateNotifier<SpicyState> {
  SpicyController(this._repo, this._ref) : super(const SpicyState()) {
    _init();
  }

  final SpicyRepository _repo;
  final Ref _ref;
  Timer? _expiryTimer;
  RealtimeChannel? _channel;

  /// Initial load + a realtime subscription on the couple's spicy_mode row, so
  /// a partner's activation / expiry flips this app live (red room + countdown).
  Future<void> _init() async {
    await refresh();
    final membership = await _ref.read(myMembershipProvider.future);
    final coupleId = membership?.coupleId;
    if (coupleId == null || !mounted) return;
    _channel = _repo.channel(coupleId, onChange: refresh)..subscribe();
  }

  /// DEV-ONLY: the client-side premium override forces spicy to unlimited too,
  /// so the "DEV: Usora+" toggle unlocks spicy for testing. The real gate stays
  /// the server RPC (below) for production — free users keep the 3h/14-day
  /// limit and RC-premium gets unlimited server-side; this only short-circuits
  /// when someone explicitly flips the dev override.
  //
  // Honored only in BETA/TestFlight builds (kBetaBuild). When on, spicy is
  // treated as premium-unlimited locally — turnOn() short-circuits, bypassing
  // the 3h/14-day server window — so a beta tester behaves like a real
  // subscriber. In production (no USORA_BETA flag) this is always false, so the
  // real server gate (activate_spicy_mode) still enforces the free-tier window
  // for actual free users; they are UNAFFECTED.
  bool get _devPremium =>
      kBetaBuild && _ref.read(premiumDevOverrideProvider) == true;

  /// Re-read the server truth (call on app load and when opening the toggle).
  Future<void> refresh() async {
    final s = await _repo.status();
    if (!mounted) return;
    final unlimited = s.unlimited || _devPremium;
    state = state.copyWith(
      loading: false,
      unlimited: unlimited,
      // Restore ON if the server says we're inside an active session.
      on: s.active ? true : state.on && unlimited,
      expiresAt: s.sessionExpiresAt,
      cooldownUntil: s.cooldownUntil,
    );
    _armExpiry();
  }

  /// Turn spicy mode ON. Premium (incl. dev override) flips locally; free asks
  /// the server.
  Future<SpicyActivateOutcome> turnOn() async {
    if (state.busy) return SpicyActivateOutcome.error;
    if (_devPremium) {
      state = state.copyWith(on: true, unlimited: true, justEnded: false);
      return SpicyActivateOutcome.unlimited;
    }
    if (state.unlimited) {
      state = state.copyWith(on: true, justEnded: false);
      return SpicyActivateOutcome.unlimited;
    }
    state = state.copyWith(busy: true);
    try {
      final a = await _repo.activate();
      if (!mounted) return SpicyActivateOutcome.error;
      if (a.unlimited) {
        state = state.copyWith(
            busy: false, unlimited: true, on: true, justEnded: false);
        return SpicyActivateOutcome.unlimited;
      }
      if (a.allowed) {
        state = state.copyWith(
          busy: false,
          on: true,
          expiresAt: a.sessionExpiresAt,
          cooldownUntil: null,
          justEnded: false,
        );
        _armExpiry();
        return SpicyActivateOutcome.activated;
      }
      // Denied — still in cooldown.
      state = state.copyWith(
          busy: false, on: false, cooldownUntil: a.cooldownUntil);
      return SpicyActivateOutcome.cooldown;
    } catch (e, st) {
      debugPrint('spicy activate failed: $e\n$st');
      if (mounted) state = state.copyWith(busy: false);
      return SpicyActivateOutcome.error;
    }
  }

  /// Turn spicy mode OFF in-app. For a free session, the server window keeps
  /// running (re-toggling on within it resumes the same session); premium is a
  /// pure local flip.
  void turnOff() {
    _expiryTimer?.cancel();
    state = state.copyWith(on: false, justEnded: false);
  }

  /// Dismiss the "session just ended" prompt after showing it.
  void clearJustEnded() => state = state.copyWith(justEnded: false);

  void _armExpiry() {
    _expiryTimer?.cancel();
    final expires = state.expiresAt;
    if (!state.on || state.unlimited || expires == null) return;
    final remaining = expires.difference(DateTime.now());
    if (remaining.isNegative) {
      _onExpired();
      return;
    }
    _expiryTimer = Timer(remaining, _onExpired);
  }

  Future<void> _onExpired() async {
    if (!mounted) return;
    state = state.copyWith(on: false, expiresAt: null, justEnded: true);
    // Refresh to pick up the server's cooldown_until.
    final s = await _repo.status();
    if (!mounted) return;
    state = state.copyWith(cooldownUntil: s.cooldownUntil, unlimited: s.unlimited);
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    final ch = _channel;
    if (ch != null) _repo.removeChannel(ch);
    super.dispose();
  }
}

final spicyControllerProvider =
    StateNotifierProvider<SpicyController, SpicyState>(
  (ref) => SpicyController(ref.watch(spicyRepositoryProvider), ref),
);

/// Whether spicy mode is currently ON — the one flag the theme, games, and
/// creature steer read.
final spicyActiveProvider =
    Provider<bool>((ref) => ref.watch(spicyControllerProvider).on);
