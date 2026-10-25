// OWNER: Fai - groups, join with the code, proposals and votes, board, alerts, chat, moments, settlement and titles
// (the group matches / competitions are Abdulelah's)
import 'package:go_router/go_router.dart';

import 'group_screen.dart';

final groupsRoutes = <GoRoute>[
  GoRoute(
    path: '/group/:id',
    builder: (context, state) => GroupScreen(groupId: int.parse(state.pathParameters['id']!)),
  ),
];
