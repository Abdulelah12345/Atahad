import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/widgets/widgets.dart';
import 'camera_capture_screen.dart';
import 'proof_widgets.dart';
import 'proofs_api.dart';
import 'request_forms.dart';

class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});
  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  late final ApiClient _client = context.read<ApiClient>();
  late Future<Json> _data = _load();
  bool _busy = false;
  CapturedImage? _bank;
  CapturedImage? _ehsan;
  int get _member => context.read<AuthState>().userId!;
  Future<Json> _load() async {
    final values = await Future.wait([
      _client.get('/api/v1/penalty/my/$_member'),
      _client.get('/api/v1/donation-proof/my/$_member')
    ]);
    return {'penalties': values[0], 'donations': values[1]};
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _data = future);
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _submit(bool email) async {
    if (!email && (_bank == null || _ehsan == null)) {
      showMessage(context, 'أرفقي صورة رسالة البنك وصورة رسالة إحسان.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (email) {
        await _client.post('/api/v1/donation-proof/email/$_member');
      } else {
        final api = ProofsApi(_client);
        final bank =
            await api.attachment('donation-proof', _bank!.bytes, _bank!.mime);
        final ehsan =
            await api.attachment('donation-proof', _ehsan!.bytes, _ehsan!.mime);
        await _client.post('/api/v1/donation-proof/screenshot/$_member',
            body: {'bankMessageImageUrl': bank, 'ehsanMessageImageUrl': ehsan});
      }
      if (!mounted) return;
      final auth = context.read<AuthState>();
      await auth.refreshProfile();
      await auth.refreshLock();
      if (!mounted) return;
      setState(() {
        _bank = null;
        _ehsan = null;
      });
      await _reload();
      if (mounted) {
        showMessage(context, 'وصل إثبات التبرع. راجعي النتيجة في السجل.');
      }
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gmail() async {
    final linked = context.read<AuthState>().profile?['emailLinked'] == true;
    if (linked) {
      if (!await confirmDelete(context,
          'نفصل ربط Gmail ونحذف كلمة مرور التطبيقات المحفوظة للربط.')) {
        return;
      }
      try {
        await _client
            .delete('/api/v1/donation-proof/gmail/disconnect/$_member');
        if (mounted) await context.read<AuthState>().refreshProfile();
      } catch (error) {
        if (mounted) proofError(context, error);
      }
      return;
    }
    if (!mounted) return;
    final done = await showDialog<bool>(
        context: context,
        builder: (_) => GmailConnectDialog(memberId: _member));
    if (done == true && mounted) {
      await context.read<AuthState>().refreshProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final linked = context.watch<AuthState>().profile?['emailLinked'] == true;
    final text = Theme.of(context).textTheme;
    return ProofPage(
        title: 'التبرع والمبالغ',
        actions: [
          IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: _reload)
        ],
        child: FutureBuilder<Json>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return ErrorView(
                    message: friendlyError(snapshot.error!), onRetry: _reload);
              }
              final penalties = ProofsApi.maps(snapshot.data!['penalties']);
              final donations = ProofsApi.maps(snapshot.data!['donations']);
              final pending =
                  penalties.where((p) => p['status'] == 'PENDING').toList();
              final amount = pending.fold<num>(
                  0, (sum, p) => sum + (p['amount'] as num? ?? 0));
              return ListView(padding: const EdgeInsets.all(24), children: [
                AppCard(
                    color: context.colors.surfaceSunken,
                    padding: const EdgeInsets.all(26),
                    child: Column(children: [
                      Icon(Icons.volunteer_activism_outlined,
                          size: 42, color: context.colors.goldText),
                      const SizedBox(height: 14),
                      Text(
                          pending.isEmpty
                              ? 'ما عليك مبلغ معلّق'
                              : 'مبلغك يصنع خيرًا',
                          style: text.headlineMedium),
                      const SizedBox(height: 12),
                      RiyalAmount(amount, style: text.displayMedium),
                      const SizedBox(height: 12),
                      const Text(
                          'تتبرعين بنفسك لمنصة إحسان، ثم ترفعين ما يثبت التحويل. ما فيه دفع أو خصم من بطاقتك داخل التطبيق.',
                          textAlign: TextAlign.center),
                      if (pending.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        AtButton('افتحي منصة إحسان', kind: AtButtonKind.gold,
                            onPressed: () async {
                          if (!await launchUrl(Uri.parse('https://ehsan.sa'),
                                  mode: LaunchMode.externalApplication) &&
                              context.mounted) {
                            showMessage(context, 'تعذر فتح إحسان الآن.');
                          }
                        })
                      ],
                    ])),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('إثبات التبرع', style: text.headlineSmall),
                  const SizedBox(height: 10),
                  const Text(
                      'اختاري الطريقة المناسبة. الصور لازم تخص نفس عملية التحويل.'),
                  const SizedBox(height: 18),
                  AttachmentPicker(
                      label: 'رسالة التحويل من البنك',
                      image: _bank,
                      onChanged: (image) => setState(() => _bank = image)),
                  const SizedBox(height: 14),
                  AttachmentPicker(
                      label: 'رسالة تأكيد إحسان',
                      image: _ehsan,
                      onChanged: (image) => setState(() => _ehsan = image)),
                  const SizedBox(height: 18),
                  AtButton('أرسلي صور التبرع',
                      kind: AtButtonKind.gold,
                      loading: _busy,
                      onPressed: _submitImages),
                  const SizedBox(height: 24),
                  AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('أو من رسالة البنك في Gmail',
                            style: text.titleLarge),
                        const SizedBox(height: 10),
                        const Text(
                            'بعد ربط بريدك، نبحث عن رسالة التحويل المطابقة للمبلغ المطلوب.'),
                        const SizedBox(height: 16),
                        AtButton(
                            linked ? 'تحققي من رسالة التحويل' : 'اربطي Gmail',
                            kind: AtButtonKind.outline,
                            loading: _busy,
                            onPressed: _busy
                                ? null
                                : linked
                                    ? () => _submit(true)
                                    : _gmail),
                        if (linked)
                          AtButton('افصلي ربط Gmail',
                              kind: AtButtonKind.text,
                              onPressed: _busy ? null : _gmail),
                      ])),
                ] else if (linked) ...[
                  const SizedBox(height: 18),
                  AtButton('افصلي ربط Gmail',
                      kind: AtButtonKind.text, onPressed: _gmail)
                ],
                const SizedBox(height: 30),
                Text('سجل المبالغ', style: text.titleLarge),
                const SizedBox(height: 12),
                if (penalties.isEmpty)
                  const ProofEmpty(
                      title: 'صفحتك خالية من المبالغ',
                      message: 'إذا ترتب مبلغ على نشاط، يظهر هنا مع حالته.',
                      icon: Icons.volunteer_activism_outlined),
                for (final p in penalties)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                          child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  switch (p['reason']) {
                                    'LOST_DAY' => 'مرة لم تكتمل',
                                    'WITHDRAWAL' => 'انسحاب من تعهد',
                                    'GROUP_COLLECTIVE' => 'مبلغ جماعي',
                                    _ => 'مبلغ التزام'
                                  },
                                  style: text.titleMedium),
                              const SizedBox(height: 5),
                              Text(displayDate(p['createdAt']),
                                  style: text.bodySmall),
                            ])),
                        RiyalAmount(p['amount'] as num?),
                        const SizedBox(width: 12),
                        StatusBadge(
                            p['status'] == 'PAID'
                                ? 'تم التبرع'
                                : p['status'] == 'CANCELLED'
                                    ? 'ملغي'
                                    : 'بانتظار التبرع',
                            kind: p['status'] == 'PENDING'
                                ? BadgeKind.warning
                                : BadgeKind.success),
                      ]))),
                const SizedBox(height: 24),
                Text('إثباتات التبرع', style: text.titleLarge),
                const SizedBox(height: 12),
                if (donations.isEmpty)
                  const Text('إثباتاتك تظهر هنا بعد إرسالها.'),
                for (final d in donations)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                  child: Text(
                                      d['method'] == 'EMAIL'
                                          ? 'رسالة البنك'
                                          : 'صور التحويل',
                                      style: text.titleMedium)),
                              StatusBadge.review(d['status'] as String?)
                            ]),
                            const SizedBox(height: 10),
                            Text(displayDate(d['createdAt']),
                                style: text.bodySmall),
                            if (d['amount'] != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: RiyalAmount(d['amount'] as num?)),
                            if (d['aiResult'] != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text('${d['aiResult']}',
                                      style: text.bodySmall)),
                            if (d['bankMessageImageUrl'] != null)
                              ExpansionTile(
                                  title: const Text('عرض الصور المرفقة'),
                                  children: [
                                    EvidenceImage(
                                        '${d['bankMessageImageUrl']}'),
                                    const SizedBox(height: 12),
                                    EvidenceImage(
                                        '${d['ehsanMessageImageUrl']}')
                                  ]),
                            if (d['status'] == 'REJECTED')
                              AtButton('اعترضي على القرار',
                                  kind: AtButtonKind.text, onPressed: () async {
                                if (await editObjection(context,
                                    kind: 'DONATION',
                                    targetId: d['id'] as int)) {
                                  _reload();
                                }
                              }),
                          ]))),
              ]);
            }));
  }

  void _submitImages() => _submit(false);
}

class GmailConnectDialog extends StatefulWidget {
  final int memberId;
  const GmailConnectDialog({super.key, required this.memberId});
  @override
  State<GmailConnectDialog> createState() => _GmailConnectDialogState();
}

class _GmailConnectDialogState extends State<GmailConnectDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().post(
          '/api/v1/donation-proof/gmail/connect/${widget.memberId}',
          body: {
            'gmailAddress': _email.text.trim(),
            'appPassword': _password.text.trim()
          });
      _password.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('ربط Gmail'),
          content: SizedBox(
              width: 450,
              child: Form(
                  key: _form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'استخدمي كلمة مرور التطبيقات التي تصدر من إعدادات حساب Google، وليست كلمة مرور بريدك الأساسية.'),
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني'),
                        validator: (v) => v != null &&
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(v.trim())
                            ? null
                            : 'اكتبي بريدًا صحيحًا.'),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _password,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                            labelText: 'كلمة مرور التطبيقات'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'أدخلي كلمة مرور التطبيقات.'
                            : null),
                  ]))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('تراجع')),
            AtButton('اربطي البريد',
                expand: false, loading: _busy, onPressed: _connect)
          ]);
}
