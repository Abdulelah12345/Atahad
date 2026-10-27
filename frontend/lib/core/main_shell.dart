import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth/auth_state.dart';
import 'state/data_refresh.dart';

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
  GoRouter? _router;
  bool _onTabs = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_routeChanged);
      _router = router..routerDelegate.addListener(_routeChanged);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_routeChanged);
    super.dispose();
  }

  // back on the tabs from another page (a proof, a group, the donation...): what changed there shows here
  void _routeChanged() {
    final onTabs = _router?.routerDelegate.currentConfiguration.uri.path == '/';
    if (onTabs && !_onTabs) _refresh();
    _onTabs = onTabs;
  }

  void _refresh() {
    DataRefresh.instance.bump();
    if (_index == 3) context.read<AuthState>().refreshProfile().catchError((_) {}); // points and level on «حسابي»
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _refresh();
  }

  static const _pages = [
    HomeScreen(),
    ProofsHomeScreen(initialTab: 2, requestsOnly: true),
    GroupsScreen(),
    AccountTab()
  ];

  @override
  Widget build(BuildContext context) {
    // back on another tab returns to «اليوم» first, it does not close the app
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: _shell(),
    );
  }

  Widget _shell() {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
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
