import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../couple/presentation/couple_gate.dart';
import '../application/auth_providers.dart';
import 'welcome_screen.dart';

/// Root router. Watches the auth stream and shows the right screen:
/// signed out → [WelcomeScreen], signed in → [HomePlaceholderScreen].
/// Also silently captures the device timezone on the first signed-in event.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _timezoneCaptured = false;

  void _maybeCaptureTimezone(Session? session) {
    if (session == null || _timezoneCaptured) return;
    _timezoneCaptured = true;
    // Fire-and-forget; best-effort, never blocks routing.
    ref.read(profileRepositoryProvider).captureHomeTimezoneIfMissing();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _Splash(),
      error: (_, _) => const WelcomeScreen(),
      data: (state) {
        final session =
            state.session ?? ref.read(authRepositoryProvider).currentSession;
        _maybeCaptureTimezone(session);
        if (session != null) {
          return const CoupleGate();
        }
        return const WelcomeScreen();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
