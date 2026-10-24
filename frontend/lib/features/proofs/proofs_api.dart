import 'dart:convert';
import 'dart:typed_data';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';

typedef Json = Map<String, dynamic>;

class ProofsApi {
  final ApiClient client;
  ProofsApi(this.client);

  Future<Json> workspace() async => Map<String, dynamic>.from(
      await client.get('/api/v1/proof-workspace/my') as Map);
  Future<List<Json>> activities() async =>
      maps(await client.get('/api/v1/commitment-week/today'));
  Future<Json> state(int id) async => Map<String, dynamic>.from(
      await client.get('/api/v1/proof-attempt/$id') as Map);

  Future<int> cameraUpload(String kind, Uint8List bytes,
      {int? proofId, String mime = 'image/jpeg'}) async {
    checkImage(bytes);
    final ticket = await client.post('/api/v1/proof-attempt/capture',
        query: {'kind': kind, 'proofId': proofId}) as Map;
    await client
        .post('/api/v1/proof-attempt/capture/${ticket['captureId']}', body: {
      'token': ticket['token'],
      'imageData': 'data:$mime;base64,${base64Encode(bytes)}',
    });
    return ticket['captureId'] as int;
  }

  Future<String> attachment(
      String section, Uint8List bytes, String mime) async {
    checkImage(bytes);
    final ticket = await client.post('/api/v1/$section/attachment') as Map;
    final result = await client
        .post('/api/v1/$section/attachment/${ticket['captureId']}', body: {
      'token': ticket['token'],
      'imageData': 'data:$mime;base64,${base64Encode(bytes)}',
    }) as Map;
    return result['reference'] as String;
  }

  void checkImage(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      throw ApiException(400, 'اختاري صورة حجمها أقل من ٢ ميغابايت.');
    }
  }

  static List<Json> maps(dynamic value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

const methodNames = {
  'PHOTO': 'صورة مباشرة',
  'QUIZ': 'اختبار قصير',
  'TIMER': 'جلسة تركيز',
  'LOCATION': 'زيارة مكان'
};
const excuseNames = {
  'SICK': 'ظرف صحي',
  'TRAVEL': 'سفر',
  'EMERGENCY': 'ظرف طارئ',
  'OTHER': 'ظرف آخر'
};
const kindNames = {
  'PROOF': 'إثبات نشاط',
  'EXCUSE': 'عذر',
  'OBJECTION': 'اعتراض',
  'DONATION': 'إثبات تبرع'
};

DateTime riyadhNow() => DateTime.now().toUtc().add(const Duration(hours: 3));
DateTime? serverInstant(Object? value) {
  if (value == null) return null;
  final text = '$value';
  return DateTime.tryParse(
      RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(text) ? text : '$text+03:00');
}

String friendlyError(Object error) {
  final raw = error is ApiException ? error.message : '$error';
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(raw)) return raw;
  if (raw.contains('no quiz attempt') || raw.contains('Quiz generation')) {
    return 'تعذر تجهيز الأسئلة الآن. محاولتك محفوظة؛ جربي بعد شوي.';
  }
  if (raw.contains('Only one retry')) {
    return 'استخدمتِ المحاولة والإعادة لهذا النشاط.';
  }
  if (raw.contains('already has') || raw.contains('already succeeded')) {
    return 'لهذا النشاط طلب سابق. افتحي السجل لمتابعته.';
  }
  if (raw.contains('Wait until')) {
    return 'انتظري انتهاء مراجعة الطلب السابق لنفس النشاط.';
  }
  if (raw.contains('ended') ||
      raw.contains('expired') ||
      raw.contains('closed')) {
    return 'انتهت مهلة هذا النشاط أو الطلب.';
  }
  if (raw.contains('Could not connect to Gmail')) {
    return 'تعذر ربط Gmail. تأكدي من البريد وكلمة مرور التطبيقات.';
  }
  if (raw.contains('No bank email')) {
    return 'ما لقينا رسالة تحويل بنكي مناسبة حتى الآن. جربي لاحقًا.';
  }
  if (raw.contains('No pending penalties')) {
    return 'ما عليك مبلغ ينتظر التبرع حاليًا.';
  }
  if (raw.contains('Unauthorized')) return 'سجلي الدخول مرة ثانية للمتابعة.';
  if (raw.contains('Forbidden') || raw.contains('Not your')) {
    return 'هذا الإجراء غير متاح لهذا الحساب.';
  }
  if (raw.contains('before') || raw.contains('different captures')) {
    return 'التقطي صورة البداية والنهاية بشكل مستقل وفي وقت النشاط.';
  }
  return 'ما اكتمل الطلب. تأكدي من البيانات وحاولي مرة ثانية.';
}
