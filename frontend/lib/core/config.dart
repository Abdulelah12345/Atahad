import 'package:flutter/foundation.dart';

// where the backend is
// iOS simulator and Chrome: localhost / Android emulator: 10.0.2.2 / a real phone: the IP of the Mac (same Wi-Fi)
// to change it without editing the code: flutter run --dart-define=API_URL=http://192.168.1.5:8080
class AppConfig {
  static const String _fromRun = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_fromRun.isNotEmpty) return _fromRun;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  // until the login page is ready, the app logs in with this test account (debug only)
  // another account: flutter run --dart-define=DEV_EMAIL=sara@test.com --dart-define=DEV_PASSWORD=12345678
  static const String devEmail = String.fromEnvironment('DEV_EMAIL', defaultValue: 'fai@test.com');
  static const String devPassword = String.fromEnvironment('DEV_PASSWORD', defaultValue: '12345678');
}
