// OWNER: Turki - home (today), habits, goals and the AI plan, progress, grace days, points, stats, Monthly Wrapped
import 'package:go_router/go_router.dart';
import 'create_commitment_screen.dart';

final commitmentsRoutes = <GoRoute>[
  GoRoute(
      path: '/commitments/new',
      builder: (context, state) => const CreateCommitmentScreen()),
  // GoRoute(path: '/habit/add', builder: (context, state) => const AddHabitScreen()),
];
