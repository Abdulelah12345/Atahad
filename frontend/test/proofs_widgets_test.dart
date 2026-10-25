import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:atahad/core/api/api_client.dart';
import 'package:atahad/core/auth/auth_state.dart';
import 'package:atahad/core/theme/at_colors.dart';
import 'package:atahad/core/widgets/widgets.dart';
import 'package:atahad/features/proofs/proofs_home_screen.dart';
import 'package:atahad/features/proofs/proof_session_screen.dart';
import 'package:atahad/features/proofs/request_forms.dart';
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
    expect(find.text('عدّلي الطلب'), findsNothing);
    expect(find.text('احذفي الطلب'), findsNothing);
    expect(find.textContaining('بدأ الأدمن'), findsOneWidget);
  });

  testWidgets('Empty objection reason stays in the editor and sends no request',
      (tester) async {
    final api = ProofsFakeApi();
    await tester.pumpWidget(
        harness(const ObjectionEditor(kind: 'PROOF', targetId: 1), api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أرسلي الطلب'));
    await tester.pumpAndSettle();
    expect(find.text('اكتبي سبب الاعتراض.'), findsOneWidget);
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
    await tester.tap(find.text('جهّزي الأسئلة'));
    await tester.pumpAndSettle();
    expect(find.byType(RadioGroup<String>), findsNWidgets(4));
    expect(find.byType(RadioListTile<String>), findsNWidgets(12));
    await tester.ensureVisible(find.text('أرسلي الإجابات'));
    await tester.tap(find.text('أرسلي الإجابات'));
    await tester.pumpAndSettle();
    expect(find.text('جاوبي الأسئلة الأربعة أولًا.'), findsOneWidget);
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
    await tester.ensureVisible(find.widgetWithText(AtButton, 'ابدئي الجلسة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابدئي الجلسة'));
    await tester.pumpAndSettle();
    expect(find.text('اختاري مدة من دقيقة إلى ٦٠٠ دقيقة.'), findsOneWidget);
    expect(api.posts, isEmpty);
  });
}
