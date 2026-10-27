import 'package:flutter/foundation.dart';

// "something changed": the tabs reload quietly when it fires
// fired on a tab switch and when coming back to the tabs
class DataRefresh extends ChangeNotifier {
  DataRefresh._();
  static final instance = DataRefresh._();

  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void bump() {
    // two bumps close together load once
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(milliseconds: 700)) return;
    _last = now;
    notifyListeners();
  }
}
