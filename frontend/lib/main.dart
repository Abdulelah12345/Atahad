import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_state.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final auth = AuthState(api);
  await auth.restore(); // logs in again with the saved account
  if (!auth.isLoggedIn && kDebugMode) {
    // no login page yet: use the test account from core/config.dart
    try {
      await auth.login(AppConfig.devEmail, AppConfig.devPassword);
    } catch (e) {
      debugPrint('Test login failed ($e): register ${AppConfig.devEmail} in Postman first');
    }
  }
  runApp(AtahadApp(api: api, auth: auth));
}

class AtahadApp extends StatefulWidget {
  final ApiClient api;
  final AuthState auth;

  const AtahadApp({super.key, required this.api, required this.auth});

  @override
  State<AtahadApp> createState() => _AtahadAppState();
}

class _AtahadAppState extends State<AtahadApp> {
  late final GoRouter _router = buildRouter(widget.auth);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: widget.api),
        ChangeNotifierProvider<AuthState>.value(value: widget.auth),
      ],
      child: MaterialApp.router(
        title: 'أتعهّد',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        // Arabic = right to left everywhere
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    );
  }
}
