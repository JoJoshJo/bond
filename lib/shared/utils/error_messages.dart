/// Maps thrown errors to short, human-readable messages for the UI.
/// Shared across features; keep the real error in logs (debugPrint) separately.
String friendlyError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('invalid login credentials')) {
    return 'That email or password doesn\'t match. Try again.';
  }
  if (message.contains('email not confirmed')) {
    return 'Please verify your email first — check your inbox.';
  }
  if (message.contains('user already registered') ||
      message.contains('already registered')) {
    return 'An account with this email already exists. Try signing in.';
  }
  if (message.contains('password should be at least')) {
    return 'Password is too short (minimum 6 characters).';
  }
  if (message.contains('rate limit') || message.contains('too many')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (message.contains('already_in_couple')) {
    return 'You\'re already linked with someone.';
  }
  if (message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network')) {
    return 'No connection. Check your internet and try again.';
  }
  return 'Something went wrong. Please try again.';
}
