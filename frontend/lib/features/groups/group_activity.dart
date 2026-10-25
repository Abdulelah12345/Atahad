import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/widgets/states.dart';
import 'group_api.dart';

// what is new in every group (a red dot on the group card until the group is opened),
// and a notification with sound when a friend sends me an alert (while the app is open)
// the real push when the app is closed needs Firebase on the phone (later)
class GroupActivity extends ChangeNotifier {
  GroupActivity._();

  static final GroupActivity instance = GroupActivity._();

  final _storage = const FlutterSecureStorage();
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  final Map<int, DateTime> _seen = {}; // when I opened the group last time
  final Map<int, DateTime> _latest = {}; // the newest thing a friend did in the group
  final Set<int> _notified = {}; // alerts already shown as a notification
  final Set<int> dismissed = {}; // alerts I removed from the board

  // a dot on the groups tab in the bottom bar
  bool get hasAnyNew => _latest.keys.any(hasNew);

  bool hasNew(int groupId) {
    final latest = _latest[groupId];
    final seen = _seen[groupId];
    return latest != null && seen != null && latest.isAfter(seen);
  }

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      final raw = await _storage.read(key: 'group_activity');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        (data['seen'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _seen[int.parse(k)] = DateTime.parse('$v'));
        _notified.addAll(((data['notified'] as List?) ?? []).map((e) => e as int));
        dismissed.addAll(((data['dismissed'] as List?) ?? []).map((e) => e as int));
      }
    } catch (_) {}
    try {
      await _notifications.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: true, requestSoundPermission: true, requestBadgePermission: true),
      ));
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notifications are off: $e');
    }
  }

  Future<void> _save() async {
    try {
      await _storage.write(
        key: 'group_activity',
        value: jsonEncode({
          'seen': _seen.map((k, v) => MapEntry('$k', v.toIso8601String())),
          'notified': _notified.toList(),
          'dismissed': dismissed.toList(),
        }),
      );
    } catch (_) {}
  }

  // opening the group removes its red dot
  Future<void> markSeen(int groupId) async {
    await _init();
    _seen[groupId] = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> dismissAlert(int alertId) async {
    dismissed.add(alertId);
    notifyListeners();
    await _save();
  }

  // checks every group: new chat messages, new moments and new alerts from the friends
  Future<void> check(GroupApi api, List<Map<String, dynamic>> groups, int? me) async {
    await _init();
    var changed = false;
    for (final g in groups) {
      final id = g['groupId'] as int?;
      if (id == null) continue;
      _seen.putIfAbsent(id, () {
        changed = true;
        return DateTime.now(); // a new group starts without a red dot
      });
      DateTime? latest;
      void take(Object? value) {
        final t = DateTime.tryParse('${value ?? ''}');
        if (t != null && (latest == null || t.isAfter(latest!))) latest = t;
      }

      try {
        final results = await Future.wait([api.messages(id), api.groupMoments(id), api.myAlertsToday(id)]);
        for (final m in results[0]) {
          if (m['senderId'] != me) take(m['sentAt']);
        }
        for (final m in results[1]) {
          if (m['memberId'] != me) take(m['createdAt']);
        }
        for (final a in results[2]) {
          take(a['sentAt']);
          final alertId = a['id'] as int?;
          if (alertId != null && !_notified.contains(alertId)) {
            _notified.add(alertId);
            changed = true;
            await _show(alertId, a['isCollective'] == true ? 'تنبيه من المجموعة' : '${a['senderName'] ?? ''} ينبهك', '${a['message'] ?? ''}');
          }
        }
      } catch (_) {
        continue;
      }
      if (latest != null && _latest[id] != latest) {
        _latest[id] = latest!;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> _show(int id, String title, String body) async {
    // inside the app (any page) ...
    appMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            Text(body, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ));
    // ... and as a notification with our sound
    try {
      await _notifications.show(
        id,
        title,
        body,
        const NotificationDetails(
          // our own sound: android/app/src/main/res/raw/group_alert.wav and ios/Runner/group_alert.wav
          // (an Android channel keeps its first sound, so a new sound needs a new channel id)
          android: AndroidNotificationDetails('group_alerts_v2', 'تنبيهات المجموعة',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('group_alert')),
          iOS: DarwinNotificationDetails(
              presentAlert: true, presentBanner: true, presentList: true, presentSound: true, sound: 'group_alert.wav'),
        ),
      );
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }
}
