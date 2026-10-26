import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'walking_api.dart';

class WalkingReading {
  final String status;
  final String message;
  final String? source;
  final String? installation;
  final int? total;
  final DateTime day;
  final DateTime observedAt;
  const WalkingReading({
    required this.status,
    required this.message,
    required this.day,
    required this.observedAt,
    this.source,
    this.installation,
    this.total,
  });
  bool get ready => status == 'READY' && total != null;
  Map<String, dynamic> get connectionBody => {
    'source': source,
    'deviceId': installation,
    'status': status,
    if (ready) 'readDay': walkingDay(day),
    if (ready) 'stepsRead': total,
  };
  Map<String, dynamic> get syncBody => {
    'source': source,
    'deviceId': installation,
    'day': walkingDay(day),
    'total': total,
    'zoneId': 'Asia/Riyadh',
    'observedAt': walkingTimestamp(observedAt),
  };
}

abstract class WalkingHealthReader {
  bool get supported;
  bool get android;
  Future<WalkingReading> read(DateTime day, {bool requestPermission = false});
  Future<void> openSettings();
}

class NativeWalkingHealthReader implements WalkingHealthReader {
  final Health _health = Health();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _configured = false;
  @override
  bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  @override
  bool get supported => android || _ios;
  Future<String> _installation() async {
    final saved = await _storage.read(key: 'walking_installation');
    if (saved != null) return saved;
    final random = Random.secure();
    final id = base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
    await _storage.write(key: 'walking_installation', value: id);
    return id;
  }

  @override
  Future<WalkingReading> read(
    DateTime day, {
    bool requestPermission = false,
  }) async {
    String? installation;
    final source = supported
        ? (android ? 'HEALTH_CONNECT' : 'HEALTH_KIT')
        : null;
    WalkingReading result(String status, String message, [int? total]) =>
        WalkingReading(
          status: status,
          message: message,
          total: total,
          source: source,
          installation: installation,
          day: day,
          observedAt: DateTime.now().toUtc(),
        );
    if (!supported) {
      return result(
        'UNAVAILABLE',
        'الربط المباشر متاح في تطبيق الجوال على أندرويد وآيفون. تقدر تستخدم إثبات الصورة هنا.',
      );
    }
    try {
      installation = await _installation();
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      if (android && !await _health.isHealthConnectAvailable()) {
        return result(
          'UNAVAILABLE',
          'خدمة Health Connect غير جاهزة على جهازك. ثبّتها أو حدّثها، أو اختر إثبات الصورة.',
        );
      }
      if (requestPermission) {
        if (android) await Permission.activityRecognition.request();
        final granted = await _health.requestAuthorization(
          [HealthDataType.STEPS],
          permissions: [HealthDataAccess.READ],
        );
        if (android && !granted) {
          return result(
            'NEEDS_PERMISSION',
            'اسمح بقراءة الخطوات من إعدادات Health Connect، ثم أعد الفحص.',
          );
        }
      }
      if (android &&
          await _health.hasPermissions(
                [HealthDataType.STEPS],
                permissions: [HealthDataAccess.READ],
              ) !=
              true) {
        return result(
          'NEEDS_PERMISSION',
          'نحتاج إذن قراءة الخطوات. اضغط فحص الربط للمتابعة.',
        );
      }
      final now = DateTime.now().toUtc();
      final start = walkingDayStartUtc(day);
      final endOfDay = start.add(const Duration(days: 1));
      final end = endOfDay.isBefore(now) ? endOfDay : now;
      if (!end.isAfter(start)) {
        return result(
          'UNKNOWN',
          'ما فيه فترة مكتملة للقراءة الآن، أعد المحاولة لاحقًا.',
        );
      }
      final total = await _health.getTotalStepsInInterval(
        start,
        end,
        includeManualEntry: false,
      );
      if (total == null) {
        return result(
          'UNKNOWN',
          'ما قدرنا نقرأ الخطوات الآن. بياناتك السابقة محفوظة؛ حاول لاحقًا أو استخدم صورة.',
        );
      }
      // HealthKit deliberately cannot distinguish denied reads from an empty store.
      if (_ios && total == 0) {
        final samples = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: start,
          endTime: end,
        );
        if (samples.isEmpty) {
          return result(
            'UNKNOWN',
            'ما وصلتنا بيانات خطوات من تطبيق صحتي. تأكد من الإذن ووجود بيانات، أو استخدم صورة.',
          );
        }
      }
      return result('READY', 'تمت قراءة خطواتك بنجاح', total);
    } catch (_) {
      return result(
        'UNKNOWN',
        'تعذّر التحقق من الربط الآن. جرّب الإعدادات أو إثبات الصورة؛ لن نبدّل خطواتك المسجلة بصفر.',
      );
    }
  }

  @override
  Future<void> openSettings() async {
    if (android) {
      if (!_configured) {
        await _health.configure();
        _configured = true;
      }
      if (!await _health.isHealthConnectAvailable()) {
        await _health.installHealthConnect();
        return;
      }
    }
    if (supported) await openAppSettings();
  }
}
