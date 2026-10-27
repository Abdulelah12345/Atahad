import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitment_widgets.dart';
import 'commitments_api.dart';
import '../walking/walking_setup.dart';
import '../walking/walking_api.dart';

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
  final _amount = TextEditingController(text: '5'); // the least Ehsan takes
  late final TargetDraft _target;
  late final WalkingDraft _walking;
  String _proofMethod = 'PHOTO';
  int _times = 3;
  Set<String> _days = {};
  bool _busy = false;

  bool _methodPicked = false; // the member chose the method by hand, the title stops changing it
  late bool _askingTitle = widget.habit == null; // a new habit starts with «وش العادة؟» alone

  bool get _editing => widget.habit != null;

  // «وش العادة؟» answered: fill the form from the title (all of it stays editable)
  void _fillFromTitle() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showMessage(context, 'اكتب اسم العادة');
      return;
    }
    final method = suggestedProofMethod(title);
    setState(() {
      _proofMethod = method;
      _methodPicked = false;
      _times = method == 'STEPS' ? 7 : 3;
      if (method == 'TIMER' && _target.minutes.text.isEmpty) _target.minutes.text = '30';
      _askingTitle = false;
    });
  }

  // a walking habit gets «مجموع خطوات اليوم» by itself (still editable); the steps go away when the title is not about walking
  void _suggestMethod(String title) {
    final walking = isWalkingTitle(title);
    if (walking && !_methodPicked && _proofMethod != 'STEPS') {
      setState(() {
        _proofMethod = 'STEPS';
        _times = 7;
      });
    } else if (!walking && _proofMethod == 'STEPS') {
      setState(() {
        _proofMethod = 'PHOTO';
        _methodPicked = false;
      });
    } else {
      setState(() {}); // the list of methods follows the title
    }
  }

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _target = h == null ? TargetDraft() : TargetDraft.from(h);
    _walking = h == null ? WalkingDraft() : WalkingDraft.from(h);
    if (h != null) {
      _title.text = '${h['title'] ?? ''}';
      _proofMethod = '${h['proofMethod'] ?? 'PHOTO'}';
      // show the coming value if an edit is waiting for next week
      _times = (h['pendingTimesPerWeek'] ?? h['timesPerWeek'] ?? 3) as int;
      final amount = (h['pendingBaseAmount'] ?? h['baseAmount']) as num?;
      if (amount != null)
        _amount.text = amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2);
      _days = {...((h['plannedDays'] as List?) ?? const []).map((d) => '$d')};
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _target.dispose();
    _walking.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_proofMethod == 'STEPS') {
      final error = _walking.validate(editing: _editing);
      if (error != null) {
        showMessage(context, error);
        return;
      }
    }
    final targetError = _target.check(_proofMethod);
    if (targetError != null) {
      showMessage(context, targetError);
      return;
    }
    final body = {
      'title': _title.text.trim(),
      'proofMethod': _proofMethod,
      'timesPerWeek': _times,
      'baseAmount': double.parse(normalizeWalkingNumber(_amount.text)),
      'plannedDays': _days.toList(),
      ..._target.toCommitmentJson(_proofMethod),
      if (_proofMethod == 'STEPS') ..._walking.toJson(),
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
        final placeChanged =
            _proofMethod == 'LOCATION' &&
            (t['targetLatitude'] != h['targetLatitude'] ||
                t['targetLongitude'] != h['targetLongitude'] ||
                (t['targetPlaceName'] ?? '') != (h['targetPlaceName'] ?? ''));
        final minutesChanged =
            _proofMethod == 'TIMER' && t['targetMinutes'] != h['targetMinutes'];
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
      showMessage(
        context,
        !_editing
            ? 'بدأت العادة، الأسبوع يبدأ من اليوم. تقدر تعدّلها أو تحذفها خلال ساعة.'
            : _firstHour
                ? 'تم الحفظ، والتغيير يبدأ من هالأسبوع.'
                : 'تم الحفظ. تغيير المرات والمبلغ يبدأ من الأسبوع الجاي.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showCommitmentError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // the first hour after creating the habit: everything changes this week too (the backend checks it again)
  int get _minutesLeft => _editing ? (editMinutesLeft(widget.habit!) ?? 60) : 0;
  bool get _firstHour => _editing && _minutesLeft > 0;
  bool get _methodLocked => _editing && (!_firstHour || widget.habit!['proofMethod'] == 'STEPS');

  // the first page of a new habit: one question, a few quick answers, then the filled form
  Widget _titleStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const examples = ['المشي اليومي', 'قراءة ٢٠ صفحة', 'النادي', 'المذاكرة ساعة'];
    return Scaffold(
      appBar: AppBar(title: const Text('عادة جديدة')),
      body: ListView(
        padding: const EdgeInsets.all(Space.s4),
        children: [
          const SizedBox(height: Space.s6),
          Text('وش العادة؟', style: text.headlineLarge),
          const SizedBox(height: Space.s2),
          Text('اكتبها بكلماتك، ونجهّز لك الباقي وتقدر تعدّله.', style: text.bodyMedium),
          const SizedBox(height: Space.s6),
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 100,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _fillFromTitle(),
            decoration: const InputDecoration(hintText: 'مثلًا: المشي ٣٠ دقيقة'),
          ),
          const SizedBox(height: Space.s2),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              for (final e in examples)
                ActionChip(
                  label: Text(e),
                  onPressed: () {
                    _title.text = e;
                    _fillFromTitle();
                  },
                ),
            ],
          ),
          const SizedBox(height: Space.s8),
          AtButton('التالي', onPressed: _fillFromTitle),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_askingTitle) return _titleStep(context);
    final text = Theme.of(context).textTheme;
    final amount = double.tryParse(normalizeWalkingNumber(_amount.text)) ?? 0;
    // back on the form of a new habit returns to «وش العادة؟», not out of it
    return PopScope(
      canPop: _editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _askingTitle = true);
      },
      child: _formStep(context, text, amount),
    );
  }

  Widget _formStep(BuildContext context, TextTheme text, double amount) {
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
              decoration: const InputDecoration(
                labelText: 'وش العادة؟',
                hintText: 'النادي',
              ),
              onChanged: _editing ? null : _suggestMethod,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اكتب اسم العادة' : null,
            ),
            const SizedBox(height: Space.s3),
            DropdownButtonFormField<String>(
              key: ValueKey(_proofMethod),
              initialValue: _proofMethod,
              decoration: InputDecoration(
                labelText: 'طريقة الإثبات',
                helperText: !_editing
                    ? null
                    : _methodLocked
                        ? 'ما تتغير بعد أول ساعة من إنشاء العادة'
                        : 'تقدر تغيّرها أول ساعة (باقي ${arabicDigits(_minutesLeft)} دقيقة)',
              ),
              // the steps only for a walking habit (a reading habit never sees it), and they cannot be added or removed after it starts
              items: {
                ...proofMethodsAr,
                if (_proofMethod == 'STEPS' || (!_editing && isWalkingTitle(_title.text))) 'STEPS': 'مجموع خطوات اليوم',
              }.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: _methodLocked
                  ? null
                  : (v) => setState(() {
                      _methodPicked = true;
                      _proofMethod = v ?? _proofMethod;
                      if (v == 'STEPS') {
                        _times = 7;
                        if (_title.text.isEmpty) _title.text = 'المشي اليومي';
                      }
                    }),
            ),
            const SizedBox(height: Space.s3),
            TargetFields(proofMethod: _proofMethod, draft: _target),
            if (_proofMethod == 'STEPS')
              WalkingSetup(
                draft: _walking,
                editing: _editing,
                onChanged: () => setState(() {}),
                onUseTimer: () => setState(() {
                  _proofMethod = 'TIMER';
                  _target.minutes.text = '30';
                }),
              ),
            const SizedBox(height: Space.s4),
            Row(
              children: [
                Expanded(
                  child: Text('كم مرة بالأسبوع؟', style: text.titleSmall),
                ),
                TimesStepper(
                  value: _times,
                  onChanged: (v) => setState(() => _times = v),
                ),
              ],
            ),
            const SizedBox(height: Space.s4),
            AmountField(
              controller: _amount,
              label: 'المبلغ لكل مرة تفوتك',
              hint: 'لو فاتتك كلها: ${money(amount * _times)} ريال صدقة بالأسبوع. أقل مبلغ ٥ ريال.',
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final value = double.tryParse(normalizeWalkingNumber(v ?? ''));
                if (value == null) return 'اكتب المبلغ';
                if (value < 5) return 'أقل مبلغ ٥ ريال';
                return null;
              },
            ),
            const SizedBox(height: Space.s4),
            Text('أيام التخطيط (للتذكير بس، اختياري)', style: text.titleSmall),
            const SizedBox(height: Space.s2),
            PlannedDaysPicker(
              selected: _days,
              onChanged: (v) => setState(() => _days = v),
            ),
            const SizedBox(height: Space.s5),
            AppCard(
              child: InfoRow(
                'أقصى خسارة بالأسبوع = ${arabicDigits(_times)} × ${money(amount)}',
                RiyalAmount(_times * amount),
              ),
            ),
            const SizedBox(height: Space.s5),
            AtButton(
              _editing ? 'احفظ' : 'التزم',
              kind: AtButtonKind.gold,
              loading: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
