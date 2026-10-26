import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:atahad/core/api/api_client.dart';
import 'package:atahad/core/api/api_exception.dart';
import 'package:atahad/core/theme/at_colors.dart';
import 'package:atahad/features/walking/walking_api.dart';
import 'package:atahad/features/walking/walking_health.dart';
import 'package:atahad/features/walking/walking_setup.dart';
import 'package:atahad/features/walking/walking_screen.dart';

class WalkingFakeApi extends ApiClient {
  bool offline = false;
  final requests = <Map<String, dynamic>>[];
  Map<String, dynamic> progress = {
    'targetSteps': 5000,
    'totalSteps': null,
    'status': 'AWAITING_SYNC',
    'evidenceMode': 'HEALTH_DATA',
    'lastSyncedAt': null,
  };
  @override
  Future<dynamic> get(String path, {Map<String, Object?>? query}) async {
    if (offline) throw ApiException(0, 'تعذّر الاتصال');
    return {...progress};
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) async {
    requests.add({'path': path, 'body': body});
    if (offline) throw ApiException(0, 'تعذّر الاتصال');
    return {'status': 'READY'};
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool auth = true,
  }) async {
    requests.add({'path': path, 'body': body});
    return {...progress};
  }
}

class Reader extends WalkingHealthReader {
  @override
  final bool supported;
  @override
  bool get android => supported;
  final String status;
  final int? total;
  int reads = 0;
  Reader({this.supported = true, this.status = 'READY', this.total = 0});
  @override
  Future<WalkingReading> read(
    DateTime day, {
    bool requestPermission = false,
  }) async {
    reads++;
    return WalkingReading(
      status: status,
      message: status == 'READY' ? 'تم الربط' : 'تعذّر قراءة الخطوات الآن',
      day: day,
      observedAt: DateTime.now().toUtc(),
      source: supported ? 'HEALTH_CONNECT' : null,
      installation: supported ? 'test-phone' : null,
      total: status == 'READY' ? total : null,
    );
  }

  @override
  Future<void> openSettings() async {}
}

Widget harness(Widget child, WalkingFakeApi api) => Provider<ApiClient>.value(
  value: api,
  child: MaterialApp(
    theme: ThemeData(extensions: const [AtColors.light]),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  test('Arabic and Persian input is accepted without multiplying the goal', () {
    expect(normalizeWalkingNumber('٥٬٠٠٠'), '5000');
    expect(normalizeWalkingNumber('۸۰۰۰'), '8000');
    final d = WalkingDraft();
    d.steps.text = '٥٠٠٠';
    d.mode = 'SCREENSHOT';
    expect(d.validate(), isNull);
    expect(d.toJson()['targetSteps'], 5000);
    d.dispose();
  });
  test(
    'Riyadh day boundaries stay correct independent of local phone timezone',
    () {
      final midnight = walkingNow(DateTime.utc(2026, 10, 25, 22));
      expect(walkingDay(midnight), '2026-10-26');
      expect(walkingDayStartUtc(midnight), DateTime.utc(2026, 10, 25, 21));
      expect(
        walkingTimestamp(DateTime.utc(2026, 10, 25, 22)),
        '2026-10-26T01:00:00.000',
      );
    },
  );
  test(
    'Health mode needs verified preflight; screenshot is selected explicitly',
    () {
      final d = WalkingDraft();
      expect(d.validate(), isNotNull);
      d.mode = 'SCREENSHOT';
      expect(d.validate(), isNull);
      d.steps.text = '99';
      expect(d.validate(), isNotNull);
      d.steps.text = '١٠٠٠٠١';
      expect(d.validate(), isNotNull);
      d.dispose();
    },
  );
  test(
    'Screenshot validation rejects oversized and non-image content before API calls',
    () async {
      final api = WalkingFakeApi();
      final walking = WalkingApi(api);
      await expectLater(
        walking.screenshot(1, walkingNow(), Uint8List(2200001)),
        throwsFormatException,
      );
      await expectLater(
        walking.screenshot(1, walkingNow(), Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      expect(api.requests, isEmpty);
    },
  );
  testWidgets(
    'A real zero read can pass preflight and is persisted before activation',
    (tester) async {
      final draft = WalkingDraft();
      final api = WalkingFakeApi();
      final reader = Reader();
      await tester.pumpWidget(
        harness(
          WalkingSetup(
            draft: draft,
            reader: reader,
            onChanged: () {},
            onUseTimer: () {},
          ),
          api,
        ),
      );
      await tester.ensureVisible(find.text('فحص ربط الخطوات'));
      await tester.tap(find.text('فحص ربط الخطوات'));
      await tester.pumpAndSettle();
      expect(draft.checked, isTrue);
      expect(draft.validate(), isNull);
      expect((api.requests.single['body'] as Map)['stepsRead'], 0);
      await tester.pumpWidget(const SizedBox());
      draft.dispose();
    },
  );
  testWidgets('Failed backend preflight does not allow activation', (
    tester,
  ) async {
    final draft = WalkingDraft();
    final api = WalkingFakeApi()..offline = true;
    await tester.pumpWidget(
      harness(
        WalkingSetup(
          draft: draft,
          reader: Reader(),
          onChanged: () {},
          onUseTimer: () {},
        ),
        api,
      ),
    );
    await tester.ensureVisible(find.text('فحص ربط الخطوات'));
    await tester.tap(find.text('فحص ربط الخطوات'));
    await tester.pumpAndSettle();
    expect(draft.checked, isFalse);
    expect(draft.validate(), isNotNull);
    expect(find.textContaining('ما اكتمل حفظ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    draft.dispose();
  });
  testWidgets(
    'Unsupported platform offers a fallback and never reports fake readiness',
    (tester) async {
      final draft = WalkingDraft();
      final api = WalkingFakeApi();
      await tester.pumpWidget(
        harness(
          WalkingSetup(
            draft: draft,
            reader: Reader(supported: false, status: 'UNAVAILABLE'),
            onChanged: () {},
            onUseTimer: () {},
          ),
          api,
        ),
      );
      await tester.ensureVisible(find.text('فحص ربط الخطوات'));
      await tester.tap(find.text('فحص ربط الخطوات'));
      await tester.pumpAndSettle();
      expect(draft.checked, isFalse);
      expect(api.requests, isEmpty);
      await tester.ensureVisible(find.text('أفضل تعهّد المشي بالدقائق'));
      expect(find.text('أفضل تعهّد المشي بالدقائق'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      draft.dispose();
    },
  );
  Widget screen(WalkingFakeApi api, Reader reader) => Provider<ApiClient>.value(
    value: api,
    child: MaterialApp(
      theme: ThemeData(extensions: const [AtColors.light]),
      home: WalkingScreen(weekId: 1, reader: reader),
    ),
  );
  testWidgets('No observation displays an unknown total, not zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(WalkingFakeApi(), Reader(supported: false, status: 'UNAVAILABLE')),
    );
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('ما وصلتنا قراءة'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Read failure preserves the previously synchronized daily total',
    (tester) async {
      final api = WalkingFakeApi()..progress['totalSteps'] = 3200;
      await tester.pumpWidget(screen(api, Reader(status: 'UNKNOWN')));
      await tester.pumpAndSettle();
      expect(find.text('٣٢٠٠'), findsOneWidget);
      expect(find.text('تعذّر قراءة الخطوات الآن'), findsOneWidget);
      expect(
        api.requests.where((r) => '${r['path']}'.endsWith('/sync')),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Screenshot-only commitment never reads health data', (
    tester,
  ) async {
    final api = WalkingFakeApi()..progress['evidenceMode'] = 'SCREENSHOT';
    final reader = Reader();
    await tester.pumpWidget(screen(api, reader));
    await tester.pumpAndSettle();
    expect(reader.reads, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Initial network failure does not invent a steps target', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        WalkingFakeApi()..offline = true,
        Reader(supported: false, status: 'UNAVAILABLE'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تعذّر الاتصال'), findsOneWidget);
    expect(find.textContaining('٥٠٠٠'), findsNothing);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Already submitted screenshot cannot be uploaded again after rejection',
    (tester) async {
      final api = WalkingFakeApi()
        ..progress.addAll({
          'evidenceMode': 'SCREENSHOT',
          'status': 'REJECTED',
          'screenshotSubmitted': true,
        });
      await tester.pumpWidget(screen(api, Reader()));
      await tester.pumpAndSettle();
      expect(find.text('ارفع صورة خطوات اليوم'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
