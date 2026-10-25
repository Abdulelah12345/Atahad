import 'package:flutter/material.dart';

import '../features/account/account_tab.dart';
import '../features/proofs/proofs_home_screen.dart';
import '../features/commitments/home_screen.dart';
import '../features/groups/group_activity.dart';
import '../features/groups/groups_screen.dart';

// the bottom bar of the member: home / my requests / groups / my account
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    ProofsHomeScreen(initialTab: 2, requestsOnly: true),
    GroupsScreen(),
    AccountTab()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'اليوم'),
          const NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'طلباتي'),
          NavigationDestination(
            // a red dot when something is new in one of my groups
            icon: ListenableBuilder(
              listenable: GroupActivity.instance,
              builder: (context, _) => Badge(isLabelVisible: GroupActivity.instance.hasAnyNew, child: const Icon(Icons.groups_outlined)),
            ),
            selectedIcon: ListenableBuilder(
              listenable: GroupActivity.instance,
              builder: (context, _) => Badge(isLabelVisible: GroupActivity.instance.hasAnyNew, child: const Icon(Icons.groups)),
            ),
            label: 'المجموعات',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}
