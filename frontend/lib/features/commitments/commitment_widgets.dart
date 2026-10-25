import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

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
  'GRACE_DAY_REDEEMED': 'بدّلتها بيوم سماح',
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

// the planned days (only reminders, never deductions)
class PlannedDaysPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const PlannedDaysPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.s2,
      runSpacing: Space.s2,
      children: List.generate(7, (i) {
        final day = weekDays[i];
        final on = selected.contains(day);
        return FilterChip(
          label: Text(weekDaysAr[i]),
          selected: on,
          onSelected: (value) {
            final next = {...selected};
            value ? next.add(day) : next.remove(day);
            onChanged(next);
          },
        );
      }),
    );
  }
}

// the target of a LOCATION commitment (the place) or a TIMER one (the minutes)
class TargetDraft {
  double? latitude;
  double? longitude;
  final placeName = TextEditingController();
  final minutes = TextEditingController();

  TargetDraft();

  factory TargetDraft.from(Map<String, dynamic> commitment) {
    final draft = TargetDraft();
    draft.latitude = (commitment['targetLatitude'] as num?)?.toDouble();
    draft.longitude = (commitment['targetLongitude'] as num?)?.toDouble();
    draft.placeName.text = '${commitment['targetPlaceName'] ?? ''}';
    final m = commitment['targetMinutes'];
    if (m != null) draft.minutes.text = '$m';
    return draft;
  }

  // null when it is fine, or the message to show
  String? check(String proofMethod) {
    if (proofMethod == 'LOCATION' && (latitude == null || longitude == null)) {
      return 'حدّد المكان أول: افتح التطبيق وأنت في المكان واضغط "استخدم موقعي الحالي".';
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
    final draft = widget.draft;
    if (widget.proofMethod == 'TIMER') {
      return TextField(
        controller: draft.minutes,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'كم دقيقة المرة الوحدة؟'),
      );
    }
    if (widget.proofMethod != 'LOCATION') return const SizedBox.shrink();
    final hasPlace = draft.latitude != null && draft.longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: draft.placeName,
          decoration: const InputDecoration(labelText: 'اسم المكان (اختياري)', hintText: 'نادي الحي'),
        ),
        const SizedBox(height: Space.s3),
        Text(
          hasPlace ? 'تم تحديد المكان ✓' : 'ما حددت المكان للحين. لازم تكون في المكان وقت التحديد.',
          style: text.bodySmall!.copyWith(color: hasPlace ? context.colors.success : null),
        ),
        const SizedBox(height: Space.s2),
        AtButton(
          hasPlace ? 'غيّر لموقعي الحالي' : 'استخدم موقعي الحالي',
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

const withdrawWarning = 'لو انسحبت الحين، كل مرة باقية هالأسبوع تصير عقوبة ويتقفل التطبيق لين تتبرع. '
    'التعهد ينتهي، ولو تبي ترجع تنشئ تعهد جديد.';
