import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'camera_capture_screen.dart';
import 'proof_widgets.dart';
import 'proofs_api.dart';
import 'request_forms.dart';

// the donation (design: DonateProof): two steps and the lock opens
// 1. donate in Ehsan  2. prove it: the two photos (the bank message + the Ehsan message), or faster: the bank email in Gmail
// under them: the amounts and the donation proofs (an objection on a rejected one)
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});
  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  late final ApiClient _client = context.read<ApiClient>();
  late Future<Json> _data = _load();
  bool _busy = false;
  bool _checkingEmail = false;
  CapturedImage? _bank;
  CapturedImage? _ehsan;
  int get _member => context.read<AuthState>().userId!;

  Future<Json> _load() async {
    final values = await Future.wait([
      _client.get('/api/v1/penalty/my/$_member'),
      _client.get('/api/v1/donation-proof/my/$_member'),
    ]);
    return {'penalties': values[0], 'donations': values[1]};
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _data = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _openEhsan() async {
    if (!await launchUrl(Uri.parse('https://ehsan.sa'), mode: LaunchMode.externalApplication) && mounted) {
      showMessage(context, 'ما قدرنا نفتح منصة إحسان، افتح ehsan.sa من المتصفح');
    }
  }

  Future<void> _pick(bool bank) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) showMessage(context, 'اختر صورة أصغر من ٢ ميغابايت.');
        return;
      }
      final image = CapturedImage(bytes, imageMime(bytes));
      setState(() {
        if (bank) {
          _bank = image;
        } else {
          _ehsan = image;
        }
      });
    } catch (_) {
      if (mounted) showMessage(context, 'تعذر فتح الصورة. جرّب صورة ثانية.');
    }
  }

  // the answer of the backend: ACCEPTED opens the app, ESCALATED opens it until the admin decides, REJECTED says why
  Future<void> _submit(bool email) async {
    if (!email && (_bank == null || _ehsan == null)) {
      showMessage(context, 'ارفع صورة رسالة البنك وصورة رسالة إحسان.');
      return;
    }
    setState(() {
      if (email) {
        _checkingEmail = true;
      } else {
        _busy = true;
      }
    });
    try {
      dynamic result;
      if (email) {
        result = await _client.post('/api/v1/donation-proof/email/$_member');
      } else {
        final api = ProofsApi(_client);
        final bank = await api.attachment('donation-proof', _bank!.bytes, _bank!.mime);
        final ehsan = await api.attachment('donation-proof', _ehsan!.bytes, _ehsan!.mime);
        result = await _client.post('/api/v1/donation-proof/screenshot/$_member',
            body: {'bankMessageImageUrl': bank, 'ehsanMessageImageUrl': ehsan});
      }
      if (!mounted) return;
      final auth = context.read<AuthState>();
      await auth.refreshProfile();
      await auth.refreshLock();
      if (!mounted) return;
      final status = result is Map ? '${result['status']}' : '';
      final amount = result is Map ? result['amount'] as num? : null;
      final note = result is Map ? result['aiResult'] as String? : null;
      setState(() {
        _bank = null;
        _ehsan = null;
      });
      await _reload();
      if (!mounted) return;
      if (status == 'ACCEPTED') {
        HapticFeedback.mediumImpact(); // the app opens: one tap
        // all the donations so far (the paid amounts), for the unlocked screen
        num donated = 0;
        try {
          final data = await _data;
          for (final p in ProofsApi.maps(data['penalties'])) {
            if (p['status'] == 'PAID') donated += (p['amount'] as num? ?? 0);
          }
        } catch (_) {}
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _UnlockedScreen(amount: amount, donated: donated)));
      } else if (status == 'ESCALATED') {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ReviewScreen(amount: amount, email: email)));
      } else if (status == 'REJECTED') {
        showMessage(context, 'ما انقبل الإثبات${note == null ? '' : ': $note'}. تقدر ترفع إثبات ثاني أو تعترض من السجل تحت.');
      } else {
        showMessage(context, 'وصل إثبات التبرع.');
      }
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _checkingEmail = false;
        });
      }
    }
  }

  Future<void> _gmail() async {
    final linked = context.read<AuthState>().profile?['emailLinked'] == true;
    if (linked) {
      if (!await confirmDelete(context, 'نفصل ربط Gmail ونحذف كلمة مرور التطبيقات المحفوظة للربط.')) return;
      try {
        await _client.delete('/api/v1/donation-proof/gmail/disconnect/$_member');
        if (mounted) await context.read<AuthState>().refreshProfile();
      } catch (error) {
        if (mounted) proofError(context, error);
      }
      return;
    }
    if (!mounted) return;
    final done = await showDialog<bool>(context: context, builder: (_) => GmailConnectDialog(memberId: _member));
    if (done == true && mounted) await context.read<AuthState>().refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    final linked = context.watch<AuthState>().profile?['emailLinked'] == true;
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: FutureBuilder<Json>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
            if (snapshot.hasError) return ErrorView(message: friendlyError(snapshot.error!), onRetry: _reload);
            final penalties = ProofsApi.maps(snapshot.data!['penalties']);
            final donations = ProofsApi.maps(snapshot.data!['donations']);
            final pending = penalties.where((p) => p['status'] == 'PENDING').toList();
            final amount = pending.fold<num>(0, (sum, p) => sum + (p['amount'] as num? ?? 0));
            final ready = _bank != null && _ehsan != null;
            return Column(
              children: [
                // the header: back, the title, what is owed
                Padding(
                  padding: const EdgeInsets.all(Space.s4),
                  child: Row(
                    children: [
                      Material(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.canPop() ? context.pop() : context.go('/lock'),
                          child: SizedBox(width: 44, height: 44, child: Icon(Icons.arrow_back_rounded, color: c.primary)),
                        ),
                      ),
                      const SizedBox(width: Space.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('التبرع', style: text.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
                            Text(pending.isEmpty ? 'ما عليك مبلغ الحين' : 'خطوتين ويفتح القفل', style: text.labelSmall),
                          ],
                        ),
                      ),
                      if (pending.isNotEmpty) RiyalAmount(amount, color: c.goldText, style: text.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
                      IconButton(tooltip: 'تحديث', onPressed: _reload, icon: Icon(Icons.refresh_rounded, color: c.inkSubtle)),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s6),
                      children: [
                        if (pending.isEmpty)
                          _StepCard(
                            leading: _StepDot.done(c),
                            title: 'ما عليك مبلغ معلّق',
                            child: Text('إذا ترتّب عليك مبلغ يطلع هنا، وتتبرّع فيه لإحسان بنفسك.', style: text.bodySmall),
                          )
                        else ...[
                          // 1. donate
                          _StepCard(
                            leading: _StepDot.number(c, '١', c.accent),
                            title: 'تبرّع في منصة إحسان',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('أي مشروع تختاره، بمبلغ ${money(amount)} ريال أو أكثر. حوّل بعد وقت الخصم.', style: text.bodySmall),
                                const SizedBox(height: Space.s2),
                                Material(
                                  color: c.surfaceSunken,
                                  borderRadius: BorderRadius.circular(Radii.md),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(Radii.md),
                                    onTap: _openEhsan,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Text('افتح إحسان', style: text.labelLarge!.copyWith(color: c.primary, fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 6),
                                        Icon(Icons.open_in_new_rounded, size: 16, color: c.primary),
                                      ]),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // the bank apps list charities too, a donation to one of them is accepted like Ehsan
                                Text('أو تبرّع لأي جمعية خيرية من تطبيق بنكك.', style: text.labelSmall),
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.s3),
                          // 2. prove it
                          _StepCard(
                            highlight: true,
                            leading: _StepDot.number(c, '٢', c.primary),
                            title: 'ثبّت إنك تبرّعت',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('صورتين لنفس التحويل:', style: text.bodySmall),
                                const SizedBox(height: Space.s2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _UploadTile(
                                        icon: Icons.smartphone_rounded,
                                        label: 'رسالة البنك',
                                        image: _bank,
                                        onTap: () => _pick(true),
                                        onRemove: () => setState(() => _bank = null),
                                      ),
                                    ),
                                    const SizedBox(width: Space.s2),
                                    Expanded(
                                      child: _UploadTile(
                                        icon: Icons.volunteer_activism_rounded,
                                        label: 'رسالة إحسان',
                                        image: _ehsan,
                                        onTap: () => _pick(false),
                                        onRemove: () => setState(() => _ehsan = null),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: Space.s3),
                                AtButton('أرسل الصورتين', loading: _busy, onPressed: ready && !_checkingEmail ? () => _submit(false) : null),
                                const SizedBox(height: Space.s4),
                                Row(children: [
                                  Expanded(child: Divider(color: c.line)),
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('أو أسرع', style: text.labelSmall)),
                                  Expanded(child: Divider(color: c.line)),
                                ]),
                                const SizedBox(height: Space.s3),
                                // faster: the bank email
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
                                        child: Icon(Icons.mail_outline_rounded, size: 20, color: c.primary),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(linked ? 'من إيميل البنك' : 'فكّ القفل تلقائي',
                                                style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
                                            Text(
                                              linked
                                                  ? 'Gmail مربوط. بعد ما يوصلك إيميل البنك اضغط تحقّق.'
                                                  : 'اربط Gmail ونقرأ إيميل البنك بنفسنا.',
                                              style: text.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_checkingEmail)
                                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      else
                                        TextButton(
                                          onPressed: _busy ? null : (linked ? () => _submit(true) : _gmail),
                                          child: Text(linked ? 'تحقّق' : 'اربط', style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ),
                                    ],
                                  ),
                                ),
                                if (linked)
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: TextButton(
                                      onPressed: _busy || _checkingEmail ? null : _gmail,
                                      style: TextButton.styleFrom(foregroundColor: c.inkSubtle),
                                      child: const Text('افصل ربط Gmail'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: Space.s5),
                        _History(
                          penalties: penalties,
                          donations: donations,
                          onObjected: _reload,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// a white step card, the current step has a primary ring
class _StepCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final Widget child;
  final bool highlight;

  const _StepCard({required this.leading, required this.title, required this.child, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: [
          if (highlight) BoxShadow(color: c.primary, spreadRadius: 2),
          BoxShadow(color: highlight ? c.primary : c.line, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final Color color;
  final Widget child;

  const _StepDot(this.color, this.child);

  factory _StepDot.number(AtColors c, String n, Color color) =>
      _StepDot(color, Text(n, style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w800, fontSize: 16)));

  factory _StepDot.done(AtColors c) => _StepDot(c.success, const Icon(Icons.check_rounded, color: Colors.white, size: 20));

  @override
  Widget build(BuildContext context) =>
      Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: child);
}

// a photo tile: dashed when empty, green with a check when it is chosen
class _UploadTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final CapturedImage? image;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _UploadTile({required this.icon, required this.label, required this.image, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final done = image != null;
    final tile = Semantics(
      button: true,
      label: done ? '$label، انرفعت، اضغط عشان تغيّرها' : 'ارفع $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.base,
          height: 120,
          decoration: BoxDecoration(
            color: done ? c.successSoft : c.bg,
            borderRadius: BorderRadius.circular(14),
            border: done ? Border.all(color: c.accent, width: 2) : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (done)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Opacity(opacity: 0.18, child: Image.memory(image!.bytes, fit: BoxFit.cover)),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(done ? Icons.check_rounded : icon, color: done ? c.success : c.primary, size: done ? 26 : 22),
                  const SizedBox(height: 4),
                  Text(label, style: text.labelMedium!.copyWith(color: done ? c.success : c.primary, fontWeight: FontWeight.w700)),
                  Text(done ? 'انرفعت' : 'اضغط وارفع الصورة', style: text.labelSmall!.copyWith(fontSize: 11)),
                ],
              ),
              if (done)
                PositionedDirectional(
                  top: 2,
                  end: 2,
                  child: IconButton(
                    tooltip: 'شيل الصورة',
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: Icon(Icons.close_rounded, size: 18, color: c.inkSubtle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (done) return tile;
    return CustomPaint(painter: _Dashed(color: c.lineStrong), child: tile);
  }
}

class _Dashed extends CustomPainter {
  final Color color;

  _Dashed({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)).deflate(1));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => old.color != color;
}

// the amounts and the donation proofs (folded)
class _History extends StatelessWidget {
  final List<Json> penalties;
  final List<Json> donations;
  final VoidCallback onObjected;

  const _History({required this.penalties, required this.donations, required this.onObjected});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    Widget section(String title, int count, List<Widget> children) => Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(title, style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
              trailing: Text(arabicDigits(count), style: text.labelSmall),
              childrenPadding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s3),
              children: children,
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section('سجل المبالغ', penalties.length, [
          if (penalties.isEmpty) Text('صفحتك خالية من المبالغ.', style: text.bodySmall),
          for (final p in penalties)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s2),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        switch (p['reason']) {
                          'LOST_DAY' => 'مرة ما اكتملت',
                          'WITHDRAWAL' => 'انسحاب من تعهّد',
                          'GROUP_COLLECTIVE' => 'تسوية المجموعة',
                          _ => 'مبلغ التزام',
                        },
                        style: text.labelLarge),
                    Text(displayDate(p['createdAt']), style: text.labelSmall),
                  ]),
                ),
                RiyalAmount(p['amount'] as num?),
                const SizedBox(width: Space.s2),
                StatusBadge(
                  p['status'] == 'PAID' ? 'تم التبرع' : p['status'] == 'CANCELLED' ? 'ملغي' : 'بانتظار التبرع',
                  kind: p['status'] == 'PENDING' ? BadgeKind.warning : BadgeKind.success,
                ),
              ]),
            ),
        ]),
        const SizedBox(height: Space.s2),
        section('إثباتات التبرع', donations.length, [
          if (donations.isEmpty) Text('إثباتاتك تطلع هنا بعد ما ترسلها.', style: text.bodySmall),
          for (final d in donations)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s3),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(d['method'] == 'EMAIL' ? 'إيميل البنك' : 'صور التحويل', style: text.labelLarge)),
                  StatusBadge.review(d['status'] as String?),
                ]),
                Text(displayDate(d['createdAt']), style: text.labelSmall),
                if (d['amount'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: RiyalAmount(d['amount'] as num?)),
                if (d['aiResult'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${d['aiResult']}', style: text.bodySmall)),
                if (d['status'] == 'REJECTED')
                  TextButton(
                    onPressed: () async {
                      if (await editObjection(context, kind: 'DONATION', targetId: d['id'] as int)) onObjected();
                    },
                    child: const Text('اعترض على القرار'),
                  ),
              ]),
            ),
        ]),
      ],
    );
  }
}

// leaves a result screen: closes it (it was pushed on top of the donation page), then goes to the home page
void _leave(BuildContext context) {
  final router = GoRouter.of(context);
  Navigator.of(context).pop();
  router.go('/');
}

// the lock opened (design: Unlocked): the key comes in and turns, then the shackle jumps open
class _UnlockedScreen extends StatelessWidget {
  final num? amount;
  final num donated; // everything donated so far

  const _UnlockedScreen({required this.amount, required this.donated});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s10, Space.s5, Space.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Space.s8),
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
                  child: const _OpeningLock(),
                ),
              ),
              const SizedBox(height: 34),
              Text('رجع التطبيق مفتوح', textAlign: TextAlign.center, style: text.headlineLarge!.copyWith(fontWeight: FontWeight.w800, fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                amount == null ? 'تبرّعك وصل باسمك. في الحالتين.. خير.' : '${money(amount)} ريال وصلت باسمك. في الحالتين.. خير.',
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: c.inkMuted, height: 1.7),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 14),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: c.warningSoft, borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.favorite_border_rounded, color: c.goldText, size: 22),
                    ),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مجموع تبرعاتك', style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
                          Text('من أول ما بديت', style: text.labelSmall),
                        ],
                      ),
                    ),
                    Text(money(donated), style: text.titleLarge!.copyWith(color: c.goldText, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Spacer(),
              AtButton('رجوع لليوم', onPressed: () => _leave(context)),
            ],
          ),
        ),
      ),
    );
  }
}

// the key slides in and turns (0 -> 0.6 of the time), then the shackle jumps up (0.9 -> 1)
class _OpeningLock extends StatefulWidget {
  const _OpeningLock();

  @override
  State<_OpeningLock> createState() => _OpeningLockState();
}

class _OpeningLockState extends State<_OpeningLock> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(size: const Size(140, 170), painter: _OpenLockPainter(_c.value)),
    );
  }
}

class _OpenLockPainter extends CustomPainter {
  final double t;

  _OpenLockPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    double phase(double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);
    final keyIn = Curves.easeOutBack.transform(phase(0, 0.55));
    final keyTurn = Curves.easeOut.transform(phase(0.55, 0.7));
    final open = Curves.elasticOut.transform(phase(0.7, 1));

    // the shackle goes up and turns a little
    canvas.save();
    canvas.translate(106, 76);
    canvas.rotate(-0.35 * open);
    canvas.translate(-106, -76 - 16 * open);
    final shackle = Paint()
      ..color = const Color(0xFF7DA6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(34, 76)
        ..lineTo(34, 50)
        ..arcToPoint(const Offset(106, 50), radius: const Radius.circular(36))
        ..lineTo(106, 76),
      shackle,
    );
    canvas.restore();

    canvas.drawRRect(RRect.fromLTRBR(10, 72, 130, 168, const Radius.circular(22)), Paint()..color = const Color(0xFF1C46C9));
    canvas.drawRRect(RRect.fromLTRBR(10, 72, 130, 92, const Radius.circular(10)), Paint()..color = const Color(0xFF2F6BF2));
    canvas.drawCircle(const Offset(70, 120), 9, Paint()..color = const Color(0xFF0A1A3A));

    // the gold key: from up right into the hole, then a quarter turn
    canvas.save();
    canvas.translate(70 + 40 * (1 - keyIn), 120 - 30 * (1 - keyIn));
    canvas.rotate(-0.52 * (1 - keyIn) + 1.57 * keyTurn);
    final gold = Paint()
      ..color = const Color(0xFFF2B33D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(-36, 0), 13, gold);
    canvas.drawLine(const Offset(-23, 0), const Offset(6, 0), gold);
    canvas.drawLine(const Offset(-6, 0), const Offset(-6, 9), gold);
    canvas.drawLine(const Offset(2, 0), const Offset(2, 7), gold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OpenLockPainter old) => old.t != t;
}

// the proof went to the admin: the AI could not decide, the app is open until the admin answers
class _ReviewScreen extends StatelessWidget {
  final num? amount;
  final bool email;

  const _ReviewScreen({required this.amount, required this.email});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    Widget step(IconData icon, Color color, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
                    Text(body, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        );
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s10, Space.s5, Space.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Space.s6),
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(color: c.pardonSoft, shape: BoxShape.circle),
                  child: Icon(Icons.hourglass_top_rounded, size: 72, color: c.pardon),
                ),
              ),
              const SizedBox(height: Space.s6),
              Text('إثباتك عند المراجعة', textAlign: TextAlign.center, style: text.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                email
                    ? 'وصلنا إيميل البنك${amount == null ? '' : ' بمبلغ ${money(amount)} ريال'}، بس ما قدرنا نتأكد منه تلقائيًا، فحوّلناه للمشرف.'
                    : 'وصلتنا الصورتين${amount == null ? '' : ' بمبلغ ${money(amount)} ريال'}، بس ما قدرنا نتأكد منها تلقائيًا، فحوّلناها للمشرف.',
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: c.inkMuted, height: 1.7),
              ),
              const SizedBox(height: Space.s6),
              Container(
                padding: const EdgeInsets.all(Space.s4),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
                child: Column(
                  children: [
                    step(Icons.lock_open_rounded, c.success, 'التطبيق مفتوح لك الحين', 'تقدر تكمّل أهدافك لين يطلع القرار.'),
                    step(Icons.check_circle_outline_rounded, c.primary, 'إذا انقبل', 'يتسدّد المبلغ ويوصلك إشعار.'),
                    step(Icons.lock_outline_rounded, c.urgent, 'إذا انرفض', 'يرجع القفل، وتقدر تعترض على القرار أو ترفع إثبات ثاني.'),
                  ],
                ),
              ),
              const Spacer(),
              AtButton('كمّل أهدافك', onPressed: () => _leave(context)),
              const SizedBox(height: Space.s2),
              AtButton('ارجع لصفحة التبرع', kind: AtButtonKind.text, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
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
      await context.read<ApiClient>().post('/api/v1/donation-proof/gmail/connect/${widget.memberId}',
          body: {'gmailAddress': _email.text.trim(), 'appPassword': _password.text.trim()});
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
                    const Text('استخدم كلمة مرور التطبيقات اللي تطلع من إعدادات حساب Google، مو كلمة مرور بريدك الأساسية.'),
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                        validator: (v) => v != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ? null : 'اكتب بريد صحيح.'),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _password,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'كلمة مرور التطبيقات'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'أدخل كلمة مرور التطبيقات.' : null),
                  ]))),
          actions: [
            TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('تراجع')),
            AtButton('اربط البريد', expand: false, loading: _busy, onPressed: _connect)
          ]);
}
