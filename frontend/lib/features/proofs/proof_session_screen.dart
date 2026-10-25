import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'camera_capture_screen.dart';
import 'proof_widgets.dart';
import 'proofs_api.dart';
import 'request_forms.dart';
import 'visit_screen.dart';

class ProofStartScreen extends StatefulWidget {
  final Json? activity;
  final int? weekId;
  final int? taskId;
  const ProofStartScreen({super.key, this.activity, this.weekId, this.taskId});
  @override
  State<ProofStartScreen> createState() => _ProofStartScreenState();
}

class _ProofStartScreenState extends State<ProofStartScreen> {
  late final ProofsApi _api = ProofsApi(context.read<ApiClient>());
  late final Future<Json> _activity = _load();
  final _minutes = TextEditingController(text: '25');
  bool _withPhotos = false;
  bool _busy = false;
  int? _beforeId;
  CapturedImage? _before;
  DateTime? _beforeTaken;
  Future<Json> _load() async {
    final tasks =
        widget.activity == null ? await _api.activities() : [widget.activity!];
    final task = tasks.firstWhere((t) =>
        widget.activity != null ||
        (t['weekId'] == widget.weekId && t['goalTaskId'] == widget.taskId));
    if (task['proofMethod'] == 'TIMER') {
      try {
        final value = await _api.client.get(
            '/api/v1/proof-attempt/suggest/${task['weekId']}',
            query: {'goalTaskId': task['goalTaskId']}) as Map;
        if (mounted) _minutes.text = '${value['suggestedMinutes']}';
      } catch (_) {}
    }
    return task;
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _takeBefore() async {
    final photo = await takeProofPhoto(context, 'صورة البداية');
    if (photo == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final id =
          await _api.cameraUpload('BEFORE', photo.bytes, mime: photo.mime);
      if (mounted) {
        setState(() {
          _before = photo;
          _beforeId = id;
          _beforeTaken = DateTime.now();
        });
      }
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(Json activity) async {
    final duration = int.tryParse(_minutes.text);
    if (activity['proofMethod'] == 'TIMER' &&
        (duration == null || duration < 1 || duration > 600)) {
      showMessage(context, 'اختر مدة من دقيقة إلى ٦٠٠ دقيقة.');
      return;
    }
    if (_withPhotos &&
        (_beforeId == null ||
            _beforeTaken == null ||
            DateTime.now().difference(_beforeTaken!).inMinutes >= 5)) {
      showMessage(context, 'التقط صورة البداية، ثم ابدأ خلال خمس دقائق.');
      return;
    }
    setState(() => _busy = true);
    try {
      final proof = await _api.client
          .post('/api/v1/proof-attempt/start/${activity['weekId']}', body: {
        'goalTaskId': activity['goalTaskId'],
        'beforeAfter': _withPhotos,
        'beforeCaptureId': _withPhotos ? _beforeId : null,
        if (activity['proofMethod'] == 'TIMER') 'targetMinutes': duration,
      }) as Map;
      if (mounted) {
        context.pushReplacement(
            '/proofs/session/${proof['id']}?started=1&title=${Uri.encodeComponent('${activity['title']}')}');
      }
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
      future: _activity,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ProofPage(title: 'إثبات النشاط', child: LoadingView());
        }
        if (snapshot.hasError) {
          return const ProofPage(
              title: 'إثبات النشاط',
              child: ErrorView(
                  message:
                      'هذا النشاط غير متاح الآن. ارجع لليوم وحدّث القائمة.'));
        }
        final task = snapshot.data!;
        if (task['proofMethod'] == 'LOCATION') {
          return VisitScreen(activity: task);
        }
        return ProofPage(
            title: 'إثبات النشاط',
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Icon(methodIcon(task['proofMethod'] as String?),
                  size: 54, color: context.colors.primary),
              const SizedBox(height: 20),
              Text('${task['title']}',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(methodNames[task['proofMethod']] ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              ProofNotice(switch (task['proofMethod']) {
                'TIMER' =>
                  'اختر المدة اللي تناسبك. إكمالها يكفي لتوثيق النشاط، وتقدر تاخذ استراحة أو تمدد بعدها.',
                'QUIZ' =>
                  'أربعة أسئلة سهلة، والنجاح من ثلاث. صور الصفحات اختيارية، وإذا ما أرفقت صورًا تكون الأسئلة عامة عن الموضوع.',
                _ =>
                  'بعد تنفيذ النشاط، التقط صورة واضحة مباشرة بالكاميرا. نخلي الإثبات بسيطًا ويركز على إنجازك.',
              }),
              const SizedBox(height: 24),
              if (task['proofMethod'] == 'TIMER') ...[
                TextFormField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'مدة الجلسة بالدقائق',
                        helperText:
                            'المدة مقترحة؛ عدّلها قبل البداية بما يناسبك.')),
                const SizedBox(height: 24),
              ],
              AppCard(
                  child: Column(children: [
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('أضيف صور قبل وبعد'),
                    subtitle: const Text(
                        'اختياري؛ نجاح أي طريقة يكفي لتوثيق النشاط.'),
                    value: _withPhotos,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _withPhotos = value)),
                if (_withPhotos) ...[
                  const SizedBox(height: 12),
                  const Text(
                      'صوّر البداية قبل تنفيذ النشاط، والنهاية بعده. نبحث عن تغيير واضح مرتبط بمهمتك.'),
                  const SizedBox(height: 16),
                  if (_before != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Image.memory(_before!.bytes, height: 180)),
                  AtButton(
                      _before == null
                          ? 'التقط صورة البداية'
                          : 'أعد صورة البداية',
                      kind: AtButtonKind.outline,
                      loading: _busy,
                      onPressed: _takeBefore),
                ],
              ])),
              const SizedBox(height: 24),
              AtButton(
                  task['proofMethod'] == 'TIMER'
                      ? 'ابدأ الجلسة'
                      : 'ابدأ توثيق النشاط',
                  loading: _busy,
                  onPressed: () => _start(task)),
              const SizedBox(height: 8),
              AtButton('عندي عذر بدل الإثبات',
                  kind: AtButtonKind.text,
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ExcuseFormScreen(activities: [task])))),
            ]));
      });
}

class ProofSessionScreen extends StatefulWidget {
  final int proofId;
  final String title;
  final bool justStarted;
  const ProofSessionScreen(
      {super.key,
      required this.proofId,
      required this.title,
      this.justStarted = false});
  @override
  State<ProofSessionScreen> createState() => _ProofSessionScreenState();
}

class _ProofSessionScreenState extends State<ProofSessionScreen> {
  late final ProofsApi _api = ProofsApi(context.read<ApiClient>());
  Json? _state;
  Object? _error;
  bool _busy = false;
  bool _syncing = false;
  Timer? _poll;
  Timer? _clock;
  Timer? _welcomeTimer;
  bool _welcome = false;
  final _extension = TextEditingController(text: '5');
  @override
  void initState() {
    super.initState();
    _welcome = widget.justStarted;
    _welcomeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _welcome = false);
    });
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_busy) _refresh(silent: true);
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _state?['timer'] != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _poll?.cancel();
    _clock?.cancel();
    _extension.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final state = await _api.state(widget.proofId);
      if (state['timer'] != null) {
        state['timer'] = await _api.client.post(
            '/api/v1/proof-attempt/timer/${state['timer']['id']}/state',
            body: {});
        final fresh = await _api.state(widget.proofId);
        state['proof'] = fresh['proof'];
        state['evidence'] = fresh['evidence'];
        state['canObject'] = fresh['canObject'];
      }
      if (mounted) {
        setState(() {
          _state = state;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && !silent) setState(() => _error = error);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photo(String kind) async {
    final photo = await takeProofPhoto(
        context, kind == 'AFTER' ? 'صورة النهاية' : 'صورة إثبات النشاط');
    if (photo == null || !mounted) return;
    await _run(() async {
      final id = await _api.cameraUpload(kind, photo.bytes,
          proofId: widget.proofId, mime: photo.mime);
      if (kind == 'AFTER') {
        await _api.client.post('/api/v1/proof-attempt/${widget.proofId}/after',
            body: {'afterCaptureId': id});
      } else {
        await _api.client.post('/api/v1/proof-attempt/${widget.proofId}/submit',
            body: {'evidenceData': '$id'});
      }
      if (mounted) showMessage(context, 'تم إرفاق الإثبات بنجاح');
    });
  }

  Future<void> _timerAction(String action, {Json body = const {}}) =>
      _run(() async {
        await _api.client.post(
            '/api/v1/proof-attempt/timer/${_state!['timer']['id']}/$action',
            body: body);
      });
  int _elapsed(Json timer) {
    int seconds = (timer['elapsedSeconds'] as num).toInt();
    if (timer['status'] == 'RUNNING') {
      final started = serverInstant(timer['lastStartedAt']);
      final deadline = serverInstant(timer['deadline']);
      final now = DateTime.now();
      final end = deadline != null && now.isAfter(deadline) ? deadline : now;
      if (started != null) {
        seconds += math.max(0, end.difference(started).inSeconds);
      }
    }
    return math.min(
        seconds,
        (timer['requiredSeconds'] as num).toInt() +
            (timer['extensionSeconds'] as num).toInt());
  }

  @override
  Widget build(BuildContext context) {
    if (_state == null) {
      return ProofPage(
          title: widget.title,
          child: _error == null
              ? const LoadingView()
              : ErrorView(message: friendlyError(_error!), onRetry: _refresh));
    }
    final proof = Map<String, dynamic>.from(_state!['proof'] as Map);
    final evidence = ProofsApi.maps(_state!['evidence']);
    final accepted = proof['result'] == 'ACCEPTED';
    final deadline = serverInstant(proof['attemptDeadline']);
    final closed = deadline != null && !DateTime.now().isBefore(deadline);
    final photosWaiting = evidence
        .any((e) => e['type'] == 'BEFORE_AFTER' && e['result'] == 'PENDING');
    return ProofPage(
        title: 'توثيق إنجازك',
        actions: [
          IconButton(
              tooltip: 'تحديث',
              onPressed: () => _refresh(),
              icon: const Icon(Icons.refresh))
        ],
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          StatusBadge.review(proof['result'] as String?),
          if (_welcome) ...[
            const SizedBox(height: 12),
            const ProofNotice('بداية موفقة'),
          ],
          const SizedBox(height: 20),
          if (accepted)
            const ProofNotice(
                'كفو، توثّق إنجازك! ما تحتاج تضيف دليلًا آخر، والنشاط ينحسب مرة واحدة.',
                icon: Icons.verified_outlined),
          if (closed && !accepted)
            const ProofNotice(
                'انتهت مهلة هذه المحاولة. التفاصيل والنتائج محفوظة في سجلك.'),
          if (_state!['timer'] != null)
            _timer(Map<String, dynamic>.from(_state!['timer'] as Map), closed),
          if (proof['type'] == 'PHOTO' && !accepted && !closed) ...[
            const SizedBox(height: 24),
            const ProofNotice(
                'صوّر النتيجة المرتبطة بالنشاط بوضوح. الصورة المباشرة فقط، دون رفع من المعرض.'),
            const SizedBox(height: 16),
            AtButton('التقط صورة الإثبات',
                loading: _busy,
                onPressed: () => _photo('PHOTO'),
                icon: const Icon(Icons.photo_camera_outlined)),
          ],
          if (proof['type'] == 'QUIZ' && !accepted && !closed)
            QuizPanel(
                proofId: widget.proofId,
                weekId: _state!['weekId'] as int,
                taskId: _state!['goalTaskId'] as int?,
                onSubmitted: () => _refresh()),
          if (photosWaiting && !accepted && !closed) ...[
            const SizedBox(height: 24),
            AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('صورك الإضافية',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  const Text(
                      'صورة البداية محفوظة. بعد التنفيذ صوّر النهاية؛ إذا نجحت الصور، يكفي هذا لقبول النشاط.'),
                  const SizedBox(height: 16),
                  AtButton('التقط صورة النهاية',
                      kind: AtButtonKind.outline,
                      loading: _busy,
                      onPressed: () => _photo('AFTER')),
                  AtButton('أكمل بدون الصور الإضافية',
                      kind: AtButtonKind.text,
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await _api.client.post(
                                    '/api/v1/proof-attempt/${widget.proofId}/skip-photos',
                                    body: {});
                              })),
                ])),
          ],
          const SizedBox(height: 24),
          Text('نتيجة كل دليل', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final item in evidence)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(
                            child: Text(item['type'] == 'BEFORE_AFTER'
                                ? 'صور قبل وبعد'
                                : methodNames[item['type']] ?? 'دليل النشاط')),
                        StatusBadge.review(item['result'] as String?)
                      ]),
                      if (item['beforeCaptureId'] != null)
                        ExpansionTile(
                          title: const Text('عرض صور قبل وبعد'),
                          children: [
                            const Text('قبل النشاط'),
                            EvidenceImage('capture:${item['beforeCaptureId']}'),
                            if (item['afterCaptureId'] != null) ...[
                              const SizedBox(height: 12),
                              const Text('بعد النشاط'),
                              EvidenceImage(
                                  'capture:${item['afterCaptureId']}'),
                            ],
                          ],
                        ),
                      if (item['reason'] != null) ...[
                        const SizedBox(height: 10),
                        Text('${item['reason']}',
                            style: Theme.of(context).textTheme.bodySmall)
                      ],
                    ]))),
          if (proof['type'] == 'PHOTO' &&
              '${proof['evidenceData']}'.startsWith('data:image/'))
            EvidenceImage('${proof['evidenceData']}'),
          if (_state!['canObject'] == true) ...[
            const SizedBox(height: 14),
            AtButton('اعترض على القرار', kind: AtButtonKind.outline,
                onPressed: () async {
              if (await editObjection(context,
                      kind: 'PROOF', targetId: widget.proofId) &&
                  context.mounted) {
                showMessage(context, 'وصل اعتراضك، تابع نتيجته من طلباتي.');
                await _refresh();
              }
            })
          ],
          const SizedBox(height: 20),
          AtButton('ارجع لطلباتي',
              kind: AtButtonKind.text,
              onPressed: () => context.go('/requests')),
        ]));
  }

  Widget _timer(Json timer, bool closed) {
    final elapsed = _elapsed(timer);
    final required = (timer['requiredSeconds'] as num).toInt();
    final total = required + (timer['extensionSeconds'] as num).toInt();
    final remaining = math.max(0, total - elapsed);
    final messages = '${timer['messages'] ?? ''}'.split('\n');
    final reached = timer['requiredReachedAt'] != null;
    final messageIndex = reached
        ? 2
        : elapsed >= required / 2
            ? 1
            : 0;
    return Column(children: [
      const SizedBox(height: 30),
      Text(
          switch (timer['status']) {
            'PAUSED' => reached ? 'اكتملت المدة المطلوبة' : 'متوقف مؤقتًا',
            'FINISHED' => 'اكتملت الجلسة',
            'EXPIRED' => 'انتهت مهلة الجلسة',
            _ => 'جارٍ التركيز',
          },
          textAlign: TextAlign.center),
      if (messageIndex > 0)
        Text(
            messageIndex < messages.length
                ? messages[messageIndex]
                : 'خذ وقتك، خطوة خطوة.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 24),
      SizedBox(
          width: 238,
          height: 238,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
                child: CircularProgressIndicator(
                    value: (elapsed / required).clamp(0, 1),
                    strokeWidth: 9,
                    backgroundColor: context.colors.surfaceSunken,
                    strokeCap: StrokeCap.round)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  arabicDigits(
                      '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}'),
                  style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 8),
              Text(timer['status'] == 'RUNNING'
                  ? 'وقت لك ولإنجازك'
                  : reached
                      ? 'اكتملت المدة الأصلية'
                      : 'الجلسة متوقفة')
            ]),
          ])),
      const SizedBox(height: 24),
      if (!closed)
        Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (timer['status'] == 'RUNNING')
                AtButton('خذ استراحة',
                    expand: false,
                    kind: AtButtonKind.outline,
                    onPressed: _busy ? null : () => _timerAction('pause'),
                    icon: const Icon(Icons.pause)),
              if (timer['status'] == 'PAUSED' && elapsed < total)
                AtButton('كمّل الجلسة',
                    expand: false,
                    onPressed: _busy ? null : () => _timerAction('resume'),
                    icon: const Icon(Icons.play_arrow)),
              if (timer['status'] == 'RUNNING' || timer['status'] == 'PAUSED')
                AtButton('أنهِ الجلسة',
                    expand: false,
                    kind: AtButtonKind.text,
                    onPressed: _busy ? null : () => _timerAction('finish')),
            ]),
      const SizedBox(height: 18),
      Text(
          'الاستراحة ما تنحسب من الوقت. تنتهي الجلسة مع نهاية اليوم بتوقيت الرياض.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center),
      if (reached && !closed) ...[
        const SizedBox(height: 24),
        AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ودّك تكمل شوي؟', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'التمديد اختياري، وإنجازك الأصلي محفوظ. خذ راحة إذا احتجت.'),
          const SizedBox(height: 16),
          TextField(
              controller: _extension,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'كم دقيقة إضافية؟')),
          const SizedBox(height: 12),
          AtButton('مدّد الجلسة',
              kind: AtButtonKind.outline,
              onPressed: _busy
                  ? null
                  : () {
                      final minutes = int.tryParse(_extension.text);
                      if (minutes == null || minutes < 1 || minutes > 600) {
                        showMessage(context, 'اختر من دقيقة إلى ٦٠٠ دقيقة.');
                        return;
                      }
                      _timerAction('extend', body: {'minutes': minutes});
                    }),
        ])),
      ],
      if (reached) ...[
        const SizedBox(height: 24),
        Text('كيف كانت الجلسة؟',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final feeling in {
                'EASY': 'سهلة',
                'OK': 'مناسبة',
                'TIRING': 'متعبة'
              }.entries)
                ChoiceChip(
                    label: Text(feeling.value),
                    selected: timer['feedback'] == feeling.key,
                    onSelected: _busy
                        ? null
                        : (_) => _timerAction('feedback',
                            body: {'feedback': feeling.key}))
            ]),
        const SizedBox(height: 8),
        Text('رأيك اختياري وما يغير قبول الإثبات.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ]);
  }
}

class QuizPanel extends StatefulWidget {
  final int proofId;
  final int weekId;
  final int? taskId;
  final Future<void> Function() onSubmitted;
  const QuizPanel(
      {super.key,
      required this.proofId,
      required this.weekId,
      this.taskId,
      required this.onSubmitted});
  @override
  State<QuizPanel> createState() => _QuizPanelState();
}

class _QuizPanelState extends State<QuizPanel> {
  final List<int> _pages = [];
  final Map<int, String?> _answers = {};
  Json? _quiz;
  bool _busy = false;
  String? _notice;
  Timer? _expiryClock;
  String? _pendingAction;
  @override
  void dispose() {
    _expiryClock?.cancel();
    super.dispose();
  }

  Duration? get _remaining {
    final end = serverInstant(_quiz?['expiresAt']);
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _page() async {
    if (_busy) return;
    if (_pages.length >= 6) {
      showMessage(context, 'يكفي حتى ست صور واضحة للصفحات.');
      return;
    }
    final photo = await takeProofPhoto(context, 'صفحة من المحتوى — اختياري');
    if (photo == null || !mounted) return;
    setState(() {
      _busy = true;
      _pendingAction = 'page';
    });
    try {
      final id = await ProofsApi(context.read<ApiClient>()).cameraUpload(
          'PAGE', photo.bytes,
          proofId: widget.proofId, mime: photo.mime);
      if (mounted) {
        setState(() => _pages.add(id));
        showMessage(context, 'تم إرفاق الصفحة بنجاح');
      }
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pendingAction = 'generate';
      _notice = null;
    });
    final client = context.read<ApiClient>();
    final member = context.read<AuthState>().userId;
    try {
      final quiz = Map<String, dynamic>.from(await client.post(
          '/api/v1/quiz/create/$member/${widget.weekId}',
          query: {'goalTaskId': widget.taskId},
          body: {'proofId': widget.proofId, 'captureIds': _pages}) as Map);
      if (!mounted) return;
      setState(() {
        _pages.clear();
        _answers.clear();
        _quiz = quiz['quizId'] == null ? null : quiz;
        _notice = quiz['quizId'] == null
            ? 'الصفحات غير واضحة. صوّر الجزئية مرة ثانية، أو جهّز أسئلة عامة بدون صور. لم تُحتسب عليك محاولة.'
            : null;
      });
      _expiryClock?.cancel();
      if (_quiz != null) {
        _expiryClock = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    } catch (error) {
      if (mounted) setState(() => _notice = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_remaining == Duration.zero) {
      setState(() => _notice =
          'انتهت مهلة الاختبار. جهّز اختبارًا جديدًا إذا كانت لديك محاولة متاحة.');
      return;
    }
    final questions = ProofsApi.maps(_quiz!['questions']);
    if (questions.any((q) => _answers[q['number']] == null)) {
      showMessage(context, 'جاوب الأسئلة الأربعة أولًا.');
      return;
    }
    setState(() {
      _busy = true;
      _pendingAction = 'submit';
    });
    try {
      final letters = questions.map((q) => _answers[q['number']]!).join();
      await context.read<ApiClient>().post(
          '/api/v1/proof-attempt/${widget.proofId}/submit',
          body: {'evidenceData': '${_quiz!['quizId']}:$letters'});
      await widget.onSubmitted();
      if (mounted) {
        setState(() {
          _expiryClock?.cancel();
          _quiz = null;
          _notice =
              'حفظنا الإجابات. راجع نتيجة الدليل بالأسفل؛ إذا ما نجحت المحاولة الأولى تقدر تطلب إعادة واحدة.';
        });
      }
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 24),
      child: AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('اختبار خفيف على إنجازك',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const Text(
            '٤ أسئلة سهلة، والنجاح من ٣. صلاحية الاختبار ساعة من إصداره، وتوجد إعادة واحدة فقط.'),
        const SizedBox(height: 16),
        if (_notice != null) ...[
          ProofNotice(_notice!),
          const SizedBox(height: 16)
        ],
        if (_busy && _pendingAction == 'generate') ...[
          const ProofNotice('جارٍ تجهيز الأسئلة…'),
          const SizedBox(height: 12),
        ],
        if (_quiz == null) ...[
          AtButton('صوّر صفحة — اختياري',
              kind: AtButtonKind.outline, onPressed: _busy ? null : _page),
          for (final id in _pages) EvidenceImage('capture:$id'),
          if (_pages.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('صور مرفقة: ${arabicDigits(_pages.length)}')),
          const SizedBox(height: 10),
          AtButton('جهّز الأسئلة',
              loading: _busy, onPressed: _busy ? null : _generate),
        ] else ...[
          if (_remaining == Duration.zero)
            AtButton('جهّز اختبارًا جديدًا',
                loading: _busy, onPressed: _generate),
          if (_remaining != null) ...[
            Text(_remaining == Duration.zero
                ? 'انتهى وقت الاختبار'
                : 'الوقت المتبقي: ${arabicDigits(_remaining!.inMinutes.toString().padLeft(2, '0'))}:${arabicDigits((_remaining!.inSeconds % 60).toString().padLeft(2, '0'))}'),
            const SizedBox(height: 16),
          ],
          for (final (i, question)
              in ProofsApi.maps(_quiz!['questions']).indexed)
            Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${arabicDigits(i + 1)}. ${question['question']}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      RadioGroup<String>(
                          groupValue: _answers[question['number']],
                          onChanged: (value) {
                            if (!_busy && _remaining != Duration.zero) {
                              setState(() =>
                                  _answers[question['number'] as int] = value);
                            }
                          },
                          child: Column(children: [
                            for (final (option, text)
                                in (question['options'] as List).indexed)
                              RadioListTile<String>(
                                  contentPadding: EdgeInsets.zero,
                                  value: 'ABC'[option],
                                  title: Text('$text')),
                          ])),
                    ])),
          AtButton('أرسل الإجابات',
              loading: _busy,
              onPressed: _remaining == Duration.zero ? null : _submit),
        ],
      ])));
}
