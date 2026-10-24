import 'package:go_router/go_router.dart';

import '../features/account/account_routes.dart';
import '../features/commitments/commitments_routes.dart';
import '../features/groups/groups_routes.dart';
import '../features/proofs/proofs_routes.dart';
import 'auth/auth_state.dart';
import 'main_shell.dart';

// every person adds his pages in his own *_routes.dart file, not here
// the redirects: locked -> /lock / admin -> /admin
// there is no login page yet (Abdulelah): in debug the app logs in with the test account (core/config.dart)
GoRouter buildRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (!auth.isLoggedIn) return null;
      if (auth.isAdmin && location == '/') return '/admin';
      if (auth.isMember && auth.isLocked && !allowedWhileLocked.any(location.startsWith)) return '/lock';
      if (auth.isMember && !auth.isLocked && location == '/lock') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainShell()),
      ...accountRoutes,
      ...commitmentsRoutes,
      ...proofsRoutes,
      ...groupsRoutes,
    ],
  );
}
