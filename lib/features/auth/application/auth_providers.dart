import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';

/// Supabase client (already initialized in main()).
final supabaseClientProvider = Provider<SupabaseClient>((ref) => supabase);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

/// The app's source of truth for auth. Emits an initial event immediately, then
/// on every sign in / sign out / token refresh. The AuthGate watches this.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Convenience: the current [Session] (null when signed out), derived from the
/// auth stream so it stays in sync.
final sessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.asData?.value.session ??
      ref.watch(authRepositoryProvider).currentSession;
});
