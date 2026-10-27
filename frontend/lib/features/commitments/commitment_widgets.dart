import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitments_api.dart' show isoDate;

// OWNER: Turki - small pieces shared by the commitments screens

const proofMethodsAr = {
  'PHOTO': 'صورة من الكاميرا',
  'LOCATION': 'الموقع (نادي، مكتبة...)',
  'TIMER': 'مؤقت',
  'QUIZ': 'سؤال فهم (كتاب أو كورس)',
};

const pointReasonsAr = {
  'TASK_DONE': 'مرة انقبل إثباتها',
  'FULL_WEEK': 'أسبوع كامل',
  'GOLDEN_WEEK': 'أسبوع ذهبي للقروب',
  'MATCH_ALL_DONE': 'كل القروب خلّص المنافسة',
  'MATCH_WIN': 'الفوز بمنافسة',
  'LEAST_PROCRASTINATION': 'الأقل تسويف',
  'GRACE_DAY_REDEEMED': 'بدّلتها ببطاقة عفو',
};

const graceSourcesAr = {
  'PERSONAL_POINTS': 'من نقاطك',
  'GROUP_POINTS': 'من نقاط القروب',
  'ADMIN_GRANTED': 'من الإدارة',
  'COMPENSATION': 'تعويض عن عذر',
};

// ACTIVE / WITHDRAWN / ENDED of a habit or a goal
StatusBadge commitmentStatusBadge(String? status) => switch (status) {
      'ACTIVE' => const StatusBadge('شغّال', kind: BadgeKind.success),
      'WITHDRAWN' => const StatusBadge('منسحب', kind: BadgeKind.danger),
      'ENDED' => const StatusBadge('انتهى', kind: BadgeKind.info),
      _ => StatusBadge(status ?? '-'),
    };

// a title above a group of cards
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.s4, bottom: Space.s2),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// a label and a value in one line
class InfoRow extends StatelessWidget {
  final String label;
  final Widget value;

  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s1),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          value,
        ],
      ),
    );
  }
}

// - 3 + for the times per week (1 to 7)
class TimesStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const TimesStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 7});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text(arabicDigits(value),
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

// the times of a week as 7 big numbers in a row (the design): the chosen one is raised and blue
class NumberRow extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged; // null = locked
  final int min;
  final int max;

  const NumberRow({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 7});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var n = 1; n <= 7; n++) ...[
          if (n > 1) const SizedBox(width: 6),
          Expanded(
            child: Builder(builder: (context) {
              final on = n == value;
              final allowed = onChanged != null && n >= min && n <= max;
              return Semantics(
                button: true,
                selected: on,
                label: '${arabicDigits(n)} مرات',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: allowed ? () => onChanged!(n) : null,
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.easePop,
                    height: 46,
                    transform: Matrix4.translationValues(0, on ? -2 : 0, 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? c.accent : c.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: on ? [BoxShadow(color: c.primary, offset: const Offset(0, 3))] : null,
                    ),
                    child: Text(
                      arabicDigits(n),
                      style: text.titleMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: on ? 18 : 16,
                        color: on ? Colors.white : (allowed ? c.inkMuted : c.inkSubtle.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

// the amount of one time: quick choices (5 / 10 / 20) and «غيره» opens the field
class AmountChips extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool enabled;

  const AmountChips({super.key, required this.controller, required this.onChanged, this.enabled = true});

  @override
  State<AmountChips> createState() => _AmountChipsState();
}

class _AmountChipsState extends State<AmountChips> {
  static const _quick = [5, 10, 20];
  late bool _custom = !_quick.contains(_current);

  num? get _current => num.tryParse(widget.controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    Widget chip({required String label, required bool on, required VoidCallback? onTap, bool riyal = true}) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? onTap : null,
            child: AnimatedContainer(
              duration: Motion.base,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? c.warningSoft : c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? c.goldDeep : c.line, width: on ? 2 : 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: (riyal ? text.titleMedium : text.labelLarge)!
                          .copyWith(fontWeight: FontWeight.w800, color: on ? c.goldText : c.inkMuted)),
                  if (riyal) ...[const SizedBox(width: 3), RiyalSymbol(size: 12, color: on ? c.goldText : c.inkSubtle)],
                ],
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (i, n) in _quick.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              chip(
                label: arabicDigits(n),
                on: !_custom && _current == n,
                onTap: () {
                  setState(() => _custom = false);
                  widget.controller.text = '$n';
                  widget.onChanged();
                },
              ),
            ],
            const SizedBox(width: 8),
            chip(label: 'غيره', riyal: false, on: _custom, onTap: () => setState(() => _custom = true)),
          ],
        ),
        if (_custom) ...[
          const SizedBox(height: Space.s2),
          AmountField(
            controller: widget.controller,
            label: '',
            enabled: widget.enabled,
            onChanged: (_) => widget.onChanged(),
            validator: (v) {
              final value = double.tryParse((v ?? '').trim().replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}'));
              if (value == null) return 'اكتب المبلغ';
              if (value < 5) return 'أقل مبلغ ٥ ريال';
              return null;
            },
          ),
        ],
      ],
    );
  }
}

// «كيف تثبت؟»: a tile with an icon for every method
const proofMethodShortAr = {
  'PHOTO': 'صورة',
  'TIMER': 'مؤقت',
  'QUIZ': 'كويز',
  'LOCATION': 'موقع',
  'STEPS': 'خطوات',
};

class ProofMethodGrid extends StatelessWidget {
  final List<String> methods;
  final String value;
  final ValueChanged<String>? onChanged; // null = locked

  const ProofMethodGrid({super.key, required this.methods, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final (i, m) in methods.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Builder(builder: (context) {
              final on = m == value;
              final enabled = onChanged != null || on;
              return Semantics(
                button: true,
                selected: on,
                label: proofMethodShortAr[m] ?? m,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onChanged == null ? null : () => onChanged!(m),
                  child: AnimatedContainer(
                    duration: Motion.base,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: on ? c.primarySoft : c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? c.accent : c.line, width: on ? 2 : 1),
                    ),
                    child: Opacity(
                      opacity: enabled ? 1 : 0.45,
                      child: Column(
                        children: [
                          Icon(proofMethodIcon(m), size: 22, color: on ? c.primary : c.inkMuted),
                          const SizedBox(height: 4),
                          Text(proofMethodShortAr[m] ?? m,
                              style: text.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: on ? c.primary : c.inkMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

// the planned days (only reminders, never deductions)
class PlannedDaysPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const PlannedDaysPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    // seven pills in one row (the design): selected = soft blue
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Builder(builder: (context) {
              final day = weekDays[i];
              final on = selected.contains(day);
              return Semantics(
                selected: on,
                button: true,
                label: weekDaysAr[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final next = {...selected};
                    on ? next.remove(day) : next.add(day);
                    onChanged(next);
                  },
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.easeOut,
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? c.primarySoft : c.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: on ? c.primary : c.line, width: on ? 1.5 : 1),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(weekDaysAr[i],
                            style: text.labelSmall!.copyWith(color: on ? c.primary : c.inkSubtle, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

// the target of a LOCATION commitment (the place) or a TIMER one (the minutes)
class TargetDraft {
  double? latitude;
  double? longitude;
  int? radius; // the circle the proof counts inside (null = 150 m on the server)
  final placeName = TextEditingController();
  final minutes = TextEditingController();

  TargetDraft();

  factory TargetDraft.from(Map<String, dynamic> commitment) {
    final draft = TargetDraft();
    draft.latitude = (commitment['targetLatitude'] as num?)?.toDouble();
    draft.longitude = (commitment['targetLongitude'] as num?)?.toDouble();
    draft.radius = (commitment['targetRadiusMeters'] as num?)?.toInt();
    draft.placeName.text = '${commitment['targetPlaceName'] ?? ''}';
    final m = commitment['targetMinutes'];
    if (m != null) draft.minutes.text = '$m';
    return draft;
  }

  // null when it is fine, or the message to show
  String? check(String proofMethod) {
    if (proofMethod == 'LOCATION' && (latitude == null || longitude == null)) {
      return 'اختر المكان من الاقتراحات، أو اضغط «موقعي الحالي» وأنت فيه.';
    }
    if (proofMethod == 'TIMER') {
      final value = int.tryParse(minutes.text.trim());
      if (value == null || value < 1 || value > 600) return 'اكتب دقائق المرة الوحدة (من ١ إلى ٦٠٠).';
    }
    return null;
  }

  // the fields with the names of the habit / goal plan request
  Map<String, dynamic> toCommitmentJson(String proofMethod) => {
        if (proofMethod == 'LOCATION') ...{
          'targetLatitude': latitude,
          'targetLongitude': longitude,
          if (placeName.text.trim().isNotEmpty) 'targetPlaceName': placeName.text.trim(),
          if (radius != null) 'targetRadiusMeters': radius,
        },
        if (proofMethod == 'TIMER') 'targetMinutes': int.tryParse(minutes.text.trim()),
      };

  void dispose() {
    placeName.dispose();
    minutes.dispose();
  }
}

class TargetFields extends StatefulWidget {
  final String proofMethod;
  final TargetDraft draft;

  const TargetFields({super.key, required this.proofMethod, required this.draft});

  @override
  State<TargetFields> createState() => _TargetFieldsState();
}

class _TargetFieldsState extends State<TargetFields> {
  bool _locating = false;
  bool _searching = false;
  Timer? _wait;
  List<Map<String, dynamic>> _results = [];
  String? _searchError;
  String _lastQuery = '';

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  // Google Places: suggestions while typing the place name (the near ones first when the location is allowed)
  void _onType(String value) {
    _wait?.cancel();
    // typing a new name forgets the picked place, so the name and the point always match
    if (widget.draft.latitude != null) {
      setState(() {
        widget.draft.latitude = null;
        widget.draft.longitude = null;
      });
    }
    _wait = Timer(const Duration(milliseconds: 500), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    _lastQuery = query;
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      Position? here;
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          here = await Geolocator.getLastKnownPosition();
        }
      } catch (_) {}
      final data = await context.read<ApiClient>().get('/api/v1/place/search',
          query: {'query': query, 'lat': here?.latitude, 'lng': here?.longitude});
      if (!mounted || query != _lastQuery) return;
      setState(() => _results = [for (final p in (data as List? ?? const [])) Map<String, dynamic>.from(p as Map)]);
    } catch (_) {
      if (mounted && query == _lastQuery) setState(() => _searchError = 'ما قدرنا نجيب الاقتراحات، جرّب «موقعي الحالي».');
    } finally {
      if (mounted && query == _lastQuery) setState(() => _searching = false);
    }
  }

  void _pick(Map<String, dynamic> place) {
    FocusScope.of(context).unfocus();
    setState(() {
      widget.draft.latitude = (place['latitude'] as num?)?.toDouble();
      widget.draft.longitude = (place['longitude'] as num?)?.toDouble();
      widget.draft.placeName.text = '${place['name'] ?? ''}';
      _results = [];
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) showMessage(context, 'اسمح للتطبيق يستخدم موقعك من الإعدادات.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)));
      setState(() {
        widget.draft.latitude = position.latitude;
        widget.draft.longitude = position.longitude;
        _results = [];
      });
    } catch (_) {
      if (mounted) showMessage(context, 'ما قدرنا نحدد موقعك، حاول مرة ثانية.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final draft = widget.draft;
    if (widget.proofMethod == 'TIMER') {
      return TextField(
        controller: draft.minutes,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'كم دقيقة المرة الوحدة؟', prefixIcon: Icon(Icons.timer_outlined), suffixText: 'دقيقة'),
      );
    }
    if (widget.proofMethod != 'LOCATION') return const SizedBox.shrink();
    final hasPlace = draft.latitude != null && draft.longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: draft.placeName,
          onChanged: _onType,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: InputDecoration(
            labelText: 'وين المكان؟',
            hintText: 'اكتب اسمه: نادي، مكتبة، مسجد...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searching
                ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : hasPlace
                    ? Icon(Icons.check_circle_rounded, color: c.success)
                    : null,
          ),
        ),
        // the suggestions
        if (_results.isNotEmpty) ...[
          const SizedBox(height: Space.s2),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, p) in _results.take(5).indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.line),
                  InkWell(
                    onTap: () => _pick(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.place_rounded, size: 20, color: c.primary),
                          ),
                          const SizedBox(width: Space.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p['name'] ?? ''}', style: text.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                                if ('${p['address'] ?? ''}'.isNotEmpty)
                                  Text('${p['address']}', style: text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_searchError != null) ...[
          const SizedBox(height: Space.s2),
          Text(_searchError!, style: text.labelSmall!.copyWith(color: c.danger)),
        ] else if (!_searching && _results.isEmpty && !hasPlace && draft.placeName.text.trim().length >= 2 && _lastQuery.isNotEmpty) ...[
          const SizedBox(height: Space.s2),
          Text('ما لقينا مكان بهالاسم، جرّب اسم ثاني أو «موقعي الحالي».', style: text.labelSmall),
        ],
        const SizedBox(height: Space.s3),
        // the picked place on a map, the pin moves with a tap, and how wide the circle is
        if (hasPlace) ...[
          PlaceMap(
            latitude: draft.latitude!,
            longitude: draft.longitude!,
            radiusMeters: draft.radius ?? 150,
            onMove: (lat, lng) => setState(() {
              draft.latitude = lat;
              draft.longitude = lng;
            }),
          ),
          const SizedBox(height: Space.s2),
          Row(
            children: [
              Icon(Icons.radio_button_checked_rounded, size: 16, color: c.inkSubtle),
              const SizedBox(width: 4),
              Text('الدائرة', style: text.labelSmall),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final m in const [100, 150, 300, 500]) ...[
                      ChoiceChip(
                        label: Text('${arabicDigits(m)} م'),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        selected: (draft.radius ?? 150) == m,
                        onSelected: (_) => setState(() => draft.radius = m),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s2),
        ],
        if (hasPlace)
          Container(
            padding: const EdgeInsets.all(Space.s3),
            decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(
              children: [
                Icon(Icons.where_to_vote_rounded, color: c.success),
                const SizedBox(width: Space.s2),
                Expanded(
                  child: Text(
                    draft.placeName.text.trim().isEmpty ? 'تحدّد المكان على موقعك' : draft.placeName.text.trim(),
                    style: text.labelLarge!.copyWith(color: c.success),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        else
          AtButton(
            'موقعي الحالي',
            kind: AtButtonKind.outline,
            loading: _locating,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            onPressed: _useMyLocation,
          ),
      ],
    );
  }
}

// yes / no before something that cannot be undone
Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, required String confirm, bool danger = false}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm, style: TextStyle(color: danger ? context.colors.danger : null)),
        ),
      ],
    ),
  );
  return answer ?? false;
}

const withdrawWarning = 'لو انسحبت الحين، كل مرة باقية هالأسبوع تصير خصم ويتقفل التطبيق لين تتبرع. '
    'التعهد ينتهي، ولو تبي ترجع تنشئ تعهد جديد.';

// «المشي ٣٠ دقيقة»، «تمشية»، «١٠ آلاف خطوة»، «walk» -> a walking habit (it can use the steps of the day)
bool isWalkingTitle(String title) =>
    RegExp(r'مش[يى]|ممشى|خطو|walk|step', caseSensitive: false).hasMatch(title);

// the proof method that fits a habit title (the member can still change it):
// walking -> the steps of the day, reading -> a quiz, a place -> the location, studying -> a timer, else a photo
String suggestedProofMethod(String title) {
  bool has(String pattern) => RegExp(pattern, caseSensitive: false).hasMatch(title);
  if (isWalkingTitle(title)) return 'STEPS';
  if (has(r'قراء|أقرأ|اقرأ|اقرا|كتاب|صفح|رواية|read|book')) return 'QUIZ';
  if (has(r'نادي|جيم|صالة|سباح|مكتبة|مسجد|gym|club')) return 'LOCATION';
  if (has(r'مذاكر|ذاكر|دراس|تعلّ?م|كورس|حفظ|تأمل|study|learn')) return 'TIMER';
  return 'PHOTO';
}

// the first hour after creating a habit or a goal: it changes this week too, or can be deleted
// null = not started yet (free to change), 0 = the hour is over, else the minutes left
int? editMinutesLeft(Map<String, dynamic> commitment) {
  final until = DateTime.tryParse('${commitment['editableUntil'] ?? ''}');
  if (until == null) return commitment['editableUntil'] == null ? null : 0;
  final left = until.difference(DateTime.now());
  return left.isNegative ? 0 : left.inMinutes + 1;
}

// the backend answers the edit and delete rules in English, the known ones in Arabic
void showCommitmentError(BuildContext context, Object error) {
  const known = {
    'A habit can only be deleted in the first hour, withdraw from it instead': 'الحذف متاح أول ساعة بس، تقدر تنسحب من العادة.',
    'A goal can only be deleted in the first hour, withdraw from it instead': 'الحذف متاح أول ساعة بس، تقدر تنسحب من الهدف.',
    'Habit already has progress, withdraw from it instead': 'رفعت إثبات فيها، تقدر تنسحب بدل الحذف.',
    'Goal already has progress, withdraw from it instead': 'رفعت إثبات فيه، تقدر تنسحب بدل الحذف.',
    'Proof method cannot change after the habit starts': 'طريقة الإثبات ما تتغير بعد أول ساعة أو بعد أول إثبات.',
  };
  final message = error is ApiException ? known[error.message] : null;
  message != null ? showMessage(context, message) : showError(context, error);
}


// «متى تبدأ؟»: today, tomorrow, next Sunday or any day in the coming year (never a past day)
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class StartDatePicker extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const StartDatePicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final sunday = today.add(Duration(days: 7 - today.weekday % 7));
    final quick = <(String, DateTime)>[
      ('اليوم', today),
      ('بكرة', tomorrow),
      if (sunday != tomorrow) ('الأحد الجاي', sunday),
    ];
    final custom = !quick.any((q) => q.$2 == value);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, day) in quick)
          ChoiceChip(
            label: Text(label),
            showCheckmark: false,
            selected: value == day,
            onSelected: (_) => onChanged(day),
          ),
        ChoiceChip(
          avatar: Icon(Icons.calendar_month_outlined, size: 18, color: custom ? context.colors.primary : null),
          label: Text(custom ? arabicDigits(isoDate(value)) : 'يوم ثاني'),
          showCheckmark: false,
          selected: custom,
          onSelected: (_) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value.isBefore(today) ? today : value,
              firstDate: today, // today is allowed, a past day is not
              lastDate: today.add(const Duration(days: 365)),
            );
            if (picked != null) onChanged(dateOnly(picked));
          },
        ),
      ],
    );
  }
}

// «تبدأ الأحد ٢٠٢٦-١١-٠١» for a commitment that did not start yet, else null
String? startsLater(Map<String, dynamic> commitment) {
  final start = DateTime.tryParse('${commitment['startDate'] ?? ''}');
  if (start == null || !dateOnly(start).isAfter(dateOnly(DateTime.now()))) return null;
  return 'يبدأ ${weekDaysAr[start.weekday % 7]} ${arabicDigits(isoDate(start))}';
}
