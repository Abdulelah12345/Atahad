import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/widgets/states.dart';
import 'group_api.dart';

// what is new in every group and where: an alert on the board, a message in the chat or a new moment
// (a red dot on the group card and on the tab, until that tab is opened),
// and a notification with sound when a friend sends me an alert (while the app is open)
class GroupActivity extends ChangeNotifier {
  GroupActivity._();

  static final GroupActivity instance = GroupActivity._();

  final _storage = const FlutterSecureStorage();
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // the places of a group where something can be new
  static const alert = 'alert'; // the board
  static const chat = 'chat';
  static const moments = 'moments';
  static const _kinds = [alert, chat, moments];

  final Map<String, DateTime> _seen = {}; // 'groupId:kind' -> when I opened it last time
  final Map<String, DateTime> _latest = {}; // 'groupId:kind' -> the newest thing a friend did there
  final Set<int> _notified = {}; // alerts already shown as a notification
  final Set<int> dismissed = {}; // alerts I removed from the board

  // a dot on the groups tab in the bottom bar
  bool get hasAnyNew => _latest.keys.any((k) => _isNew(k));

  bool _isNew(String key) {
    final latest = _latest[key];
    final seen = _seen[key];
    return latest != null && seen != null && latest.isAfter(seen);
  }

  bool hasNew(int groupId) => _kinds.any((k) => hasNewIn(groupId, k));

  bool hasNewIn(int groupId, String kind) => _isNew('$groupId:$kind');

  // where the new things are, for the group card
  String? whereNew(int groupId) {
    final parts = [
      if (hasNewIn(groupId, alert)) 'تنبيه لك باللوحة',
      if (hasNewIn(groupId, chat)) 'رسالة جديدة بالشات',
      if (hasNewIn(groupId, moments)) 'لحظة جديدة',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      final raw = await _storage.read(key: 'group_activity');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        (data['seenIn'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _seen[k] = DateTime.parse('$v'));
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
          'seenIn': _seen.map((k, v) => MapEntry(k, v.toIso8601String())),
          'notified': _notified.toList(),
          'dismissed': dismissed.toList(),
        }),
      );
    } catch (_) {}
  }

  // opening a tab of the group removes its red dot
  Future<void> markSeen(int groupId, String kind) async {
    await _init();
    if (!hasNewIn(groupId, kind) && _seen.containsKey('$groupId:$kind')) return;
    _seen['$groupId:$kind'] = DateTime.now();
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
      for (final k in _kinds) {
        _seen.putIfAbsent('$id:$k', () {
          changed = true;
          return DateTime.now(); // a new group starts without a red dot
        });
      }
      final latest = <String, DateTime>{};
      void take(String kind, Object? value) {
        final t = DateTime.tryParse('${value ?? ''}');
        if (t != null && (latest[kind] == null || t.isAfter(latest[kind]!))) latest[kind] = t;
      }
      final groupName = '${g['groupName'] ?? ''}';

      try {
        final results = await Future.wait([api.messages(id), api.groupMoments(id), api.myAlertsToday(id)]);
        for (final m in results[0]) {
          if (m['senderId'] != me) take(chat, m['sentAt']);
        }
        for (final m in results[1]) {
          if (m['memberId'] != me) take(moments, m['createdAt']);
        }
        for (final a in results[2]) {
          take(alert, a['sentAt']);
          final alertId = a['id'] as int?;
          if (alertId != null && !_notified.contains(alertId)) {
            _notified.add(alertId);
            changed = true;
            final from = a['isCollective'] == true ? 'تنبيه من المجموعة' : 'تنبيه من ${a['senderName'] ?? ''}';
            final place = '${a['groupName'] ?? groupName}';
            await _show(alertId, '$from · $place', '${a['message'] ?? ''}\nتلقاه في لوحة المجموعة');
          }
        }
      } catch (_) {
        continue;
      }
      latest.forEach((kind, t) {
        if (_latest['$id:$kind'] != t) {
          _latest['$id:$kind'] = t;
          changed = true;
        }
      });
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
