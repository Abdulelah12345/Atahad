import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/at_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'walking_api.dart';
import 'walking_health.dart';

String walkingError(Object error) {
  if (error is FormatException) return error.message;
  final raw = error is ApiException ? error.message : '$error';
  if (RegExp(r'[\u0600-\u06ff]').hasMatch(raw)) return raw;
  if (raw.contains('window') || raw.contains('day is invalid')) {
    return 'انتهت مهلة هذا اليوم أو اليوم خارج أسبوع التعهّد.';
  }
  if (raw.contains('already submitted')) {
    return 'صورة هذا اليوم مرفوعة بالفعل. تابع حالتها من الطلبات.';
  }
  if (raw.contains('same data source')) {
    return 'استخدم نفس الجوال ومصدر الخطوات لهذا اليوم، أو ارفع صورة للمراجعة.';
  }
  if (raw.contains('Recheck')) {
    return 'أعد فحص ربط الخطوات على هذا الجوال أولًا.';
  }
  if (raw.contains('already covered')) {
    return 'هذا اليوم أو الأسبوع محسوب بالفعل.';
  }
  if (raw.contains('objection')) {
    return 'انتظر نتيجة الاعتراض السابق لهذا اليوم.';
  }
  return 'ما اكتمل التحديث. خطواتك السابقة محفوظة؛ تحقق من الاتصال وحاول ثانية.';
}

class WalkingScreen extends StatefulWidget {
  final int weekId;
  final String title;
  final int? commitmentId;
  final DateTime? day;
  final WalkingHealthReader? reader;
  const WalkingScreen({
    super.key,
    required this.weekId,
    this.title = 'المشي اليومي',
    this.commitmentId,
    this.day,
    this.reader,
  });
  @override
  State<WalkingScreen> createState() => _WalkingScreenState();
}

class _WalkingScreenState extends State<WalkingScreen>
    with WidgetsBindingObserver {
  late final _api = WalkingApi(context.read<ApiClient>());
  late final _reader = widget.reader ?? NativeWalkingHealthReader();
  late int _weekId = widget.weekId;
  late DateTime _day = widget.day ?? walkingNow();
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _history = [];
  String? _message;
  bool _busy = false;
  bool _initial = true;
  Timer? _timer;
  bool get _windowOpen => DateTime.now().toUtc().isBefore(
    walkingDayStartUtc(_day).add(const Duration(days: 2)),
  );
  bool get _accepted => _progress?['status'] == 'ACCEPTED';
  bool get _reviewing => _progress?['status'] == 'ESCALATED';
  bool get _healthMode => _progress?['evidenceMode'] != 'SCREENSHOT';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_busy &&
          _healthMode &&
          _reader.supported &&
          _windowOpen &&
          !_accepted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _sync();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_busy &&
        ModalRoute.of(context)?.isCurrent == true)
      _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.commitmentId != null && _history.isEmpty) {
        final data = await _api.client.get(
          '/api/v1/commitment-week/getHistory/${widget.commitmentId}',
        );
        _history = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      final result = await _api.progress(_weekId, _day);
      if (mounted) {
        setState(() {
          _progress = result;
          _message = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = walkingError(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _initial = false;
        });
      }
    }
    if (mounted &&
        _progress != null &&
        _healthMode &&
        _reader.supported &&
        _windowOpen &&
        !_accepted &&
        !_reviewing) {
      await _sync();
    }
  }

  Future<void> _sync({bool requestPermission = false}) async {
    if (_busy || !_windowOpen || !_healthMode) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // Preflight always reads today, even when synchronizing yesterday's delayed data.
      final today = await _reader.read(
        walkingNow(),
        requestPermission: requestPermission,
      );
      if (!mounted) return;
      if (today.source != null && today.installation != null) {
        await _api.check(today.connectionBody);
      }
      if (!today.ready) {
        if (mounted) setState(() => _message = today.message);
        return;
      }
      final reading = walkingDay(_day) == walkingDay(walkingNow())
          ? today
          : await _reader.read(_day);
      if (!reading.ready) {
        if (mounted) setState(() => _message = reading.message);
        return;
      }
      final progress = await _api.sync(_weekId, reading.syncBody);
      if (mounted) {
        setState(() {
          _progress = progress;
          _message = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = walkingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectDay(DateTime day) async {
    if (_busy) return;
    var id = widget.weekId;
    if (_history.isNotEmpty) {
      final matching = _history.where(
        (w) =>
            walkingDay(day).compareTo('${w['weekStart']}'.substring(0, 10)) >=
                0 &&
            walkingDay(day).compareTo('${w['weekEnd']}'.substring(0, 10)) <= 0,
      );
      if (matching.isEmpty) {
        showMessage(context, 'التعهّد ما كان بدأ في هذا اليوم.');
        return;
      }
      id = (matching.first['id'] as num).toInt();
    }
    setState(() {
      _day = day;
      _weekId = id;
      _progress = null;
      _message = null;
    });
    await _load();
  }

  Future<void> _upload() async {
    if (_busy || !_windowOpen || _accepted || _reviewing) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2200000) {
        throw const FormatException('اختر صورة حجمها أقل من ٢٫٢ ميغابايت.');
      }
      if (!mounted) return;
      var checked = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('راجع صورة خطواتك'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'يوم ${arabicDigits(walkingDay(_day))} · الهدف ${arabicDigits(_progress?['targetSteps'])} خطوة',
                  ),
                  const SizedBox(height: 12),
                  Image.memory(
                    bytes,
                    height: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Text('تعذّر عرض الصورة. اختر PNG أو JPEG.'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: checked,
                    onChanged: (v) => update(() => checked = v!),
                    title: const Text(
                      'الصورة توضح التاريخ الكامل ومجموع خطوات هذا اليوم',
                    ),
                  ),
                  const Text(
                    'الصورة تروح للمراجعة؛ ما ينحسب الإنجاز تلقائيًا.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('رجوع'),
              ),
              FilledButton(
                onPressed: checked
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('إرسال للمراجعة'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      final progress = await _api.screenshot(_weekId, _day, bytes);
      if (mounted) {
        setState(() {
          _progress = progress;
          _message = 'وصلت صورتك للمراجعة. تقدر تتابع القرار من الطلبات.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = walkingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final total = (_progress?['totalSteps'] as num?)?.toInt();
    final target = (_progress?['targetSteps'] as num?)?.toInt() ?? 5000;
    final ratio = ((total ?? 0) / target.clamp(1, 100000)).clamp(0.0, 1.0);
    final status = switch (_progress?['status']) {
      'ACCEPTED' => 'إنجازك موثّق',
      'ESCALATED' => 'بانتظار مراجعة الصورة',
      'REJECTED' => 'راجع نتيجة الإثبات في الطلبات',
      'COVERED_BY_EXCUSE' => 'لهذا اليوم طلب عذر',
      'SYNC_WINDOW_ENDED' => 'انتهت مهلة المزامنة',
      'IN_PROGRESS' => 'كل خطوة تقرّبك',
      _ => 'بانتظار أول مزامنة',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'تحديث الحالة',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _initial
          ? const Center(child: CircularProgressIndicator())
          : _progress == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_message ?? 'تعذّر تحميل هدفك الآن.'),
                    const SizedBox(height: 16),
                    AtButton(
                      'إعادة المحاولة',
                      loading: _busy,
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_history.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final offset in [0, 1])
                          ChoiceChip(
                            label: Text(
                              offset == 0 ? 'اليوم' : 'أمس · مزامنة متأخرة',
                            ),
                            selected:
                                walkingDay(_day) ==
                                walkingDay(
                                  walkingNow().subtract(Duration(days: offset)),
                                ),
                            onSelected: _busy
                                ? null
                                : (_) => _selectDay(
                                    walkingNow().subtract(
                                      Duration(days: offset),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [c.deep, c.deepRaised]),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          arabicDigits(walkingDay(_day)),
                          style: text.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 180,
                          width: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: ratio,
                                  strokeWidth: 10,
                                  color: c.gold,
                                  backgroundColor: Colors.white12,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _accepted
                                        ? Icons.check_rounded
                                        : Icons.directions_walk_rounded,
                                    color: c.gold,
                                    size: 30,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    total == null ? '—' : arabicDigits(total),
                                    style: text.headlineLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'من ${arabicDigits(target)} خطوة',
                                    style: text.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          status,
                          style: text.titleMedium?.copyWith(
                            color: _accepted ? c.goldLight : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'مجموع اليوم · بتوقيت الرياض',
                          style: text.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(child: Text(_message!)),
                    ),
                  if (_progress == null)
                    AtButton('إعادة المحاولة', loading: _busy, onPressed: _load)
                  else ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'خطوات متفرقة، إنجاز واحد',
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'ما تحتاج تبدأ جلسة أو تخلي التطبيق مفتوحًا طول المشي. نحسب مجموع يومك من تطبيق الصحة.',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _progress?['lastSyncedAt'] == null
                                ? 'ما وصلتنا قراءة بعد؛ هذا ما يعني أن خطواتك صفر.'
                                : 'آخر مزامنة: ${arabicDigits('${_progress!['lastSyncedAt']}'.replaceFirst('T', ' ').split('.').first)}',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_healthMode && _windowOpen) ...[
                      AtButton(
                        _reader.supported ? 'مزامنة خطواتي' : 'فحص ربط الجوال',
                        loading: _busy,
                        onPressed: () => _sync(requestPermission: true),
                        icon: const Icon(Icons.sync),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy || !_reader.supported
                            ? null
                            : () async {
                                try {
                                  await _reader.openSettings();
                                } catch (_) {
                                  if (context.mounted) {
                                    showMessage(
                                      context,
                                      'افتح إعدادات الصحة من جهازك.',
                                    );
                                  }
                                }
                              },
                        child: const Text('إعدادات ربط الخطوات'),
                      ),
                    ],
                    if (_windowOpen &&
                        !_accepted &&
                        !_reviewing &&
                        _progress?['screenshotSubmitted'] != true)
                      AtButton(
                        _healthMode
                            ? 'الربط ما اشتغل؟ أرفع صورة'
                            : 'ارفع صورة خطوات اليوم',
                        kind: AtButtonKind.outline,
                        loading: _busy && !_healthMode,
                        onPressed: _busy ? null : _upload,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _windowOpen
                          ? 'تقدر تزامن هذا اليوم أو ترفع صورته حتى ${arabicDigits(walkingDay(_day.add(const Duration(days: 2))))} الساعة ٠٠:٠٠ بتوقيت الرياض. الصور قيد المراجعة تنتظر قرار المشرف.'
                          : 'انتهت مهلة رفع البيانات لهذا اليوم. راجع حالة الإثبات والاعتراض من الطلبات.',
                      style: text.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
