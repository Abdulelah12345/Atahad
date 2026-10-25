import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
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
        AtButton(image == null ? 'اختاري صورة' : 'غيّري الصورة',
            kind: AtButtonKind.outline, onPressed: () async {
          try {
            final file = await ImagePicker().pickImage(
                source: ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
            if (file == null) return;
            final bytes = await file.readAsBytes();
            if (bytes.length > 2 * 1024 * 1024) {
              if (context.mounted) {
                showMessage(context, 'اختاري صورة أصغر من ٢ ميغابايت.');
              }
              return;
            }
            onChanged(CapturedImage(bytes, imageMime(bytes)));
          } catch (error) {
            if (context.mounted) {
              showMessage(context, 'تعذر فتح الصورة. جربي صورة ثانية.');
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
            : 'عدّلي سبب الاعتراض'),
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
                              ? 'وضحي سبب اعتراضك. يصل طلبك للأدمن مع سبب القرار السابق.'
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
                              ? 'اكتبي سبب الاعتراض.'
                              : null),
                    ]))),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('تراجع')),
          AtButton('أرسلي الطلب',
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
      showMessage(context, 'أرفقي مستندًا داعمًا للعذر قبل الإرسال.');
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
              ? 'وصل عذرك، تابعي حالته من السجل.'
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

  @override
  Widget build(BuildContext context) => ProofPage(
      title: widget.existing == null ? 'تقديم عذر' : 'تعديل العذر',
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text('ظروفك لها اعتبار',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        const Text(
            'اختاري النشاط واليوم، وأرفقي مستندًا داعمًا للعذر لتقييمه.'),
        const SizedBox(height: 24),
        DropdownButtonFormField<int>(
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'النشاط'),
            items: [
              for (final (i, activity) in widget.activities.indexed)
                DropdownMenuItem(
                    value: i,
                    child: Text('${activity['title']}',
                        overflow: TextOverflow.ellipsis))
            ],
            onChanged: widget.existing != null || _busy
                ? null
                : (v) => setState(() => _selected = v ?? 0)),
        const SizedBox(height: 20),
        Text('نوع الظرف', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final type in excuseNames.entries)
            ChoiceChip(
                label: Text(type.value),
                selected: _type == type.key,
                onSelected:
                    _busy ? null : (_) => setState(() => _type = type.key))
        ]),
        const SizedBox(height: 20),
        AppCard(
            onTap: _busy ? null : _pickDate,
            child: Row(children: [
              const Icon(Icons.calendar_month_outlined),
              const SizedBox(width: 12),
              const Text('يوم النشاط'),
              const Spacer(),
              Text(displayDate(_date.toIso8601String())),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more)
            ])),
        const SizedBox(height: 20),
        AttachmentPicker(
            label: 'مستند داعم للعذر — مطلوب',
            image: _attachment,
            onChanged: (value) => setState(() => _attachment = value)),
        if (widget.existing?['evidenceUrl'] != null && _attachment == null)
          const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('المرفق السابق محفوظ. اختيار صورة جديدة يستبدله.')),
        const SizedBox(height: 20),
        const ProofNotice(
            'آخر وقت لرفع الأعذار هو نهاية الأسبوع، السبت ١١:٥٩ مساءً. إذا بدأ التحليل أو التحويل للأدمن، يتوقف التعديل والحذف.'),
        const SizedBox(height: 24),
        AtButton(widget.existing == null ? 'أرسلي العذر' : 'احفظي التعديل',
            onPressed: _busy ? null : _save, loading: _busy),
      ]));
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
          AtButton('التقطي صورة جديدة', kind: AtButtonKind.outline,
              onPressed: () async {
            final image = await takeProofPhoto(context, 'تعديل صورة الإثبات');
            if (image != null && mounted) setState(() => _image = image);
          }),
          const SizedBox(height: 18),
          AtButton('احفظي التعديل',
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
              'تابعي هذا الإثبات من طريقة النشاط الأصلية. لا يمكن تغيير نوع الإثبات إلى صورة.'),
      ]));
}
