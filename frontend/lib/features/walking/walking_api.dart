import 'dart:convert';
import 'dart:typed_data';
import '../../core/api/api_client.dart';

String normalizeWalkingNumber(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  return value.trim().replaceAll('٬', '').replaceAll('٫', '.');
}

DateTime walkingNow([DateTime? instant]) =>
    (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
String walkingDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
DateTime walkingDayStartUtc(DateTime day) => DateTime.utc(
  day.year,
  day.month,
  day.day,
).subtract(const Duration(hours: 3));
String walkingTimestamp(DateTime instant) =>
    walkingNow(instant).toIso8601String().replaceFirst(RegExp(r'Z$'), '');

class WalkingApi {
  final ApiClient client;
  WalkingApi(this.client);
  Future<Map<String, dynamic>> connection() async => Map<String, dynamic>.from(
    await client.get('/api/v1/walking/connection') as Map,
  );
  Future<Map<String, dynamic>> check(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await client.put('/api/v1/walking/connection', body: body) as Map,
      );
  Future<Map<String, dynamic>> progress(int weekId, DateTime day) async =>
      Map<String, dynamic>.from(
        await client.get(
              '/api/v1/walking/weeks/$weekId/progress',
              query: {'day': walkingDay(day)},
            )
            as Map,
      );
  Future<Map<String, dynamic>> sync(
    int weekId,
    Map<String, dynamic> body,
  ) async => Map<String, dynamic>.from(
    await client.post('/api/v1/walking/weeks/$weekId/sync', body: body) as Map,
  );
  Future<Map<String, dynamic>> screenshot(
    int weekId,
    DateTime day,
    Uint8List bytes,
  ) async {
    // Stay below the backend's encoded payload cap, including the data URI prefix.
    if (bytes.isEmpty || bytes.length > 2200000) {
      throw const FormatException('اختر صورة حجمها أقل من ٢٫٢ ميغابايت.');
    }
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpeg) {
      throw const FormatException('اختر لقطة شاشة بصيغة PNG أو JPEG.');
    }
    return Map<String, dynamic>.from(
      await client.post(
            '/api/v1/walking/weeks/$weekId/screenshot',
            body: {
              'day': walkingDay(day),
              'imageData':
                  'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}',
            },
          )
          as Map,
    );
  }
}
