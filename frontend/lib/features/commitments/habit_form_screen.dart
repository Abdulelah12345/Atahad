import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitment_widgets.dart';
import 'commitments_api.dart';

// OWNER: Turki - add a habit, or edit one (habit != null)
// after the habit starts: the times and the amount apply from next week, the proof method is locked
class HabitFormScreen extends StatefulWidget {
  final Map<String, dynamic>? habit;

  const HabitFormScreen({super.key, this.habit});

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  late final _api = CommitmentsApi(context.read<ApiClient>());
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController(text: '10');
  late final TargetDraft _target;
  String _proofMethod = 'PHOTO';
  int _times = 3;
  Set<String> _days = {};
  bool _busy = false;

  bool get _editing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _target = h == null ? TargetDraft() : TargetDraft.from(h);
    if (h != null) {
      _title.text = '${h['title'] ?? ''}';
      _proofMethod = '${h['proofMethod'] ?? 'PHOTO'}';
      // show the coming value if an edit is waiting for next week
      _times = (h['pendingTimesPerWeek'] ?? h['timesPerWeek'] ?? 3) as int;
      final amount = (h['pendingBaseAmount'] ?? h['baseAmount']) as num?;
      if (amount != null) _amount.text = amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2);
      _days = {...((h['plannedDays'] as List?) ?? const []).map((d) => '$d')};
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final targetError = _target.check(_proofMethod);
    if (targetError != null) {
      showMessage(context, targetError);
      return;
    }
    final body = {
      'title': _title.text.trim(),
      'proofMethod': _proofMethod,
      'timesPerWeek': _times,
      'baseAmount': double.parse(_amount.text.trim()),
      'plannedDays': _days.toList(),
      ..._target.toCommitmentJson(_proofMethod),
    };
    setState(() => _busy = true);
    try {
      if (_editing) {
        final id = widget.habit!['id'] as int;
        await _api.updateHabit(id, body);
        // the update does not touch the place or the minutes, they have their own endpoint.
        // only send it when it changed: the place is locked after the first accepted proof
        final t = _target.toCommitmentJson(_proofMethod);
        final h = widget.habit!;
        final placeChanged = _proofMethod == 'LOCATION' &&
            (t['targetLatitude'] != h['targetLatitude'] ||
                t['targetLongitude'] != h['targetLongitude'] ||
                (t['targetPlaceName'] ?? '') != (h['targetPlaceName'] ?? ''));
        final minutesChanged = _proofMethod == 'TIMER' && t['targetMinutes'] != h['targetMinutes'];
        if (placeChanged) {
          await _api.setTarget(id, {
            'latitude': t['targetLatitude'],
            'longitude': t['targetLongitude'],
            'placeName': t['targetPlaceName'],
          });
        } else if (minutesChanged) {
          await _api.setTarget(id, {'minutes': t['targetMinutes']});
        }
      } else {
        await _api.addHabit(body);
      }
      if (!mounted) return;
      showMessage(context, _editing ? 'تم الحفظ. تغيير المرات والمبلغ يبدأ من الأسبوع الجاي.' : 'بدأت العادة، الأسبوع يبدأ من اليوم.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'تعديل العادة' : 'عادة جديدة')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Space.s4),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'وش العادة؟', hintText: 'النادي'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب اسم العادة' : null,
            ),
            const SizedBox(height: Space.s3),
            DropdownButtonFormField<String>(
              initialValue: _proofMethod,
              decoration: InputDecoration(
                labelText: 'طريقة الإثبات',
                helperText: _editing ? 'ما تتغير بعد ما تبدأ العادة' : null,
              ),
              items: proofMethodsAr.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _proofMethod = v ?? _proofMethod),
            ),
            const SizedBox(height: Space.s3),
            TargetFields(proofMethod: _proofMethod, draft: _target),
            const SizedBox(height: Space.s4),
            Row(
              children: [
                Expanded(child: Text('كم مرة بالأسبوع؟', style: text.titleSmall)),
                TimesStepper(value: _times, onChanged: (v) => setState(() => _times = v)),
              ],
            ),
            const SizedBox(height: Space.s4),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ لكل مرة تفوتك (٥ ريال أقل شي)'),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final value = double.tryParse((v ?? '').trim());
                if (value == null) return 'اكتب المبلغ';
                if (value < 5) return 'أقل مبلغ ٥ ريال';
                return null;
              },
            ),
            const SizedBox(height: Space.s4),
            Text('أيام التخطيط (للتذكير بس، اختياري)', style: text.titleSmall),
            const SizedBox(height: Space.s2),
            PlannedDaysPicker(selected: _days, onChanged: (v) => setState(() => _days = v)),
            const SizedBox(height: Space.s5),
            AppCard(
              child: InfoRow(
                'أقصى خسارة بالأسبوع = ${arabicDigits(_times)} × ${money(amount)}',
                RiyalAmount(_times * amount),
              ),
            ),
            const SizedBox(height: Space.s5),
            AtButton(_editing ? 'احفظ' : 'التزم', kind: AtButtonKind.gold, loading: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
