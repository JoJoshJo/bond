import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Google OAuth client IDs (public — safe in the client). The iOS client is
/// used on-device; the WEB client is the `serverClientId` whose audience the
/// Supabase Google provider validates.
const _googleIosClientId =
    '760277024151-obp9stu8r9j9diqddsnq50o68m2t5mvd.apps.googleusercontent.com';
const _googleWebClientId =
    '760277024151-oad0g6h93vp91ledreg05mfoqmlacj8q.apps.googleusercontent.com';

/// Thin wrapper over Supabase Auth for email/password flows.
///
/// Keeps all direct `supabase.auth` calls in one place so the UI and providers
/// depend on this repository, not on the SDK directly. OAuth (Apple/Google) and
/// deep-link recovery are added here in a later task.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Deep link Supabase redirects back to after email confirmation / password
  /// reset. The `usora` scheme is registered natively (iOS Info.plist +
  /// Android intent-filter); supabase_flutter catches the incoming link and
  /// completes the PKCE session automatically. Must be in the Supabase
  /// dashboard's Redirect URLs allow-list.
  static const _redirect = 'usora://login-callback';

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
    return _auth.signUp(
      email: email.trim(),
      password: password,
      data: data,
      emailRedirectTo: _redirect,
    );
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
    return _auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: _redirect,
    );
  }

  /// Send a password-reset email. Completing the reset (setting a new password
  /// in-app) requires deep-link recovery, added with the OAuth task.
  Future<void> sendPasswordReset(String email) {
    return _auth.resetPasswordForEmail(email.trim(), redirectTo: _redirect);
  }

  // ---------------- Social sign-in (native → signInWithIdToken) ----------------

  /// Sign in with Apple via the native AuthenticationServices sheet. Uses a
  /// nonce (raw → Supabase, SHA-256 → Apple) as Supabase requires. On first
  /// authorization Apple returns the name; we populate `display_name` then.
  Future<void> signInWithApple() async {
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final cred = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = cred.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple did not return an identity token.');
    }
    await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    // Apple only sends the name on the FIRST authorization — capture it now.
    final name = [cred.givenName, cred.familyName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ')
        .trim();
    if (name.isNotEmpty) await _setDisplayNameIfEmpty(name);
  }

  bool _googleInitialized = false;

  /// Sign in with Google via the native sheet. The idToken's audience is the
  /// web client id (serverClientId), which the Supabase Google provider expects.
  Future<void> signInWithGoogle() async {
    final gsi = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await gsi.initialize(
        // iOS needs the iOS OAuth client id; Android derives it from
        // google-services.json, so pass null there.
        clientId: Platform.isIOS ? _googleIosClientId : null,
        serverClientId: _googleWebClientId,
      );
      _googleInitialized = true;
    }
    final account = await gsi.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google did not return an identity token.');
    }
    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    final name = account.displayName;
    if (name != null && name.isNotEmpty) await _setDisplayNameIfEmpty(name);
  }

  /// Populate `users.display_name` from the provider only if it's currently
  /// empty (never overwrite a name the user already has). Best-effort.
  Future<void> _setDisplayNameIfEmpty(String name) async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _client
          .from('users')
          .select('display_name')
          .eq('id', uid)
          .maybeSingle();
      final existing = row?['display_name'] as String?;
      if (existing == null || existing.isEmpty) {
        await _client.from('users').update({'display_name': name}).eq('id', uid);
      }
    } catch (e) {
      // Non-fatal — sign-in already succeeded; the name just isn't stored.
      debugPrint('display_name save failed: $e');
    }
  }

  static String _randomNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  Future<void> signOut() => _auth.signOut();

  /// Permanently delete the account (Apple 5.1.1(v)). Calls the `delete-account`
  /// Edge Function (server-side purge of the couple's data + auth.users delete),
  /// then signs out locally so the app routes back to the Welcome screen.
  Future<void> deleteAccount() async {
    final res = await _client.functions.invoke('delete-account');
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception('account deletion failed: ${data['error']}');
    }
    await _auth.signOut();
  }
}
