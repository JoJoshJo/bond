import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/couple_repository.dart';

final coupleRepositoryProvider = Provider<CoupleRepository>(
  (ref) => CoupleRepository(ref.watch(supabaseClientProvider)),
);

/// The current user's couple membership (null = not in a couple yet).
/// Drives CoupleGate routing. Re-fetched via [ref.invalidate] after create/join.
final myMembershipProvider = FutureProvider<CoupleMembership?>((ref) {
  // Re-resolve whenever auth changes (sign in/out).
  ref.watch(authStateProvider);
  return ref.watch(coupleRepositoryProvider).getMyMembership();
});

/// Live status stream for a specific couple (Partner A's waiting screen).
final coupleStatusProvider = StreamProvider.family<String, String>(
  (ref, coupleId) =>
      ref.watch(coupleRepositoryProvider).watchCoupleStatus(coupleId),
);
