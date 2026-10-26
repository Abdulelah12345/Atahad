import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:atahad/core/api/api_client.dart';
import 'package:atahad/core/theme/at_colors.dart';
import 'package:atahad/core/widgets/widgets.dart';
import 'package:atahad/features/proofs/proofs_home_screen.dart';
import 'support/proofs_fake_api.dart';

ProofsFakeApi fixture() {
  final api = ProofsFakeApi();
  api.workspace['excuses'] = [
    {
      'id': 1,
      'title': 'ترتيب مكتبي',
      'status': 'ESCALATED',
      'activityTime': '2026-10-26',
      'canObject': false,
    },
    {
      'id': 2,
      'title': 'سفر عمل',
      'status': 'REJECTED',
      'activityTime': '2026-10-25',
      'canObject': true,
    },
    {
      'id': 3,
      'title': 'موعد طبي',
      'status': 'ACCEPTED',
      'activityTime': '2026-10-18',
      'canObject': false,
    },
  ];
  api.workspace['objections'] = [
    {
      'id': 4,
      'title': 'اعتراض سابق',
      'status': 'PENDING',
      'createdAt': '2026-10-26T10:00:00',
      'canObject': false,
    },
  ];
  return api;
}

Widget app(ProofsFakeApi api, {bool dark = false}) => Provider<ApiClient>.value(
  value: api,
  child: MaterialApp(
    theme: ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      extensions: [dark ? AtColors.dark : AtColors.light],
    ),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const ProofsHomeScreen(requestsOnly: true),
  ),
);
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'Reference hierarchy and counts replace the crowded requests header',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(app(fixture()));
      await tester.pumpAndSettle();
      expect(find.text('إرفاق الأعذار والاعتراضات'), findsOneWidget);
      expect(find.text('الأعذار (٣)'), findsOneWidget);
      expect(find.text('الاعتراضات (١)'), findsOneWidget);
      expect(
        tester
            .widget<AtButton>(find.widgetWithText(AtButton, 'تقديم عذر'))
            .kind,
        AtButtonKind.gold,
      );
      expect(find.text('عرض التبرعات والمبالغ'), findsNothing);
      expect(find.text('سجل إثباتاتي'), findsNothing);
      await tester.tap(find.byTooltip('خيارات طلباتي'));
      await tester.pumpAndSettle();
      expect(find.text('التبرعات والمبالغ'), findsOneWidget);
      expect(find.text('سجل إثباتاتي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Inline objection belongs only to rejected eligible excuse and opens its editor',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(app(fixture()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('اعترض على القرار'), 180);
      expect(find.text('اعترض على القرار'), findsOneWidget);
      await tester.tap(find.text('اعترض على القرار'));
      await tester.pumpAndSettle();
      expect(find.text('سبب الاعتراض'), findsWidgets);
      expect(find.text('أرسل الطلب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Expired rejected excuse never offers another objection', (
    tester,
  ) async {
    final api = fixture();
    (api.workspace['excuses'] as List)[1]['canObject'] = false;
    phone(tester);
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('اعترض على القرار'), findsNothing);
  });
  testWidgets(
    'Filters and tabs preserve status semantics and reset the selected filter',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(app(fixture()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('قيد الانتظار'));
      await tester.pumpAndSettle();
      expect(find.text('ترتيب مكتبي'), findsOneWidget);
      expect(find.text('سفر عمل'), findsNothing);
      await tester.tap(find.text('الاعتراضات (١)'));
      await tester.pumpAndSettle();
      expect(find.text('اعتراض سابق'), findsOneWidget);
      expect(find.text('اعترض على القرار'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Compact dark layout fits a narrow phone and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: app(fixture(), dark: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
