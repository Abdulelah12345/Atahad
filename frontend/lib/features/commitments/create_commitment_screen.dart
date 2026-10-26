import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/widgets.dart';
import '../proofs/proof_widgets.dart';
import '../proofs/proofs_api.dart';
import '../walking/walking_setup.dart';
import '../walking/walking_api.dart';

/// Entry point for creating an activity without entering database identifiers.
class CreateCommitmentScreen extends StatefulWidget {
  const CreateCommitmentScreen({super.key});
  @override
  State<CreateCommitmentScreen> createState() => _CreateCommitmentScreenState();
}

class _CreateCommitmentScreenState extends State<CreateCommitmentScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController(text: '5');
  final _minutes = TextEditingController(text: '25');
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _walking = WalkingDraft();
  bool _habit = false;
  bool _busy = false;
  String _method = 'PHOTO';
  int _times = 3;
  DateTime _end = DateTime.now().add(const Duration(days: 14));
  Json? _plan;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _amount, _minutes, _latitude, _longitude]) {
      c.dispose();
    }
    super.dispose();
    _walking.dispose();
  }

  Future<void> _suggest() async {
    if (_busy) return;
    if (_title.text.trim().isEmpty) {
      showMessage(context, 'اكتب هدفك أولًا.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final plan = Map<String, dynamic>.from(
        await context.read<ApiClient>().post(
              '/api/v1/goal/suggest',
              body: {'goal': _title.text.trim(), 'endDate': dateInput(_end)},
            )
            as Map,
      );
      if (mounted) {
        setState(() {
          _plan = plan;
          _method = plan['proofMethod'] as String;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final amount = double.tryParse(normalizeWalkingNumber(_amount.text));
    final minutes = int.tryParse(_minutes.text);
    final lat = double.tryParse(_latitude.text);
    final lon = double.tryParse(_longitude.text);
    if (_title.text.trim().isEmpty ||
        _title.text.trim().length > 100 ||
        amount == null ||
        !amount.isFinite ||
        amount < 5) {
      showMessage(
        context,
        'اكتب عنوانًا حتى ١٠٠ حرف ومبلغًا لا يقل عن ٥ ريالات.',
      );
      return;
    }
    if (_method == 'TIMER' &&
        (minutes == null || minutes < 1 || minutes > 600)) {
      showMessage(context, 'اختر مدة من دقيقة إلى ٦٠٠ دقيقة.');
      return;
    }
    if (_method == 'LOCATION' &&
        (lat == null ||
            lon == null ||
            !lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180)) {
      showMessage(context, 'حدّد إحداثيات المكان بشكل صحيح.');
      return;
    }
    if (!_habit && _plan == null) return;
    if (_method == 'STEPS') {
      final error = _walking.validate();
      if (!_habit || error != null) {
        showMessage(context, error ?? 'خطوات اليوم متاحة للعادة الفردية.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        'proofMethod': _method,
        if (_method == 'STEPS') ..._walking.toJson(),
        if (_method == 'TIMER') 'targetMinutes': minutes,
        if (_method == 'LOCATION') ...{
          'targetLatitude': lat,
          'targetLongitude': lon,
          'targetRadiusMeters': 150,
        },
        if (_habit) ...{
          'baseAmount': amount,
          'timesPerWeek': _times,
        } else ...{
          'amountPerTime': amount,
          'weeks': _plan!['weeks'],
        },
      };
      await context.read<ApiClient>().post(
        _habit ? '/api/v1/habit/add' : '/api/v1/goal/addWithPlan',
        body: body,
      );
      if (!mounted) return;
      showMessage(context, 'تمت إضافة النشاط بنجاح');
      context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProofPage(
    title: 'إضافة نشاط',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('هدف بخطة')),
            ButtonSegment(value: true, label: Text('عادة')),
          ],
          selected: {_habit},
          onSelectionChanged: _busy
              ? null
              : (v) => setState(() {
                  _habit = v.first;
                  if (!_habit && _method == 'STEPS') _method = 'PHOTO';
                  _plan = null;
                  _error = null;
                }),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _title,
          maxLength: 100,
          enabled: !_busy,
          onChanged: (_) {
            if (_plan != null) {
              setState(() => _plan = null);
            }
          },
          decoration: InputDecoration(
            labelText: _habit ? 'اسم العادة' : 'ما هدفك؟',
          ),
        ),
        if (!_habit) ...[
          ListTile(
            title: const Text('تاريخ الوصول للهدف'),
            subtitle: Text(dateInput(_end)),
            trailing: const Icon(Icons.calendar_month),
            onTap: _busy
                ? null
                : () async {
                    final today = DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _end,
                      firstDate: today.add(const Duration(days: 1)),
                      lastDate: today.add(const Duration(days: 350)),
                    );
                    if (date != null && mounted) {
                      setState(() {
                        _end = date;
                        _plan = null;
                      });
                    }
                  },
          ),
          AtButton(
            'اقترح خطة وطريقة إثبات',
            loading: _busy,
            onPressed: _suggest,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          ProofNotice(_error!),
        ],
        if (_plan != null) ...[
          const SizedBox(height: 20),
          ProofNotice('${_plan!['note'] ?? 'راجع الخطة قبل اعتمادها.'}'),
          const SizedBox(height: 12),
          for (final (i, week) in ProofsApi.maps(_plan!['weeks']).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  children: [
                    Text('الأسبوع ${i + 1}'),
                    TextFormField(
                      initialValue: '${week['title']}',
                      maxLength: 100,
                      enabled: !_busy,
                      decoration: const InputDecoration(labelText: 'المهمة'),
                      onChanged: (v) =>
                          (_plan!['weeks'] as List)[i]['title'] = v.trim(),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: week['timesPerWeek'] as int,
                      decoration: const InputDecoration(
                        labelText: 'مرات الإنجاز',
                      ),
                      items: [
                        for (var n = 1; n <= 7; n++)
                          DropdownMenuItem(value: n, child: Text('$n')),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) =>
                                (_plan!['weeks'] as List)[i]['timesPerWeek'] =
                                    v,
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (_habit || _plan != null) ...[
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: ValueKey(_method),
            initialValue: _method,
            decoration: InputDecoration(
              labelText: _habit ? 'طريقة الإثبات' : 'طريقة الإثبات المقترحة',
            ),
            items: [
              for (final method in methodNames.entries.where(
                (e) => _habit || e.key != 'STEPS',
              ))
                DropdownMenuItem(value: method.key, child: Text(method.value)),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _method = v!;
                    if (v == 'STEPS') {
                      _times = 7;
                      if (_title.text.isEmpty) _title.text = 'المشي اليومي';
                    }
                  }),
          ),
          if (_method == 'STEPS')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: WalkingSetup(
                draft: _walking,
                onChanged: () => setState(() {}),
                onUseTimer: () => setState(() {
                  _method = 'TIMER';
                  _minutes.text = '30';
                }),
              ),
            ),
          if (_habit)
            DropdownButtonFormField<int>(
              initialValue: _times,
              decoration: const InputDecoration(
                labelText: 'مرات الإنجاز أسبوعيًا',
              ),
              items: [
                for (var n = 1; n <= 7; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: _busy ? null : (v) => setState(() => _times = v!),
            ),
          if (_method == 'TIMER')
            TextField(
              controller: _minutes,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'مدة الجلسة بالدقائق',
              ),
            ),
          if (_method == 'LOCATION') ...[
            TextField(
              controller: _latitude,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'خط العرض'),
            ),
            TextField(
              controller: _longitude,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'خط الطول'),
            ),
          ],
          TextField(
            controller: _amount,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'مبلغ الالتزام لكل مرة غير منجزة',
              helperText: '٥ ريالات على الأقل. لا يتم دفع المبلغ عند الإضافة.',
            ),
          ),
          const SizedBox(height: 24),
          AtButton(
            _habit ? 'إضافة العادة' : 'اعتماد الخطة وإضافة الهدف',
            loading: _busy,
            onPressed: _save,
          ),
        ],
      ],
    ),
  );
}
