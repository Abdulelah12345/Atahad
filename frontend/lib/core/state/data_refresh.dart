import 'package:flutter/foundation.dart';

// one signal for "the data may have changed somewhere": the main tabs listen to it and reload quietly
// (keeping what is on screen until the new data arrives), so a change made on one page shows on the others too.
// It is fired when the member switches tab and when they come back to the tabs from another page.
class DataRefresh extends ChangeNotifier {
  DataRefresh._();
  static final instance = DataRefresh._();

  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void bump() {
    // two bumps close together (a pop then a tab tap) load once
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(milliseconds: 700)) return;
    _last = now;
    notifyListeners();
  }
}
