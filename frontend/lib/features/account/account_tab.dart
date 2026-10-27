import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/state/data_refresh.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/theme/theme_state.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/widgets.dart';
import '../commitments/commitment_widgets.dart' show confirmDialog;

// OWNER: Abdulelah - the "حسابي" tab (design: Account)
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  // my name, email and phone in a sheet, with the edit button
  void _showProfile(BuildContext context, Map profile) {
    showAtSheet<void>(
      context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(icon: Icons.badge_outlined, title: 'بياناتي'),
            RowGroup(children: [
              for (final (icon, label, value) in [
                (Icons.person_outline_rounded, 'الاسم', profile['name']),
                (Icons.alternate_email_rounded, 'الإيميل', profile['email']),
                (Icons.phone_iphone_rounded, 'الجوال', profile['phone']),
              ])
                ActionRow(
                  icon: icon,
                  title: '${value ?? '-'}',
                  subtitle: label,
                ),
            ]),
            const SizedBox(height: Space.s4),
            AtButton('عدّل بياناتي', icon: const Icon(Icons.edit_rounded, size: 18), onPressed: () {
              Navigator.pop(sheet);
              context.push('/update-profile');
            }),
          ],
        ),
      ),
    );
  }

  // deactivating ends every running commitment and leaves the groups, so it asks first
  Future<void> _deactivate(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'تعطّل حسابك؟',
      message: 'تنتهي كل تعهّداتك الشغّالة وتطلع من مجموعاتك، وما تقدر ترجع لها. '
          'لازم تكون مسدّد كل خصوماتك قبل.',
      confirm: 'عطّل الحساب',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<ApiClient>().put('/api/v1/account/deactivate');
      if (!context.mounted) return;
      showMessage(context, 'تعطّل حسابك. نتمنى نشوفك مرة ثانية');
      await context.read<AuthState>().logout();
    } catch (e) {
      if (!context.mounted) return;
      final raw = '$e';
      showMessage(
        context,
        raw.contains('Pay the donations')
            ? 'سدّد خصوماتك أول، بعدها تقدر تعطّل الحساب.'
            : raw.contains('already deactivated')
                ? 'الحساب معطّل من قبل.'
                : 'ما قدرنا نعطّل الحساب، حاول مرة ثانية.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final profile = auth.profile ?? {};
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final mode = context.watch<ThemeState>().mode;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            DataRefresh.instance.bump();
            await auth.refreshProfile();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s5, Space.s4, Space.s8),
            children: [
              Text('حسابي', style: text.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: Space.s3),
              _HeroCard(profile: profile, isMember: auth.isMember),
              if (auth.isMember) ...[
                const SizedBox(height: Space.s4),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    // no lines above and under the open tile
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      leading: IconTile(Icons.grid_view_rounded, size: 40, fg: c.success, bg: c.successSoft),
                      title: const Text('نشاطي'),
                      subtitle: const Text('أسبوع، شهر أو سنة'),
                      childrenPadding: const EdgeInsets.all(Space.s2),
                      children: const [_ActivityHeatmap()],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Space.s4),
              RowGroup(children: [
                ActionRow(icon: Icons.badge_outlined, title: 'بياناتي', subtitle: 'الاسم والإيميل والجوال', onTap: () => _showProfile(context, profile)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.s4, 12, Space.s4, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        IconTile(Icons.dark_mode_outlined, size: 40, fg: c.pardon, bg: c.pardonSoft),
                        const SizedBox(width: Space.s4),
                        Text('المظهر', style: text.labelLarge!.copyWith(fontSize: 15)),
                      ]),
                      const SizedBox(height: 10),
                      SegmentedPills<ThemeMode>(
                        options: const [(ThemeMode.light, 'فاتح'), (ThemeMode.dark, 'داكن'), (ThemeMode.system, 'حسب الجهاز')],
                        value: mode,
                        onChanged: (m) => context.read<ThemeState>().setMode(m),
                      ),
                    ],
                  ),
                ),
                ActionRow(
                  icon: Icons.calendar_month_outlined,
                  title: 'جدولة مهامك',
                  subtitle: 'Google Calendar يقترح أوقات مهامك',
                  tone: c.info,
                  onTap: () => context.push('/google-calendar'),
                ),
              ]),
              const SizedBox(height: Space.s4),
              RowGroup(children: [
                if (auth.isMember)
                  ActionRow(icon: Icons.person_off_outlined, title: 'تعطيل الحساب', danger: true, onTap: () => _deactivate(context)),
                ActionRow(
                  icon: Icons.logout_rounded,
                  title: 'تسجيل الخروج',
                  danger: true,
                  trailing: const SizedBox.shrink(),
                  onTap: () => context.read<AuthState>().logout(),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// the blue card (design: Account): my letter, name, level, and four numbers. A tap opens «مستواي»
class _HeroCard extends StatefulWidget {
  final Map profile;
  final bool isMember;

  const _HeroCard({required this.profile, required this.isMember});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
    DataRefresh.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataRefresh.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.isMember) return;
    try {
      final data = await context.read<ApiClient>().get('/api/v1/commitment/stats');
      if (mounted && data is Map) setState(() => _stats = Map<String, dynamic>.from(data));
    } catch (_) {} // the card shows the profile numbers meanwhile
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final p = widget.profile;
    final s = _stats ?? const {};
    final name = '${p['name'] ?? ''}'.trim();
    final level = (s['level'] ?? p['level'])?.toString();
    String n(Object? v) => arabicDigits(v is num ? (v % 1 == 0 ? v.toInt() : v) : (v ?? 0));
    const soft = Color(0xFFB7C5E8);
    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.isDark ? c.deepRaised : c.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: c.deep, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          // two soft circles, like the design
          PositionedDirectional(
            top: -40,
            end: -40,
            child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent.withValues(alpha: 0.45))),
          ),
          PositionedDirectional(
            bottom: -50,
            start: 120,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.pardon,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [BoxShadow(color: Color(0xFF8FB4FF), spreadRadius: 3)],
                      ),
                      child: Text(name.isEmpty ? '؟' : name.characters.first,
                          style: text.headlineLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.2)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? '-' : name,
                              style: text.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if ('${p['email'] ?? ''}'.isNotEmpty)
                            Text('${p['email']}', style: text.labelSmall!.copyWith(color: soft), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (widget.isMember && level != null) ...[
                            const SizedBox(height: 6),
                            TagPill(levelsAr[level] ?? level, fg: Colors.white, bg: c.accent, icon: Icons.military_tech_rounded),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isMember) const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                  ],
                ),
                if (widget.isMember) ...[
                  const SizedBox(height: Space.s4),
                  Row(
                    children: [
                      Expanded(child: StatCell(value: n(s['points'] ?? p['points']), label: 'نقطة')),
                      const SizedBox(width: 6),
                      Expanded(child: StatCell(value: n(s['availableGraceDays']), label: 'بطاقة عفو')),
                      const SizedBox(width: 6),
                      Expanded(child: StatCell(value: n(s['consecutiveWeeks'] ?? p['consecutiveWeeks']), label: 'أسبوع ورا بعض')),
                      const SizedBox(width: 6),
                      Expanded(child: StatCell(value: n(s['totalDonated']), label: 'ريال للخير', valueColor: c.goldLight)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (!widget.isMember) return card;
    return Semantics(
      button: true,
      label: 'مستواي ونقاطي',
      child: GestureDetector(onTap: () => context.push('/stats'), child: card),
    );
  }
}

// Commitment Heatmap (Abdulelah): my done tasks per day, as a week, a month or a year that fits the screen
enum _Period { week, month, year }

class _ActivityHeatmap extends StatefulWidget {
  const _ActivityHeatmap();

  @override
  State<_ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<_ActivityHeatmap> {
  static const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static const _days = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س']; // Sunday first

  bool _loading = true;
  bool _error = false;
  Map<String, int> _activity = {};
  _Period _period = _Period.week;
  late DateTime _anchor = _today; // the week / month / year shown
  DateTime? _selected;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActivity());
    DataRefresh.instance.addListener(_quietLoad);
  }

  // a proof or a task done on another page: the map gets its new square without the spinner
  void _quietLoad() {
    if (!_loading && !_error) _loadActivity(silent: true);
  }

  @override
  void dispose() {
    DataRefresh.instance.removeListener(_quietLoad);
    super.dispose();
  }

  Future<void> _loadActivity({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final result = await context.read<ApiClient>().get('/api/v1/member/activity-map');
      if (result is! List) throw Exception('Invalid activity map response');
      final activity = <String, int>{};
      for (final item in result) {
        if (item is! Map || item['date'] == null) continue;
        final date = DateTime.tryParse('${item['date']}');
        if (date == null) continue;
        activity[_key(date)] = int.tryParse('${item['completed'] ?? 0}') ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _activity = activity;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || silent) return; // a quiet reload keeps the map on screen
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  String _key(DateTime d) => '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';
  int _count(DateTime d) => _activity[_key(d)] ?? 0;
  DateTime _sunday(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday % 7));

  // the days of the period shown
  (DateTime, DateTime) get _range => switch (_period) {
        _Period.week => (_sunday(_anchor), _sunday(_anchor).add(const Duration(days: 6))),
        _Period.month => (DateTime(_anchor.year, _anchor.month, 1), DateTime(_anchor.year, _anchor.month + 1, 0)),
        _Period.year => (DateTime(_anchor.year, 1, 1), DateTime(_anchor.year, 12, 31)),
      };

  String get _title {
    final (from, to) = _range;
    return switch (_period) {
      _Period.week => '${arabicDigits(from.day)} ${_months[from.month - 1]} - ${arabicDigits(to.day)} ${_months[to.month - 1]}',
      _Period.month => '${_months[_anchor.month - 1]} ${arabicDigits(_anchor.year)}',
      _Period.year => arabicDigits(_anchor.year),
    };
  }

  void _move(int step) => setState(() {
        _selected = null;
        _anchor = switch (_period) {
          _Period.week => _anchor.add(Duration(days: 7 * step)),
          _Period.month => DateTime(_anchor.year, _anchor.month + step, 1),
          _Period.year => DateTime(_anchor.year + step, 1, 1),
        };
      });

  bool get _canGoNext => _range.$2.isBefore(_today);

  Color _color(int completed) {
    final c = context.colors;
    if (completed <= 0) return c.surfaceSunken;
    if (completed == 1) return c.accent.withValues(alpha: 0.35);
    if (completed == 2) return c.accent.withValues(alpha: 0.6);
    if (completed == 3) return c.accent.withValues(alpha: 0.8);
    return c.accent;
  }

  // one day: a rounded square, the day number on it when there is room
  Widget _square(DateTime d, double size, {bool number = true}) {
    final c = context.colors;
    final count = _count(d);
    final future = d.isAfter(_today);
    final isToday = d == _today;
    final selected = _selected == d;
    return GestureDetector(
      onTap: future ? null : () => setState(() => _selected = selected ? null : d),
      child: AnimatedContainer(
        duration: Motion.fast,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: future ? Colors.transparent : _color(count),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: selected
              ? Border.all(color: c.primary, width: 2)
              : isToday
                  ? Border.all(color: c.ink, width: 1.5)
                  : future
                      ? Border.all(color: c.line)
                      : null,
        ),
        child: number && size >= 22
            ? Text(arabicDigits(d.day),
                style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: count >= 2 ? Colors.white : c.inkMuted))
            : null,
      ),
    );
  }

  // a month as a 7 column grid (Sunday first) that fills the given width
  Widget _monthGrid(DateTime month, double width, {bool numbers = true, bool header = true}) {
    final text = Theme.of(context).textTheme;
    const gap = 4.0;
    final size = (width - gap * 6) / 7;
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7;
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    return Column(
      children: [
        if (header)
          Row(children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(width: size, child: Text(_days[i], textAlign: TextAlign.center, style: text.labelSmall!.copyWith(fontSize: 11))),
            ],
          ]),
        if (header) const SizedBox(height: 6),
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: gap),
          Row(children: [
            for (var col = 0; col < 7; col++) ...[
              if (col > 0) const SizedBox(width: gap),
              Builder(builder: (_) {
                final index = r * 7 + col - lead;
                if (index < 0 || index >= days) return SizedBox(width: size, height: size);
                return _square(DateTime(month.year, month.month, index + 1), size, number: numbers);
              }),
            ],
          ]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    if (_loading) return const Padding(padding: EdgeInsets.all(Space.s5), child: Center(child: CircularProgressIndicator()));
    if (_error) {
      return Padding(
        padding: const EdgeInsets.all(Space.s4),
        child: Column(children: [
          Text('ما قدرنا نجيب نشاطك', style: text.labelLarge),
          TextButton.icon(onPressed: _loadActivity, icon: const Icon(Icons.refresh_rounded), label: const Text('حاول مرة ثانية')),
        ]),
      );
    }
    final (from, to) = _range;
    var active = 0, total = 0, streak = 0, best = 0;
    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      final n = _count(d);
      total += n;
      if (n > 0) {
        active++;
        streak++;
        if (streak > best) best = streak;
      } else if (!d.isAfter(_today)) {
        streak = 0;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s2, 0, Space.s2, Space.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedPills<_Period>(
            options: const [(_Period.week, 'أسبوع'), (_Period.month, 'شهر'), (_Period.year, 'سنة')],
            value: _period,
            onChanged: (p) => setState(() {
              _period = p;
              _anchor = _today;
              _selected = null;
            }),
          ),
          const SizedBox(height: Space.s3),
          // ‹ the period ›
          Row(
            children: [
              IconButton(tooltip: 'اللي قبل', onPressed: () => _move(-1), icon: const Icon(Icons.chevron_right_rounded)),
              Expanded(child: Text(_title, textAlign: TextAlign.center, style: text.titleSmall)),
              IconButton(tooltip: 'اللي بعد', onPressed: _canGoNext ? () => _move(1) : null, icon: const Icon(Icons.chevron_left_rounded)),
            ],
          ),
          const SizedBox(height: Space.s2),
          LayoutBuilder(builder: (context, box) {
            final width = box.maxWidth;
            switch (_period) {
              case _Period.week:
                const gap = 6.0;
                final size = (width - gap * 6) / 7;
                return Row(children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Column(children: [
                      Text(_days[i], style: text.labelSmall!.copyWith(fontSize: 11)),
                      const SizedBox(height: 6),
                      _square(from.add(Duration(days: i)), size),
                    ]),
                  ],
                ]);
              case _Period.month:
                return _monthGrid(DateTime(_anchor.year, _anchor.month), width);
              case _Period.year:
                // 12 small months, 3 in a row, every square in sight
                const gap = 12.0;
                final cell = (width - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      SizedBox(
                        width: cell,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_months[m - 1], style: text.labelSmall!.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            _monthGrid(DateTime(_anchor.year, m), cell, numbers: false, header: false),
                          ],
                        ),
                      ),
                  ],
                );
            }
          }),
          const SizedBox(height: Space.s3),
          // less -> more
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('أقل', style: text.labelSmall),
              const SizedBox(width: 6),
              for (final n in const [0, 1, 2, 3, 4]) ...[
                Container(width: 14, height: 14, decoration: BoxDecoration(color: _color(n), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 2),
              Text('أكثر', style: text.labelSmall),
            ],
          ),
          if (_selected != null) ...[
            const SizedBox(height: Space.s3),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(children: [
                Icon(_count(_selected!) > 0 ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded, color: c.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${arabicDigits(_selected!.day)} ${_months[_selected!.month - 1]} · '
                    '${_count(_selected!) > 0 ? '${arabicDigits(_count(_selected!))} إنجاز' : 'ما فيه إنجاز'}',
                    style: text.labelLarge,
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: Space.s3),
          Row(
            children: [
              _Stat(icon: Icons.event_available_rounded, value: arabicDigits(active), label: 'يوم نشيط', color: c.accent),
              _Stat(icon: Icons.task_alt_rounded, value: arabicDigits(total), label: 'إنجاز', color: c.success),
              _Stat(icon: Icons.local_fire_department_rounded, value: arabicDigits(best), label: 'أطول سلسلة', color: c.urgent),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(value, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: text.labelSmall!.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
