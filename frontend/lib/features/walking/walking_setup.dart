import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/at_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'walking_api.dart';
import 'walking_health.dart';

class WalkingDraft {
  final steps = TextEditingController(text: '5000');
  String mode = 'HEALTH_DATA';
  WalkingReading? reading;
  bool checked = false;
  Map<String, dynamic> toJson() => {
    'targetSteps': int.tryParse(normalizeWalkingNumber(steps.text)),
    'stepEvidenceMode': mode,
  };
  String? validate({bool editing = false}) {
    final n = int.tryParse(normalizeWalkingNumber(steps.text));
    if (n == null || n < 100 || n > 100000) {
      return 'اختر هدفًا بين ١٠٠ و١٠٠٬٠٠٠ خطوة لليوم.';
    }
    if (!editing && mode == 'HEALTH_DATA' && !checked) {
      return 'افحص ربط الخطوات أولًا، أو اختر إثبات الصورة.';
    }
    return null;
  }

  WalkingDraft();
  WalkingDraft.from(Map<String, dynamic> habit) {
    steps.text = '${habit['targetSteps'] ?? 5000}';
    mode = '${habit['stepEvidenceMode'] ?? 'HEALTH_DATA'}';
  }
  void dispose() => steps.dispose();
}

class WalkingSetup extends StatefulWidget {
  final WalkingDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onUseTimer;
  final bool editing;
  final WalkingHealthReader? reader;
  const WalkingSetup({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onUseTimer,
    this.editing = false,
    this.reader,
  });
  @override
  State<WalkingSetup> createState() => _WalkingSetupState();
}

class _WalkingSetupState extends State<WalkingSetup> {
  late final _reader = widget.reader ?? NativeWalkingHealthReader();
  bool _checking = false;
  String? _error;
  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      widget.draft.checked = false;
    });
    try {
      final result = await _reader.read(walkingNow(), requestPermission: true);
      if (!mounted) return;
      widget.draft.reading = result;
      if (result.source != null && result.installation != null) {
        await WalkingApi(
          context.read<ApiClient>(),
        ).check(result.connectionBody);
      }
      if (!mounted) return;
      widget.draft.checked = result.ready;
    } catch (_) {
      _error = 'ما اكتمل حفظ فحص الربط. تحقق من الاتصال وحاول مرة ثانية.';
    } finally {
      if (mounted) {
        setState(() => _checking = false);
        widget.onChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_walk_rounded, color: c.primary),
              const SizedBox(width: 8),
              Text('خطواتك تصنع الفرق', style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'الهدف مجموع خطوات اليوم كاملًا، حتى لو مشيت على فترات. اليوم يُحسب بتوقيت الرياض.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: draft.steps,
            enabled: !widget.editing && !_checking,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'هدف خطوات اليوم',
              suffixText: 'خطوة',
            ),
            onChanged: (_) => widget.onChanged(),
            validator: (_) {
              final n = int.tryParse(normalizeWalkingNumber(draft.steps.text));
              return n == null || n < 100 || n > 100000
                  ? 'من ١٠٠ إلى ١٠٠٬٠٠٠ خطوة'
                  : null;
            },
          ),
          if (!widget.editing) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final n in [3000, 5000, 8000])
                  ActionChip(
                    label: Text('${arabicDigits(n)} خطوة'),
                    onPressed: _checking
                        ? null
                        : () {
                            draft.steps.text = '$n';
                            widget.onChanged();
                          },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: draft.mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'كيف نثبت إنجازك؟'),
            items: const [
              DropdownMenuItem(
                value: 'HEALTH_DATA',
                child: Text('ربط خطوات الجوال'),
              ),
              DropdownMenuItem(
                value: 'SCREENSHOT',
                child: Text('صورة خطوات اليوم'),
              ),
            ],
            onChanged: widget.editing || _checking
                ? null
                : (value) {
                    setState(() => draft.mode = value!);
                    widget.onChanged();
                  },
          ),
          const SizedBox(height: 12),
          if (widget.editing)
            const Text('هدف الخطوات وطريقة الإثبات ثابتان بعد بدء التعهّد.')
          else if (draft.mode == 'HEALTH_DATA') ...[
            Text(
              _error ??
                  draft.reading?.message ??
                  'نطلب قراءة الخطوات فقط، بدون تعديل بيانات الصحة أو تتبّع موقعك.',
            ),
            if (draft.checked && draft.reading?.total != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'خطواتك اليوم: ${arabicDigits(draft.reading!.total)}',
                  style: text.titleMedium?.copyWith(color: c.success),
                ),
              ),
            const SizedBox(height: 12),
            AtButton(
              draft.checked ? 'إعادة فحص الربط' : 'فحص ربط الخطوات',
              loading: _checking,
              onPressed: _check,
              kind: AtButtonKind.outline,
              icon: const Icon(Icons.sync),
            ),
            if (_reader.supported && draft.reading != null && !draft.checked)
              TextButton(
                onPressed: () async {
                  try {
                    await _reader.openSettings();
                  } catch (_) {}
                },
                child: const Text('افتح الإعدادات'),
              ),
          ] else
            const Text(
              'ارفع صورة واضحة يظهر فيها التاريخ الكامل ومجموع خطوات اليوم. يراجعها المشرف قبل اعتماد الإنجاز.',
            ),
          if (!widget.editing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _checking ? null : widget.onUseTimer,
              child: const Text('أفضل تعهّد المشي بالدقائق'),
            ),
          ],
        ],
      ),
    );
  }
}
