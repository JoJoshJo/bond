import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/home_placeholder_screen.dart';
import '../application/couple_providers.dart';
import 'create_or_join_screen.dart';
import 'invite_waiting_screen.dart';

/// Routes a signed-in user by couple status:
/// no couple → CreateOrJoin; pending (waiting for B) → InviteWaiting;
/// active/sealed → Home.
class CoupleGate extends ConsumerWidget {
  const CoupleGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myMembershipProvider);

    return membership.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const CreateOrJoinScreen(),
      data: (m) {
        if (m == null) return const CreateOrJoinScreen();
        if (m.isPending) {
          return InviteWaitingScreen(
            coupleId: m.coupleId,
            coupleName: m.coupleName,
          );
        }
        return const HomePlaceholderScreen();
      },
    );
  }
}
