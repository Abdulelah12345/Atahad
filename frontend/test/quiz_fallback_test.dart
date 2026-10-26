import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atahad/core/api/api_exception.dart';
import 'package:atahad/features/proofs/camera_capture_screen.dart';
import 'package:atahad/features/proofs/proof_session_screen.dart';
import 'support/proofs_fake_api.dart';
import 'proofs_widgets_test.dart' as ui;

class FallbackQuizApi extends ProofsFakeApi {
  final bool unreadable;
  final bool unclear;
  final bodies = <Map<String, dynamic>>[];
  final topics = <Object?>[];
  final image = File('assets/images/app_icon_square.png').readAsBytesSync();
  FallbackQuizApi({this.unreadable = false, this.unclear = false});
  @override
  Future<dynamic> get(String path, {Map<String, Object?>? query}) async {
    if (path.contains('/attachment/'))
      return {'imageData': 'data:image/png;base64,${base64Encode(image)}'};
    return super.get(path, query: query);
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool auth = true,
  }) async {
    if (path.endsWith('/proof-attempt/capture'))
      return {'captureId': 77, 'token': 'test-ticket'};
    if (path.endsWith('/capture/77')) return {'message': 'uploaded'};
    if (path.contains('/quiz/create/')) {
      final request = Map<String, dynamic>.from(body as Map);
      bodies.add({
        ...request,
        'captureIds': List<int>.from(request['captureIds'] as List),
      });
      topics.add(query?['topic']);
      if ((request['captureIds'] as List).isNotEmpty) {
        if (unreadable)
          return {
            'quizId': null,
            'questions': [],
            'howToAnswer': 'REUPLOAD_PAGES',
          };
        throw ApiException(
          503,
          'Quiz generation is unavailable; no quiz attempt was consumed',
        );
      }
      if (unclear && query?['topic'] == null)
        throw ApiException(
          400,
          'Quiz topic is unclear; specify the activity topic; no quiz attempt was consumed',
        );
    }
    return super.post(path, body: body, query: query, auth: auth);
  }
}

void main() {
  for (final unreadable in [false, true]) {
    testWidgets(
      'No-image generation remains available after ${unreadable ? 'unreadable pages' : 'image analysis outage'}',
      (tester) async {
        final api = FallbackQuizApi(unreadable: unreadable);
        await tester.pumpWidget(
          ui.harness(
            SingleChildScrollView(
              child: QuizPanel(
                proofId: 102,
                weekId: 2,
                onSubmitted: () async {},
              ),
            ),
            api,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('صوّر صفحة — اختياري'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        // Return an approved camera result; no physical camera or external upload is used.
        Navigator.of(
          tester.element(find.byType(CameraCaptureScreen)),
        ).pop(CapturedImage(api.image, 'image/png'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('جهّز الأسئلة من الصور'));
        await tester.tap(find.text('جهّز الأسئلة من الصور'));
        await tester.pumpAndSettle();
        expect(api.bodies.single['captureIds'], [77]);
        await tester.ensureVisible(find.text('جهّز الأسئلة بدون صور'));
        await tester.tap(find.text('جهّز الأسئلة بدون صور'));
        await tester.pumpAndSettle();
        expect(api.bodies.last['captureIds'], isEmpty);
        expect(find.byType(RadioGroup<String>), findsNWidgets(4));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Vague topic can be clarified without a camera or changing the activity',
    (tester) async {
      final api = FallbackQuizApi(unclear: true);
      await tester.pumpWidget(
        ui.harness(
          SingleChildScrollView(
            child: QuizPanel(proofId: 102, weekId: 2, onSubmitted: () async {}),
          ),
          api,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('جهّز الأسئلة بدون صور'));
      await tester.pumpAndSettle();
      expect(find.textContaining('لم تُحتسب عليك محاولة'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'أساسيات التغذية المتوازنة',
      );
      await tester.ensureVisible(find.text('جهّز الأسئلة بدون صور'));
      await tester.tap(find.text('جهّز الأسئلة بدون صور'));
      await tester.pumpAndSettle();
      expect(api.topics.last, 'أساسيات التغذية المتوازنة');
      expect(api.bodies.last['proofId'], 102);
      expect(api.bodies.last['captureIds'], isEmpty);
      expect(find.byType(RadioGroup<String>), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
