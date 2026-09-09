import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over Supabase Auth for email/password flows.
///
/// Keeps all direct `supabase.auth` calls in one place so the UI and providers
/// depend on this repository, not on the SDK directly. OAuth (Apple/Google) and
/// deep-link recovery are added here in a later task.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// Current session, or null if signed out.
  Session? get currentSession => _auth.currentSession;

  /// Current user, or null if signed out.
  User? get currentUser => _auth.currentUser;

  /// Emits on every auth change (sign in, sign out, token refresh, recovery).
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// Sign up with email + password. With "Confirm email" ON in Supabase, this
  /// creates the user but NO active session until the emailed link is clicked.
  /// The `on_auth_user_created` DB trigger creates the public.users row.
  ///
  /// [data] is written to the auth user's metadata (`raw_user_meta_data`). We
  /// use it to record the declared date of birth (`birth_date`, YYYY-MM-DD) from
  /// the 18+ age gate — no public.users column needed, and it persists even when
  /// signup returns no session (confirm-email flow).
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) {
    return _auth.signUp(email: email.trim(), password: password, data: data);
  }

  /// Sign in with email + password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Resend the signup confirmation email.
  Future<void> resendConfirmation(String email) {
    return _auth.resend(type: OtpType.signup, email: email.trim());
  }

  /// Send a password-reset email. Completing the reset (setting a new password
  /// in-app) requires deep-link recovery, added with the OAuth task.
  Future<void> sendPasswordReset(String email) {
    return _auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}
