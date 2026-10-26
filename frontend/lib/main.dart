import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_state.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_state.dart';
import 'core/widgets/splash_gate.dart';
import 'core/widgets/states.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final auth = AuthState(api);
  await auth.restore(); // logs in again with the saved account
  final theme = ThemeState();
  await theme.restore(); // light / dark / like the phone
  runApp(AtahadApp(api: api, auth: auth, theme: theme));
}

class AtahadApp extends StatefulWidget {
  final ApiClient api;
  final AuthState auth;
  final ThemeState theme;

  const AtahadApp({super.key, required this.api, required this.auth, required this.theme});

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
        ChangeNotifierProvider<ThemeState>.value(value: widget.theme),
      ],
      child: Builder(
        builder: (context) => MaterialApp.router(
          title: 'أتعهّد',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: appMessengerKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: context.watch<ThemeState>().mode,
          // Arabic = right to left everywhere
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
          // the splash video covers the app once when it opens (core/widgets/splash_gate.dart)
          builder: (context, child) => SplashGate(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
