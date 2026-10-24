// OWNER: Subhiyyah - proofs (camera, quiz, location), excuses, objections, the lock screen and the donation, penalties, admin review
import 'package:go_router/go_router.dart';

import 'admin_home_screen.dart';
import 'lock_screen.dart';

// a locked member can open only these pages (the donation and the excuse pages go here too)
const allowedWhileLocked = ['/lock'];

final proofsRoutes = <GoRoute>[
  GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
  GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
];
