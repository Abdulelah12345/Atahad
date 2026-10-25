
// OWNER: Abdulelah - login, register, my profile, deactivate, Google Calendar
import 'package:go_router/go_router.dart';

import 'login_screen.dart';
import 'register_screen.dart';
import 'update_profile_screen.dart';
import 'google_calendar_screen.dart';

final accountRoutes = <GoRoute>[
  GoRoute(
    path: '/login',
    builder: (context, state) => const LoginScreen(),
  ),
  GoRoute(
    path: '/register',
    builder: (context, state) => const RegisterScreen(),
  ),
  GoRoute(
    path: '/update-profile',
    builder: (context, state) => const UpdateProfileScreen(),
  ),
  GoRoute(
    path: '/google-calendar',
    builder: (context, state) => const GoogleCalendarScreen(),
  ),
];
