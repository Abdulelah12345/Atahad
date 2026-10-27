import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'camera_capture_screen.dart';
import 'proof_widgets.dart';
import 'proofs_api.dart';

String imageMime(Uint8List bytes) =>
    bytes.length > 4 && bytes[0] == 137 && bytes[1] == 80
        ? 'image/png'
        : 'image/jpeg';

class AttachmentPicker extends StatelessWidget {
  final String label;
  final CapturedImage? image;
  final ValueChanged<CapturedImage?> onChanged;
  const AttachmentPicker(
      {super.key,
      required this.label,
      required this.image,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.attach_file, color: context.colors.primary),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.titleMedium)),
          if (image != null)
            IconButton(
                tooltip: 'إزالة الصورة',
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close))
        ]),
        const SizedBox(height: 12),
        if (image != null)
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Image.memory(image!.bytes, fit: BoxFit.contain))),
        if (image == null)
          Text('صورة واضحة بصيغة صورة، حتى ٢ ميغابايت.',
              style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        AtButton(image == null ? 'اختر صورة' : 'غيّر الصورة',
            kind: AtButtonKind.outline, onPressed: () async {
          try {
            final file = await ImagePicker().pickImage(
                source: ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
            if (file == null) return;
            final bytes = await file.readAsBytes();
            if (bytes.length > 2 * 1024 * 1024) {
              if (context.mounted) {
                showMessage(context, 'اختر صورة أصغر من ٢ ميغابايت.');
              }
              return;
            }
            onChanged(CapturedImage(bytes, imageMime(bytes)));
          } catch (error) {
            if (context.mounted) {
              showMessage(context, 'تعذر فتح الصورة. جرّب صورة ثانية.');
            }
          }
        }),
      ]));
}

Future<bool> editObjection(BuildContext context,
    {required String kind, required int targetId, Json? existing}) async {
  return await showDialog<bool>(
          context: context,
          builder: (_) => ObjectionEditor(
              kind: kind, targetId: targetId, existing: existing)) ??
      false;
}

class ObjectionEditor extends StatefulWidget {
  final String kind;
  final int targetId;
  final Json? existing;
  const ObjectionEditor(
      {super.key, required this.kind, required this.targetId, this.existing});
  @override
  State<ObjectionEditor> createState() => _ObjectionEditorState();
}

class _ObjectionEditorState extends State<ObjectionEditor> {
  late final TextEditingController _reason =
      TextEditingController(text: widget.existing?['reason'] as String?);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final api = context.read<ApiClient>();
    try {
      if (widget.existing != null) {
        await api.put('/api/v1/objection/update/${widget.targetId}',
            body: {'reason': _reason.text.trim()});
      } else if (widget.kind == 'DONATION') {
        final member = context.read<AuthState>().userId;
        await api.post(
            '/api/v1/donation-proof/objection/$member/${widget.targetId}',
            body: {'reason': _reason.text.trim()});
      } else {
        await api.post(
            '/api/v1/objection/add/${widget.kind == 'PROOF' ? 'proof' : 'excuse'}/${widget.targetId}',
            body: {'reason': _reason.text.trim()});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null
            ? 'خلّينا نراجع القرار'
            : 'عدّل سبب الاعتراض'),
        content: SizedBox(
            width: 460,
            child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          widget.existing == null
                              ? 'وضّح سبب اعتراضك. يصل طلبك للأدمن مع سبب القرار السابق.'
                              : 'نعدل السبب فقط، دون تغيير تاريخ تقديم الاعتراض.',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 20),
                      TextFormField(
                          controller: _reason,
                          maxLength: 1000,
                          minLines: 4,
                          maxLines: 7,
                          decoration: const InputDecoration(
                              labelText: 'سبب الاعتراض',
                              hintText:
                                  'وش المعلومة اللي تساعدنا نراجع القرار؟'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'اكتب سبب الاعتراض.'
                              : null),
                    ]))),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('تراجع')),
          AtButton('أرسل الطلب',
              expand: false, loading: _busy, onPressed: _save)
        ],
      );
}

class ExcuseFormScreen extends StatefulWidget {
  final List<Json> activities;
  final Json? existing;
  const ExcuseFormScreen({super.key, required this.activities, this.existing});
  @override
  State<ExcuseFormScreen> createState() => _ExcuseFormScreenState();
}

class _ExcuseFormScreenState extends State<ExcuseFormScreen> {
  int _selected = 0;
  late String _type = widget.existing?['type'] as String? ?? 'SICK';
  late DateTime _date =
      DateTime.tryParse('${widget.existing?['activityTime']}') ?? riyadhNow();
  CapturedImage? _attachment;
  bool _busy = false;
  Json get _activity => widget.activities[_selected];
  Future<void> _save() async {
    if (_busy) return;
    final previous = widget.existing?['evidenceUrl'] as String?;
    if (_attachment == null && (previous == null || previous.trim().isEmpty)) {
      showMessage(context, 'أرفق مستندًا داعمًا للعذر قبل الإرسال.');
      return;
    }
    setState(() => _busy = true);
    try {
      final client = context.read<ApiClient>();
      final memberId = context.read<AuthState>().userId;
      String? evidence = widget.existing?['evidenceUrl'] as String?;
      if (_attachment != null) {
        evidence = await ProofsApi(client)
            .attachment('excuse', _attachment!.bytes, _attachment!.mime);
      }
      final body = {
        'type': _type,
        'excuseDate': dateInput(_date),
        'evidenceUrl': evidence
      };
      if (widget.existing != null) {
        await client.put(
            '/api/v1/excuse/update/goal-task/${widget.existing!['id']}',
            body: body);
      } else if (_activity['goalTaskId'] != null) {
        await client.post(
            '/api/v1/excuse/add/goal-task/${_activity['goalTaskId']}/week/${_activity['weekId']}',
            body: body);
      } else {
        await client.post(
            '/api/v1/excuse/habit/$memberId/${_activity['weekId']}',
            body: body);
      }
      if (!mounted) return;
      showMessage(
          context,
          widget.existing == null
              ? 'وصل عذرك، تابع حالته من السجل.'
              : 'حفظنا تعديلك.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final now = riyadhNow();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime.tryParse('${_activity['weekStart']}') ??
        today.subtract(Duration(days: today.weekday % 7));
    final end = DateTime.tryParse('${_activity['weekEnd']}') ??
        start.add(const Duration(days: 6));
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    final initial = _date.isBefore(first)
        ? first
        : _date.isAfter(last)
            ? last
            : _date;
    final value = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last);
    if (value != null) setState(() => _date = value);
  }

  // the days of the chosen task's week that already came (up to today), Sunday first
  List<DateTime> _days() {
    final now = riyadhNow();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime.tryParse('${_activity['weekStart']}') ?? today.subtract(Duration(days: today.weekday % 7));
    final first = DateTime(start.year, start.month, start.day);
    final end = DateTime.tryParse('${_activity['weekEnd']}');
    final last = end == null || DateTime(end.year, end.month, end.day).isAfter(today) ? today : DateTime(end.year, end.month, end.day);
    return [for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) d];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final now = riyadhNow();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(_date.year, _date.month, _date.day);
    Widget label(String title, {String? hint}) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Row(children: [
            Text(title, style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
            if (hint != null) ...[const SizedBox(width: 6), Text(hint, style: text.labelSmall)],
          ]),
        );
    const reasons = [
      ('SICK', Icons.medical_services_outlined, 'مرض'),
      ('TRAVEL', Icons.flight_takeoff_rounded, 'سفر'),
      ('EMERGENCY', Icons.warning_amber_rounded, 'طارئ'),
      ('OTHER', Icons.more_horiz_rounded, 'غيره'),
    ];
    return ProofPage(
      title: widget.existing == null ? 'قدّم عذر' : 'تعديل العذر',
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
        // what an excuse does, in one line (design: Excuse)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.pardonSoft, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            IconTile(Icons.shield_outlined, size: 44, fg: Colors.white, bg: c.pardon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('العذر يحمي اليوم', style: text.titleSmall!.copyWith(color: c.pardonText, fontWeight: FontWeight.w800)),
                Text('لو انقبل، ما عليه خصم', style: text.labelSmall!.copyWith(color: c.pardonText)),
              ]),
            ),
          ]),
        ),
        label('أي مهمة؟'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, activity) in widget.activities.indexed)
            ChoiceChip(
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text('${activity['title']}', overflow: TextOverflow.ellipsis),
              ),
              selected: _selected == i,
              showCheckmark: false,
              onSelected: widget.existing != null || _busy ? null : (_) => setState(() => _selected = i),
            ),
        ]),
        label('أي يوم؟'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final d in _days().reversed) ...[
              ChoiceChip(
                label: Text(d == today ? 'اليوم' : weekDaysAr[d.weekday % 7]),
                selected: d == picked,
                showCheckmark: false,
                onSelected: _busy ? null : (_) => setState(() => _date = d),
              ),
              const SizedBox(width: 8),
            ],
            ActionChip(
              avatar: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('تاريخ'),
              onPressed: _busy ? null : _pickDate,
            ),
          ]),
        ),
        label('وش السبب؟'),
        Row(children: [
          for (final (i, (key, icon, name)) in reasons.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _busy ? null : () => setState(() => _type = key),
                child: AnimatedContainer(
                  duration: Motion.base,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _type == key ? c.primarySoft : c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _type == key ? c.accent : c.line, width: _type == key ? 2 : 1),
                  ),
                  child: Column(children: [
                    Icon(icon, size: 22, color: _type == key ? c.primary : c.inkMuted),
                    const SizedBox(height: 4),
                    Text(name, style: text.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: _type == key ? c.primary : c.inkMuted)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
        label('المستند', hint: '(إجباري)'),
        AttachmentPicker(
            label: 'تقرير طبي، تذكرة سفر...',
            image: _attachment,
            onChanged: (value) => setState(() => _attachment = value)),
        if (widget.existing?['evidenceUrl'] != null && _attachment == null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(Icons.attach_file_rounded, size: 16, color: c.success),
                const SizedBox(width: 4),
                Text('المرفق السابق محفوظ', style: text.labelSmall),
              ])),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: c.inkSubtle),
          const SizedBox(width: 6),
          Expanded(child: Text('الذكاء يراجعه أول، ولو ما حسم يروح للمشرف · آخر وقت السبت ١١:٥٩م', style: text.labelSmall)),
        ]),
        const SizedBox(height: 16),
        AtButton(widget.existing == null ? 'أرسل العذر' : 'احفظ التعديل',
            icon: const Icon(Icons.send_rounded, size: 18), onPressed: _busy ? null : _save, loading: _busy),
      ]),
    );
  }
}

class LegacyProofEditScreen extends StatefulWidget {
  final Json proof;
  const LegacyProofEditScreen({super.key, required this.proof});
  @override
  State<LegacyProofEditScreen> createState() => _LegacyProofEditScreenState();
}

class _LegacyProofEditScreenState extends State<LegacyProofEditScreen> {
  CapturedImage? _image;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => ProofPage(
      title: 'تعديل الإثبات',
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const ProofNotice(
            'نغير الدليل فقط قبل بدء التحليل، مع بقاء المهمة وطريقة الإثبات نفسها.'),
        const SizedBox(height: 24),
        Text('${widget.proof['title']}',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        if (widget.proof['type'] == 'PHOTO') ...[
          if (_image != null) Image.memory(_image!.bytes, height: 220),
          AtButton('التقط صورة جديدة', kind: AtButtonKind.outline,
              onPressed: () async {
            final image = await takeProofPhoto(context, 'تعديل صورة الإثبات');
            if (image != null && mounted) setState(() => _image = image);
          }),
          const SizedBox(height: 18),
          AtButton('احفظ التعديل',
              loading: _busy,
              onPressed: _image == null
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        final client = context.read<ApiClient>();
                        final id = await ProofsApi(client).cameraUpload(
                            'PHOTO', _image!.bytes,
                            proofId: widget.proof['id'] as int,
                            mime: _image!.mime);
                        await client.put(
                            '/api/v1/proof/update/goal-task/${widget.proof['id']}',
                            body: {
                              'activityTime': widget.proof['activityTime'],
                              'evidenceData': '$id'
                            });
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (error) {
                        if (context.mounted) proofError(context, error);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    }),
        ] else
          const ProofNotice(
              'تابع هذا الإثبات من طريقة النشاط الأصلية. لا يمكن تغيير نوع الإثبات إلى صورة.'),
      ]));
}
