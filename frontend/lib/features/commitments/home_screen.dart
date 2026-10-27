import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../proofs/activity_proof_entry.dart';
import '../proofs/proof_widgets.dart';
import '../proofs/request_forms.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitment_widgets.dart';
import 'commitments_api.dart';
import 'day_screen.dart';
import '../learn_quest/learn_quest_api.dart';

// OWNER: Turki - the home screen: my level and points, and what is left this week (GET /commitment-week/today)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _api = CommitmentsApi(context.read<ApiClient>());
  int _version = 0; // a new key reloads the screen

  Future<JsonMap> _load() async {
    final tasks = await _api.today();
    JsonMap? stats;
    try {
      stats = await _api.stats();
    } catch (_) {} // the tasks are the important part, the card can be missing
    // Learn Quest - Abdulelah: the library shows only for a learning commitment
    bool hasLearningGoal = false;
    try {
      hasLearningGoal = await LearnQuestApi(context.read<ApiClient>()).hasLearningGoal();
    } catch (_) {} // hide the library if checking eligibility fails
    return {'tasks': tasks, 'stats': stats, 'hasLearningGoal': hasLearningGoal};
  }

  Future<void> _open(String location) async {
    await context.push(location);
    if (mounted) setState(() => _version++);
  }

  Future<void> _newCommitment() async {
    final location = await showAtSheet<String>(
      context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(icon: Icons.add_task_rounded, title: 'تعهّد جديد', subtitle: 'وش نوعه؟'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OptionCard(
                    icon: Icons.repeat_rounded,
                    title: 'عادة',
                    subtitle: 'تتكرر كل أسبوع',
                    onTap: () => Navigator.pop(context, '/habit/add'),
                  ),
                ),
                const SizedBox(width: Space.s3),
                Expanded(
                  child: OptionCard(
                    icon: Icons.flag_rounded,
                    title: 'هدف',
                    subtitle: 'رحلة بمراحل، والذكاء يخططها',
                    onTap: () => Navigator.pop(context, '/goal/new'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (location != null && mounted) await _open(location);
  }

  // postpone inside this week: pick other days, only the reminders move
  Future<void> _postpone(JsonMap task, Future<void> Function() reload) async {
    // the days of this week come with the task (a habit's week, or the goal task's own days)
    var planned = ((task['plannedDays'] as List?) ?? const []).map((d) => '$d').toSet();
    if (task['plannedDays'] == null && task['type'] == 'HABIT') {
      try {
        final week = await _api.currentWeek(task['commitmentId'] as int);
        planned = ((week['plannedDays'] as List?) ?? const []).map((d) => '$d').toSet();
      } catch (error) {
        if (mounted) showError(context, error);
        return;
      }
    }
    if (!mounted) return;
    final days = await showAtSheet<Set<String>>(
      context,
      builder: (context) => _PostponeSheet(
        title: '${task['title']}',
        required: (task['required'] ?? 0) as int,
        planned: planned,
      ),
    );
    if (days == null || !mounted) return;
    try {
      await _api.changeWeekPlan(task['weekId'] as int, days, goalTaskId: task['goalTaskId'] as int?);
      if (!mounted) return;
      showMessage(context, 'تم، غيّرنا أيام التذكير لهالأسبوع بس.');
      await reload();
    } catch (error) {
      if (mounted) _showGraceOrPlanError(error);
    }
  }

  // use a grace day by hand: it counts as an excused time this week
  Future<void> _useGraceDay(JsonMap task, Future<void> Function() reload) async {
    final List<JsonMap> days;
    try {
      days = await _api.graceDays();
    } catch (error) {
      if (mounted) showError(context, error);
      return;
    }
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final usable = days.where((d) {
      final expiresAt = DateTime.tryParse('${d['expiresAt']}');
      return d['usedAt'] == null && expiresAt != null && !expiresAt.isBefore(midnight);
    }).toList()
      // the one that ends first goes first
      ..sort((a, b) => '${a['expiresAt']}'.compareTo('${b['expiresAt']}'));
    if (!mounted) return;
    if (usable.isEmpty) {
      showMessage(context, 'ما عندك بطاقة عفو متاحة. كل ١٥٠ نقطة تعطيك بطاقة.');
      return;
    }
    final day = usable.first;
    final ok = await confirmDialog(
      context,
      title: 'تستخدم بطاقة عفو؟',
      message: 'تنحسب لـ "${task['title']}" مرة معذورة هالأسبوع، وإذا عليها خصم ما انقضى ينلغي. '
          'بطاقة وحدة بس بالأسبوع.\n\nبنستخدم اللي تنتهي ${arabicDigits(day['expiresAt'])} '
          '(باقي عندك ${arabicDigits(usable.length)}).',
      confirm: 'استخدمها',
    );
    if (!ok || !mounted) return;
    try {
      await _api.useGraceDay(day['id'] as int, task['weekId'] as int);
      if (!mounted) return;
      showMessage(context, 'استخدمت بطاقة عفو.');
      await reload();
    } catch (error) {
      if (mounted) _showGraceOrPlanError(error);
    }
  }

  Future<void> _excuse(JsonMap task, Future<void> Function() reload) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ExcuseFormScreen(activities: [Map<String, dynamic>.from(task)])));
    if (mounted) await reload();
  }

  // the backend answers these two in English, the known ones are shown in Arabic
  void _showGraceOrPlanError(Object error) {
    const known = {
      'Only one grace day can be used in a week': 'استخدمت بطاقة عفو هالأسبوع، بطاقة وحدة بس بالأسبوع.',
      'This week does not need a grace day': 'هالأسبوع ما يحتاج بطاقة عفو.',
      'Grace day has expired': 'بطاقة العفو هذي انتهت.',
      'Grace day already used': 'بطاقة العفو هذي مستخدمة.',
      'This week is not running': 'هالأسبوع خلص.',
      'You planned more days than the times of this week':
      'اخترت أيام أكثر من مرات هالأسبوع.',
    };

    final message = error is ApiException ? known[error.message] : null;

    message != null ? showMessage(context, message) : showError(context, error);
  }

  // Lucky Challenge card (Abdulelah)
  Widget _luckyChallengeCard() {
    return FeatureBanner(
      icon: Icons.casino_rounded,
      title: 'مهمة عشوائية',
      subtitle: 'نفّذ مهمة عشوائية وتكسب نقاط زيادة!',
      colors: const [Color(0xFF6A4BE0), Color(0xFF3B2A9E)],
      badge: const TagPill('٣ فرص', fg: Colors.white, bg: Color(0x33FFFFFF)),
      onTap: () => _open('/lucky-challenge'),
    );
  }

  // Learn Quest (Abdulelah): only for a learning commitment
  Widget _learnQuestCard() {
    return FeatureBanner(
      icon: Icons.auto_stories_rounded,
      title: 'رحلة التعلّم',
      subtitle: 'كتب وبودكاست ودورات لهدفك',
      colors: const [Color(0xFF0E7490), Color(0xFF0B4F63)],
      onTap: () => _open('/learn-quest'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthState>().profile ?? const {};
    final name = '${profile['name'] ?? ''}'.trim().split(' ').first;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newCommitment,
        icon: const Icon(Icons.add_rounded),
        label: const Text('أنشئ تعهّد جديد'),
      ),
      body: SafeArea(
        bottom: false,
        child: AsyncView<JsonMap>(
          key: ValueKey(_version),
          load: _load,
          builder: (context, data, reload) {
            final all = data['tasks'] as List<JsonMap>;
            final stats = data['stats'] as JsonMap?;
            // «اليوم» is what is left for today: done today, done for the week and postponed ones move to «تعهّداتي»
            final weekDone = all.where((t) => t['trackStatus'] == 'SETTLED' || (t['remaining'] ?? 1) == 0).toList();
            final doneToday = all.where((t) => !weekDone.contains(t) && t['doneToday'] == true).toList();
            final postponed = all
                .where((t) =>
                    !weekDone.contains(t) &&
                    !doneToday.contains(t) &&
                    questStateOf(t['trackStatus'] as String?) == QuestState.safe &&
                    t['postponedToday'] == true)
                .toList();
            final tasks = all.where((t) => !weekDone.contains(t) && !doneToday.contains(t) && !postponed.contains(t)).toList();
            // by the state, never by the creation date: what to do now first
            final urgent = tasks.where((t) => questStateOf(t['trackStatus'] as String?) == QuestState.urgent).toList();
            final missed = tasks.where((t) => questStateOf(t['trackStatus'] as String?) == QuestState.missed).toList();
            final fine = tasks.where((t) => questStateOf(t['trackStatus'] as String?) == QuestState.safe).toList();
            Widget quest(JsonMap t) => Padding(
                  padding: const EdgeInsets.only(bottom: Space.s3),
                  child: _Quest(
                    task: t,
                    pardons: (stats?['availableGraceDays'] ?? 0) as int,
                    onProve: () async {
                      await openActivityProof(context, Map<String, dynamic>.from(t));
                      if (context.mounted) await reload();
                    },
                    onPostpone: () => _postpone(t, reload),
                    onPardon: () => _useGraceDay(t, reload),
                    onExcuse: () => _excuse(t, reload),
                  ),
                );
            final c = context.colors;
            final sections = [
              if (urgent.isNotEmpty) ('لازم اليوم', urgent, Icons.bolt_rounded, c.urgent),
              if (missed.isNotEmpty) ('يحتاج قرار', missed, Icons.error_outline_rounded, c.danger),
              if (fine.isNotEmpty) ('ماشية تمام', fine, Icons.check_circle_outline_rounded, c.success),
            ];
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, 96), // room for the button
                children: [
                  _Header(
                    name: name,
                    stats: stats,
                    onLevel: () => _open('/stats'),
                    onCommitments: () => _open('/commitments'),
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 14),
                    // the next reward is always in sight
                    RewardProgress(
                      label: 'بطاقة العفو الجاية',
                      current: 150 - ((stats['pointsToGraceDay'] ?? 150) as int).clamp(0, 150),
                      target: 150,
                      onTap: () => _open('/stats'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _WeekStrip(
                    onDay: (day) async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => DayScreen(day: day)));
                    },
                  ),
                  // today's quest bar: what is done out of what was due today
                  if (all.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _TodayBar(done: doneToday.length, total: doneToday.length + tasks.length),
                  ],
                  if (all.isEmpty)
                    _EmptyToday(
                      icon: Icons.flag_rounded,
                      title: 'ما عندك مهام اليوم',
                      line: 'اللي يبدأ بعدين تلقاه في تعهّداتي',
                    )
                  else if (tasks.isEmpty)
                    _EmptyToday(
                      icon: Icons.task_alt_rounded,
                      title: 'خلّصت اللي عليك اليوم',
                      line: 'كفو! نشوفك بكرة',
                    ),
                  for (final (title, list, icon, color) in sections) ...[
                    SectionHeader(title, count: arabicDigits(list.length), icon: icon, color: color),
                    ...list.map(quest),
                  ],
                  // what is out of the way: done today, done for the week, moved to another day
                  if (doneToday.isNotEmpty || weekDone.isNotEmpty) ...[
                    SectionHeader(
                      'خلّصت ${arabicDigits(doneToday.length + weekDone.length)} ${doneToday.length + weekDone.length == 1 ? 'مهمة' : 'مهام'}',
                      icon: Icons.task_alt_rounded,
                      color: c.success,
                    ),
                    for (final t in doneToday) _DoneRow(task: t, label: 'خلّصتها اليوم', color: c.success, soft: c.successSoft),
                    for (final t in weekDone) _DoneRow(task: t, label: 'خلّصت هذا الأسبوع', color: c.accent, soft: c.primarySoft),
                  ],
                  if (postponed.isNotEmpty) ...[
                    SectionHeader('أجّلتها ليوم ثاني', count: arabicDigits(postponed.length), icon: Icons.event_repeat_rounded, color: c.inkSubtle),
                    for (final t in postponed) _DoneRow(task: t, label: 'مؤجلة', color: c.inkSubtle, soft: c.surfaceSunken, icon: Icons.event_repeat_rounded),
                  ],
                  const SizedBox(height: Space.s5),
                  _luckyChallengeCard(),
                  if (data['hasLearningGoal'] == true) ...[
                    const SizedBox(height: Space.s3),
                    _learnQuestCard(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// a different hello for the morning, the afternoon and the night
String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'صباح الهمّة';
  if (hour < 18) return 'هلا';
  return 'مساء الإنجاز';
}

// the top: my avatar in my level's ring, the hello on its own line, my name, my level and weeks,
// then my points and pardon cards
class _Header extends StatelessWidget {
  final String name;
  final JsonMap? stats;
  final VoidCallback onLevel;
  final VoidCallback onCommitments;

  const _Header({required this.name, required this.stats, required this.onLevel, required this.onCommitments});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final level = stats?['level'] as String?;
    final weeks = (stats?['consecutiveWeeks'] ?? 0) as int;
    final ring = c.level(level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              button: true,
              label: 'مستواي',
              child: GestureDetector(
                onTap: onLevel,
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.primarySoft,
                    boxShadow: [BoxShadow(color: ring, spreadRadius: 5), BoxShadow(color: c.bg, spreadRadius: 3)],
                  ),
                  child: Text(name.isEmpty ? '؟' : name.characters.first,
                      style: text.headlineSmall!.copyWith(color: c.primary, fontWeight: FontWeight.w800, height: 1.2)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: onLevel,
                borderRadius: BorderRadius.circular(Radii.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(), style: text.labelSmall!.copyWith(color: c.inkSubtle)),
                    Text(name.isEmpty ? 'هلا' : name,
                        style: text.headlineSmall!.copyWith(fontWeight: FontWeight.w800, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (level != null)
                      Row(children: [
                        Icon(Icons.military_tech_rounded, size: 14, color: ring),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(levelsAr[level] ?? level, style: text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (weeks > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.local_fire_department_rounded, size: 14, color: c.urgent),
                          const SizedBox(width: 2),
                          Text('${arabicDigits(weeks)} أسابيع', style: text.labelSmall),
                        ],
                      ]),
                  ],
                ),
              ),
            ),
            // all my habits and goals
            Material(
              color: c.surface,
              shape: StadiumBorder(side: BorderSide(color: c.line)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onCommitments,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.checklist_rounded, size: 18, color: c.primary),
                    const SizedBox(width: 4),
                    Text('عاداتي وأهدافي', style: text.labelMedium!.copyWith(color: c.primary, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ],
        ),
        if (stats != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              ResourceChip(ResourceKind.points, (stats!['points'] ?? 0) as num, onTap: onLevel),
              const SizedBox(width: 8),
              ResourceChip(ResourceKind.pardon, (stats!['availableGraceDays'] ?? 0) as num, onTap: onLevel),
            ],
          ),
        ],
      ],
    );
  }
}

// the 7 days of this week (Sunday first), three fixed colors: the days that passed, today, the coming days.
// A day that passed (or today) opens its page, the coming days are only shown
class _WeekStrip extends StatelessWidget {
  final void Function(DateTime day) onDay;

  const _WeekStrip({required this.onDay});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sunday = today.subtract(Duration(days: today.weekday % 7));
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Builder(builder: (context) {
              final day = sunday.add(Duration(days: i));
              final isToday = day == today;
              final future = day.isAfter(today);
              final (Color bar, Color label) = isToday
                  ? (c.primary, c.primary)
                  : future
                      ? (c.line, c.inkSubtle.withValues(alpha: 0.6))
                      : (c.accent.withValues(alpha: 0.45), c.inkMuted);
              final cell = Column(
                children: [
                  Container(height: 6, decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(Radii.full))),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      weekDaysAr[i],
                      style: text.labelSmall!.copyWith(
                        fontSize: 11,
                        color: label,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
              if (future) return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: cell);
              return Semantics(
                button: true,
                label: weekDaysFull[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDay(day),
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: cell),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

const weekDaysFull = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

// nothing left today: one icon and one line
class _EmptyToday extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line;
  const _EmptyToday({required this.icon, required this.title, required this.line});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s5),
      child: Container(
        padding: const EdgeInsets.all(Space.s5),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
        child: Column(
          children: [
            IconTile(icon, size: 56, fg: c.success, bg: c.successSoft),
            const SizedBox(height: Space.s3),
            Text(title, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w800)),
            Text(line, style: text.labelSmall),
          ],
        ),
      ),
    );
  }
}

// a task that is out of the way: a small row with its state on the end
class _DoneRow extends StatelessWidget {
  final JsonMap task;
  final String label;
  final Color color;
  final Color soft;
  final IconData icon;

  const _DoneRow({required this.task, required this.label, required this.color, required this.soft, this.icon = Icons.check_rounded});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
        child: Row(
          children: [
            IconTile(icon, size: 34, fg: color, bg: soft),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${task['title']}',
                  style: text.labelLarge!.copyWith(color: c.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            TagPill(label, fg: color, bg: soft),
          ],
        ),
      ),
    );
  }
}

class _Quest extends StatelessWidget {
  final JsonMap task;
  final VoidCallback onProve;
  final VoidCallback onPostpone;
  final VoidCallback onPardon;
  final VoidCallback onExcuse;
  final int pardons; // the pardon cards the member has

  const _Quest({required this.task, required this.onProve, required this.onPostpone, required this.onPardon, required this.onExcuse, this.pardons = 0});

  @override
  Widget build(BuildContext context) {
    final t = task;
    final needed = (t['required'] ?? 0) as int;
    final completed = (t['completed'] ?? 0) as int;
    final excused = (t['excused'] ?? 0) as int;
    final state = questStateOf(t['trackStatus'] as String?);
    final settled = t['trackStatus'] == 'SETTLED';
    // pardon by hand: habits only (goals use it by themselves). postpone: any task with times left
    final habitRunning = t['type'] == 'HABIT' && !settled;
    final canPostpone = !settled && ((t['remaining'] ?? 0) as int) > 0;
    final meta = [
      'باقي ${arabicDigits(t['remaining'])} من ${arabicDigits(needed)}',
      if (t['daysLeft'] != null && !settled) '${arabicDigits(t['daysLeft'])} أيام باقية',
      if (state == QuestState.safe && t['plannedToday'] == true && !settled) 'مخططة اليوم',
      if (t['type'] == 'GOAL') 'هدف',
    ].join(' · ');
    return QuestCard(
      state: state,
      metaWidget: _QuestMeta(
        completed: completed,
        excused: excused,
        total: needed,
        daysLeft: settled ? null : t['daysLeft'] as int?,
        plannedToday: state == QuestState.safe && t['plannedToday'] == true && !settled,
        goal: t['type'] == 'GOAL',
      ),
      icon: proofMethodIcon(t['proofMethod'] as String?),
      title: ActivityHeading(title: '${t['title']}', goalTitle: t['goalTitle'] as String?, taskTitle: t['taskTitle'] as String?),
      meta: meta,
      // an excused time counts as done this week
      done: completed + excused,
      total: needed,
      stake: t['amountPerTime'] as num?,
      onTap: settled ? null : onProve,
      actionLabel: t['proofMethod'] == 'QUIZ' ? 'ابدأ الكويز' : 'ارفع الإثبات',
      onAction: onProve,
      // a lost day always offers it (it tells how to earn one), the other states only when there is a card
      onPardon: habitRunning && ((t['remaining'] ?? 0) as int) > 0 && (state == QuestState.missed || pardons > 0) ? onPardon : null,
      pardons: pardons,
      onExcuse: onExcuse,
      onPostpone: canPostpone ? onPostpone : null,
      badge: settled ? StatusBadge.track('SETTLED') : null,
    );
  }
}

// the days of this week only, the habit default stays as it is
class _PostponeSheet extends StatefulWidget {
  final String title;
  final int required;
  final Set<String> planned;

  const _PostponeSheet({required this.title, required this.required, required this.planned});

  @override
  State<_PostponeSheet> createState() => _PostponeSheetState();
}

class _PostponeSheetState extends State<_PostponeSheet> {
  late Set<String> _days = {...widget.planned};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              icon: Icons.event_repeat_rounded,
              title: 'أجّل "${widget.title}"',
              subtitle: 'اختر أيام التذكير لهالأسبوع · ${arabicDigits(widget.required)} بالكثير',
            ),
            const SizedBox(height: Space.s3),
            PlannedDaysPicker(
              selected: _days,
              onChanged: (next) {
                if (next.length > widget.required) {
                  showMessage(context, 'هالأسبوع عليك ${arabicDigits(widget.required)} مرات بس.');
                  return;
                }
                setState(() => _days = next);
              },
            ),
            const SizedBox(height: Space.s4),
            AtButton('احفظ', icon: const Icon(Icons.check_rounded, size: 20), onPressed: () => Navigator.pop(context, _days)),
          ],
        ),
      ),
    );
  }
}


// «خلّصت ٢ من ٥ اليوم»: a bar that fills, a trophy when everything is done
class _TodayBar extends StatelessWidget {
  final int done;
  final int total;

  const _TodayBar({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final all = total > 0 && done >= total;
    final value = total == 0 ? 0.0 : (done / total).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: all ? c.successSoft : c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: all ? c.success.withValues(alpha: 0.4) : c.line),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: Motion.base,
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Icon(
              all ? Icons.emoji_events_rounded : Icons.flag_circle_rounded,
              key: ValueKey(all),
              size: 30,
              color: all ? c.success : c.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  all ? 'يومك مكتمل، كفو!' : 'مهام اليوم: ${arabicDigits(done)} من ${arabicDigits(total)}',
                  style: text.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: all ? c.success : c.ink),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.full),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value),
                    duration: Motion.reward,
                    curve: Motion.easeOut,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: c.surfaceSunken,
                      valueColor: AlwaysStoppedAnimation(all ? c.success : c.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// the times of the week as small icons: a blue check = done, a purple shield = excused, a grey circle = left.
// Then the days left, «today» when it is planned, and a flag for a goal
class _QuestMeta extends StatelessWidget {
  final int completed;
  final int excused;
  final int total;
  final int? daysLeft;
  final bool plannedToday;
  final bool goal;

  const _QuestMeta({
    required this.completed,
    required this.excused,
    required this.total,
    required this.daysLeft,
    required this.plannedToday,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final small = text.labelSmall!.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600);
    Widget info(IconData icon, String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(label, style: small.copyWith(color: color)),
        ]);
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          label: 'سوّيت ${arabicDigits(completed)} من ${arabicDigits(total)}',
          child: total > 8
              ? info(Icons.check_circle_rounded, '${arabicDigits(completed + excused)}/${arabicDigits(total)}', c.accent)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < total; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 2),
                      child: i < completed
                          ? Icon(Icons.check_circle_rounded, size: 16, color: c.accent)
                          : i < completed + excused
                              ? Icon(Icons.shield_rounded, size: 16, color: c.pardon)
                              : Icon(Icons.circle_outlined, size: 16, color: c.inkSubtle.withValues(alpha: 0.6)),
                    ),
                ]),
        ),
        if (daysLeft != null) info(Icons.event_rounded, '${arabicDigits(daysLeft)} ${daysLeft == 1 ? 'يوم' : 'أيام'}', c.inkSubtle),
        if (plannedToday) info(Icons.alarm_rounded, 'اليوم', c.primary),
        if (goal) info(Icons.flag_rounded, 'هدف', c.inkSubtle),
      ],
    );
  }
}
