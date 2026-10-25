import 'package:go_router/go_router.dart';
import 'admin_home_screen.dart';
import 'donations_screen.dart';
import 'lock_screen.dart';
import 'proofs_home_screen.dart';
import 'proof_session_screen.dart';

// تظهر الطلبات والتبرع أثناء القفل؛ الباك إند يطبق الصلاحيات على كل إجراء فعلي.
const allowedWhileLocked = ['/lock', '/requests', '/proofs/donations'];

final proofsRoutes = <GoRoute>[
  GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
  GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
  GoRoute(
      path: '/requests',
      builder: (context, state) =>
          const ProofsHomeScreen(initialTab: 2, requestsOnly: true)),
  GoRoute(
      path: '/proofs',
      builder: (context, state) => const ProofsHomeScreen(initialTab: 1)),
  GoRoute(
      path: '/proofs/donations',
      builder: (context, state) => const DonationsScreen()),
  GoRoute(
      path: '/proofs/start',
      builder: (_, state) => ProofStartScreen(
          activity: state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null,
          weekId: int.tryParse(state.uri.queryParameters['weekId'] ?? ''),
          taskId: int.tryParse(state.uri.queryParameters['taskId'] ?? ''))),
  GoRoute(
      path: '/proofs/session/:id',
      builder: (_, state) => ProofSessionScreen(
          proofId: int.parse(state.pathParameters['id']!),
          title: state.uri.queryParameters['title'] ?? 'نشاطك')),
];
