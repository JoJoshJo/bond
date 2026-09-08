import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../couple/presentation/couple_profile_screen.dart';
import '../../games/presentation/games_hub_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../memories/presentation/memory_vault_screen.dart';
import '../../messaging/presentation/chat_screen.dart';

/// The linked-couple app shell: bottom nav tying the app together.
/// Home · Chat · Play · Memories · Us.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.coupleId, required this.coupleName});

  final String coupleId;
  final String coupleName;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(coupleId: widget.coupleId, coupleName: widget.coupleName),
      ChatScreen(coupleId: widget.coupleId, coupleName: widget.coupleName),
      const GamesHubScreen(),
      MemoryVaultScreen(coupleId: widget.coupleId),
      CoupleProfileScreen(
          coupleId: widget.coupleId, coupleName: widget.coupleName),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.mintWash,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat'),
          NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports_rounded),
              label: 'Play'),
          NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library_rounded),
              label: 'Memories'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Us'),
        ],
      ),
    );
  }
}
