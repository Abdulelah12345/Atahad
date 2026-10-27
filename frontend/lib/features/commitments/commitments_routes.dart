// OWNER: Turki - home (today), habits, goals and the AI plan, progress, grace days, points, stats, Monthly Wrapped
import 'package:go_router/go_router.dart';
import 'create_commitment_screen.dart';

import 'commitments_screen.dart';
import 'goal_plan_screen.dart';
import 'goal_screen.dart';
import 'habit_form_screen.dart';
import 'stats_screen.dart';
import 'wrapped_screen.dart';
import '../lucky_challenge/lucky_challenge_screen.dart';
final commitmentsRoutes = <GoRoute>[
  GoRoute(
      path: '/commitments/new',
      builder: (context, state) => const CreateCommitmentScreen()),
  // GoRoute(path: '/habit/add', builder: (context, state) => const AddHabitScreen()),
  GoRoute(path: '/commitments', builder: (context, state) => const CommitmentsScreen()),
  GoRoute(path: '/habit/add', builder: (context, state) => const HabitFormScreen()),
  GoRoute(
    path: '/habit/edit',
    builder: (context, state) =>
        HabitFormScreen(habit: state.extra is Map ? Map<String, dynamic>.from(state.extra as Map) : null),
  ),
  // before /goal/:id so "new" is not read as an id
  GoRoute(path: '/goal/new', builder: (context, state) => const GoalPlanScreen()),
  GoRoute(
    path: '/goal/:id',
    builder: (context, state) => GoalScreen(id: int.parse(state.pathParameters['id']!)),
  ),
  GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
  GoRoute(path: '/wrapped', builder: (context, state) => const WrappedScreen()),
  GoRoute(
    path: '/lucky-challenge',
    builder: (context, state) => const LuckyChallengeScreen(),
  ),
];
