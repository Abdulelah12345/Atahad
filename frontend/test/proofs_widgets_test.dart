import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:atahad/core/api/api_client.dart';
import 'package:atahad/core/api/api_exception.dart';
import 'package:atahad/core/auth/auth_state.dart';
import 'package:atahad/core/theme/at_colors.dart';
import 'package:atahad/core/widgets/widgets.dart';
import 'package:atahad/features/proofs/proofs_home_screen.dart';
import 'package:atahad/features/proofs/proof_session_screen.dart';
import 'package:atahad/features/proofs/request_forms.dart';
import 'package:atahad/features/proofs/proof_widgets.dart';
import 'package:atahad/features/commitments/create_commitment_screen.dart';
import 'support/proofs_fake_api.dart';

Widget harness(Widget child, ProofsFakeApi api) => MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthState>(create: (_) => ProofsFakeAuth(api)),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AtColors.light]),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets(
      'Identical goal and task titles display only once, including old links',
      (tester) async {
    await tester.pumpWidget(harness(
        const ActivityHeading(title: 'ترتيب المكتب - ترتيب المكتب'),
        ProofsFakeApi()));
    expect(find.text('ترتيب المكتب'), findsOneWidget);
    expect(find.text('ترتيب المكتب - ترتيب المكتب'), findsNothing);
    await tester.pumpWidget(harness(
        const ActivityHeading(
            title: 'ترتيب المكتب',
            goalTitle: 'ترتيب المكتب',
            taskTitle: 'ترتيب المكتب'),
        ProofsFakeApi()));
    expect(find.text('ترتيب المكتب'), findsOneWidget);
  });

  testWidgets('Different task title is the heading and goal title is secondary',
      (tester) async {
    await tester.pumpWidget(harness(
        const ActivityHeading(
            title: 'goal - task',
            goalTitle: 'هدف القراءة',
            taskTitle: 'قراءة الفصل الأول'),
        ProofsFakeApi()));
    expect(find.text('قراءة الفصل الأول'), findsOneWidget);
    expect(find.text('هدف القراءة'), findsOneWidget);
    expect(find.text('goal - task'), findsNothing);
  });

  testWidgets('Submitted photo awaiting admin review cannot be captured again',
      (tester) async {
    final api = ProofsFakeApi();
    final state = api.session(103);
    state['proof']['result'] = 'ESCALATED';
    state['proof']['primaryCaptureId'] = 22;
    state['evidence'][0]['result'] = 'ESCALATED';
    await tester.pumpWidget(harness(
        const ProofSessionScreen(
            proofId: 103, title: 'ترتيب المكتب - ترتيب المكتب'),
        api));
    await tester.pumpAndSettle();
    expect(find.text('ترتيب المكتب'), findsOneWidget);
    expect(find.text('التقط صورة الإثبات'), findsNothing);
    expect(find.textContaining('صوّر النتيجة'), findsNothing);
    expect(find.text('نتيجة كل دليل'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Photo attempt without a submitted image keeps capture available',
      (tester) async {
    await tester.pumpWidget(harness(
        const ProofSessionScreen(proofId: 103, title: 'ترتيب المكتب'),
        ProofsFakeApi()));
    await tester.pumpAndSettle();
    expect(find.text('التقط صورة الإثبات'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Welcome expires while the timer state remains visible',
      (tester) async {
    await tester.pumpWidget(harness(
        const ProofSessionScreen(
            proofId: 101, title: 'جلسة تركيز', justStarted: true),
        ProofsFakeApi()));
    await tester.pumpAndSettle();
    expect(find.text('بداية موفقة'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('بداية موفقة'), findsNothing);
    expect(find.text('جارٍ التركيز'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Goal plan can be requested and reviewed without entering identifiers',
      (tester) async {
    final api = GoalPlanApi();
    await tester.pumpWidget(harness(const CreateCommitmentScreen(), api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'جلسة تركيز');
    await tester.tap(find.text('اقترح خطة وطريقة إثبات'));
    await tester.pumpAndSettle();
    expect(find.text('جلسة تركيز'), findsWidgets);
    expect(find.text('الأسبوع 1'), findsOneWidget);
    expect(find.text('رقم الأسبوع'), findsNothing);
    expect(api.posts, ['/api/v1/goal/suggest']);
  });
  testWidgets('Excuse cannot be submitted without an uploaded document', (
    tester,
  ) async {
    final api = ProofsFakeApi();
    await tester.pumpWidget(
      harness(ExcuseFormScreen(activities: [api.tasks.first]), api),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('أرسل العذر'), 300);
    await tester.tap(find.text('أرسل العذر'));
    await tester.pumpAndSettle();
    expect(
      find.text('أرفق مستندًا داعمًا للعذر قبل الإرسال.'),
      findsOneWidget,
    );
    expect(api.posts, isEmpty);
  });

  testWidgets(
    'Quiz outage displays an Arabic inline message without questions',
    (tester) async {
      final api = UnavailableQuizApi();
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(
            child: QuizPanel(proofId: 102, weekId: 2, onSubmitted: () async {}),
          ),
          api,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('جهّز الأسئلة'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'تعذر تجهيز الأسئلة الآن. حاول لاحقًا، لم تُحتسب عليك محاولة.',
        ),
        findsOneWidget,
      );
      expect(find.text('أرسل الإجابات'), findsNothing);
      expect(find.text('صوّر صفحة — اختياري'), findsOneWidget);
    },
  );

  testWidgets(
      'Empty requests render on a narrow screen without allowing an unrelated excuse',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness(
        const ProofsHomeScreen(initialTab: 2, requestsOnly: true),
        ProofsFakeApi(empty: true)));
    await tester.pumpAndSettle();
    expect(find.text('طلباتي'), findsOneWidget);
    final create =
        tester.widget<AtButton>(find.widgetWithText(AtButton, 'تقديم عذر'));
    expect(create.onPressed, isNull);
    await tester.scrollUntilVisible(find.text('السجل هادئ للحين'), 250);
    expect(find.text('السجل هادئ للحين'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('An objection already under review has no edit or delete action',
      (tester) async {
    await tester.pumpWidget(harness(
        RecordDetails(item: const {
          'id': 4,
          'title': 'قراءة كتاب',
          'status': 'PENDING',
          'reason': 'سبب الاعتراض',
          'reviewStartedAt': '2026-10-24T10:00:00',
          'canEdit': false,
          'canDelete': false,
        }, kind: 'OBJECTION', onChanged: () async {}),
        ProofsFakeApi()));
    await tester.pumpAndSettle();
    expect(find.text('عدّل الطلب'), findsNothing);
    expect(find.text('احذف الطلب'), findsNothing);
    expect(find.textContaining('بدأ الأدمن'), findsOneWidget);
  });

  testWidgets('Empty objection reason stays in the editor and sends no request',
      (tester) async {
    final api = ProofsFakeApi();
    await tester.pumpWidget(
        harness(const ObjectionEditor(kind: 'PROOF', targetId: 1), api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أرسل الطلب'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب سبب الاعتراض.'), findsOneWidget);
    expect(api.posts, isEmpty);
  });

  testWidgets('Quiz has four questions and cannot submit unanswered questions',
      (tester) async {
    final api = ProofsFakeApi();
    await tester.pumpWidget(harness(
        SingleChildScrollView(
            child:
                QuizPanel(proofId: 102, weekId: 2, onSubmitted: () async {})),
        api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('جهّز الأسئلة'));
    await tester.pumpAndSettle();
    expect(find.byType(RadioGroup<String>), findsNWidgets(4));
    expect(find.byType(RadioListTile<String>), findsNWidgets(12));
    await tester.ensureVisible(find.text('أرسل الإجابات'));
    await tester.tap(find.text('أرسل الإجابات'));
    await tester.pumpAndSettle();
    expect(find.text('جاوب الأسئلة الأربعة أولًا.'), findsOneWidget);
    expect(api.posts.where((p) => p.endsWith('/submit')), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Timer rejects zero duration before creating a proof',
      (tester) async {
    final api = ProofsFakeApi();
    await tester
        .pumpWidget(harness(ProofStartScreen(activity: api.tasks.first), api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(AtButton, 'ابدأ الجلسة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدأ الجلسة'));
    await tester.pumpAndSettle();
    expect(find.text('اختر مدة من دقيقة إلى ٦٠٠ دقيقة.'), findsOneWidget);
    expect(api.posts, isEmpty);
  });
}

class UnavailableQuizApi extends ProofsFakeApi {
  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool auth = true,
  }) async {
    if (path.contains('/quiz/create/')) {
      throw ApiException(
        400,
        'Quiz generation is unavailable; no quiz attempt was consumed',
      );
    }
    return super.post(path, body: body, query: query, auth: auth);
  }
}

class GoalPlanApi extends ProofsFakeApi {
  @override
  Future<dynamic> post(String path,
      {Object? body, Map<String, Object?>? query, bool auth = true}) async {
    if (path == '/api/v1/goal/suggest') {
      posts.add(path);
      return {
        'title': 'جلسة تركيز',
        'proofMethod': 'TIMER',
        'note': 'راجع الخطة',
        'weeks': [
          {'title': 'جلسة تركيز', 'timesPerWeek': 3}
        ]
      };
    }
    return super.post(path, body: body, query: query, auth: auth);
  }
}
