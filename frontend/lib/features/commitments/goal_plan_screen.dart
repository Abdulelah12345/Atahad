import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitment_widgets.dart';
import 'commitments_api.dart';

// OWNER: Turki - a new goal with the AI plan
// step 1: the member writes the goal and its end date, the AI suggests a task for every week (nothing is saved)
// step 2: he changes what he wants, then the plan is saved and the goal starts right away
class GoalPlanScreen extends StatefulWidget {
  const GoalPlanScreen({super.key});

  @override
  State<GoalPlanScreen> createState() => _GoalPlanScreenState();
}

class _WeekDraft {
  final TextEditingController title;
  int times;

  _WeekDraft(String title, this.times) : title = TextEditingController(text: title);
}

class _GoalPlanScreenState extends State<GoalPlanScreen> {
  late final _api = CommitmentsApi(context.read<ApiClient>());
  final _goal = TextEditingController();
  DateTime? _endDate;

  // step 2
  JsonMap? _plan;
  final _title = TextEditingController();
  final _amount = TextEditingController(text: '10');
  final _target = TargetDraft();
  String _proofMethod = 'PHOTO';
  List<_WeekDraft> _weeks = [];

  bool _busy = false;

  @override
  void dispose() {
    _goal.dispose();
    _title.dispose();
    _amount.dispose();
    _target.dispose();
    for (final w in _weeks) {
      w.title.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now.add(const Duration(days: 28)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 364)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _suggest() async {
    if (_goal.text.trim().isEmpty || _endDate == null) {
      showMessage(context, 'اكتب هدفك واختر تاريخ نهايته.');
      return;
    }
    setState(() => _busy = true);
    try {
      final plan = await _api.suggestPlan(_goal.text.trim(), _endDate!);
      if (!mounted) return;
      for (final w in _weeks) {
        w.title.dispose();
      }
      setState(() {
        _plan = plan;
        _title.text = '${plan['title'] ?? _goal.text.trim()}';
        final method = '${plan['proofMethod'] ?? ''}';
        _proofMethod = proofMethodsAr.containsKey(method) ? method : 'PHOTO';
        _weeks = ((plan['weeks'] as List?) ?? const [])
            .map((w) => _WeekDraft('${(w as Map)['title'] ?? ''}', ((w['timesPerWeek'] ?? 1) as int).clamp(1, 7)))
            .toList();
        if (_weeks.isEmpty) _weeks = [_WeekDraft(_title.text, 3)];
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (_title.text.trim().isEmpty) return showMessage(context, 'اكتب عنوان الهدف.');
    if (amount == null || amount < 5) return showMessage(context, 'أقل مبلغ لكل مرة ٥ ريال.');
    if (_weeks.any((w) => w.title.text.trim().isEmpty)) return showMessage(context, 'كل أسبوع يحتاج مهمة.');
    final targetError = _target.check(_proofMethod);
    if (targetError != null) return showMessage(context, targetError);

    setState(() => _busy = true);
    try {
      await _api.addWithPlan({
        'title': _title.text.trim(),
        'description': _goal.text.trim(),
        'proofMethod': _proofMethod,
        'amountPerTime': amount,
        'weeks': _weeks.map((w) => {'title': w.title.text.trim(), 'timesPerWeek': w.times}).toList(),
        ..._target.toCommitmentJson(_proofMethod),
      });
      if (!mounted) return;
      showMessage(context, 'بدأ الهدف، الأسبوع الأول يخلص هالسبت.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('هدف جديد')),
      body: _plan == null ? _askStep(context) : _planStep(context),
    );
  }

  Widget _askStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Space.s4),
      children: [
        Text('اكتب هدفك بكلامك، والذكاء يقترح لك خطة أسبوع بأسبوع تزيد تدريجياً.', style: text.bodyMedium),
        const SizedBox(height: Space.s4),
        TextField(
          controller: _goal,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'هدفك', hintText: 'أبي أخلص كتاب في البرمجة'),
        ),
        const SizedBox(height: Space.s3),
        AppCard(
          onTap: _pickDate,
          child: InfoRow(
            'متى ينتهي؟',
            Text(_endDate == null ? 'اختر التاريخ' : arabicDigits(isoDate(_endDate!)), style: text.titleSmall),
          ),
        ),
        const SizedBox(height: Space.s5),
        AtButton('اقترح لي خطة', loading: _busy, icon: const Icon(Icons.auto_awesome_rounded, size: 18), onPressed: _suggest),
      ],
    );
  }

  Widget _planStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final amount = parseAmount(_amount.text) ?? 0;
    final note = _plan?['note'];
    return ListView(
      padding: const EdgeInsets.all(Space.s4),
      children: [
        if (note != null && '$note'.isNotEmpty)
          AppCard(
            color: c.primarySoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: c.primary, size: 20),
                const SizedBox(width: Space.s2),
                Expanded(child: Text('$note', style: text.bodySmall!.copyWith(color: c.ink))),
              ],
            ),
          ),
        const SizedBox(height: Space.s4),
        TextField(controller: _title, maxLength: 100, decoration: const InputDecoration(labelText: 'عنوان الهدف')),
        const SizedBox(height: Space.s3),
        DropdownButtonFormField<String>(
          initialValue: _proofMethod,
          decoration: const InputDecoration(labelText: 'طريقة الإثبات'),
          items: proofMethodsAr.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => _proofMethod = v ?? _proofMethod),
        ),
        const SizedBox(height: Space.s3),
        TargetFields(proofMethod: _proofMethod, draft: _target),
        const SizedBox(height: Space.s3),
        AmountField(
          controller: _amount,
          label: 'المبلغ لكل مرة تفوتك',
          hint: 'أقل مبلغ ٥ ريال. تشوف أقصى خصم لكل أسبوع تحت.',
          onChanged: (_) => setState(() {}),
        ),
        SectionTitle('الخطة (${arabicDigits(_weeks.length)} أسابيع)'),
        ...List.generate(_weeks.length, (i) {
          final w = _weeks[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('الأسبوع ${arabicDigits(i + 1)}', style: text.titleSmall)),
                      TimesStepper(value: w.times, onChanged: (v) => setState(() => w.times = v)),
                    ],
                  ),
                  const SizedBox(height: Space.s2),
                  TextField(controller: w.title, decoration: const InputDecoration(labelText: 'مهمة الأسبوع')),
                  const SizedBox(height: Space.s1),
                  Text(
                    'أقصى خسارة هالأسبوع: ${arabicDigits(w.times)} × ${money(amount)}',
                    style: text.labelSmall,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: Space.s2),
        AtButton('التزم وابدأ', kind: AtButtonKind.gold, loading: _busy, onPressed: _save),
        const SizedBox(height: Space.s2),
        AtButton('اكتب الهدف من جديد', kind: AtButtonKind.text, onPressed: _busy ? null : () => setState(() => _plan = null)),
      ],
    );
  }
}
