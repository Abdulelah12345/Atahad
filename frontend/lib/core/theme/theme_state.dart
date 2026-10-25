import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// light / dark / like the phone, kept on the phone so it stays after closing the app.
// In a widget: context.read<ThemeState>().setMode(ThemeMode.dark)
class ThemeState extends ChangeNotifier {
  static const _key = 'themeMode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> restore() async {
    final saved = await _storage.read(key: _key);
    _mode = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    await _storage.write(key: _key, value: mode.name);
  }
}
