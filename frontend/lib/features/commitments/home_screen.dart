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
    // the week strip: which days of this week had a done task
    Map<String, int> activity = {};
    try {
      final map = await context.read<ApiClient>().get('/api/v1/member/activity-map');
      for (final item in (map as List? ?? const [])) {
        if (item is Map && item['date'] != null) activity['${item['date']}'] = int.tryParse('${item['completed'] ?? 0}') ?? 0;
      }
    } catch (_) {} // the strip just shows the days without the marks
    return {'tasks': tasks, 'stats': stats, 'hasLearningGoal': hasLearningGoal, 'activity': activity};
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
      title: 'تحدي الحظ',
      subtitle: 'تحدي مفاجئ اليوم بـ ٢٠ نقطة',
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
            // «تعهّد جديد» sits on the first heading, always in sight
            final newButton = TextButton.icon(
              onPressed: _newCommitment,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('تعهّد جديد'),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.s2), visualDensity: VisualDensity.compact),
            );
            final sections = [
              if (urgent.isNotEmpty) ('لازم اليوم', urgent),
              if (missed.isNotEmpty) ('يحتاج قرار', missed),
              if (fine.isNotEmpty) ('ماشية تمام', fine),
            ];
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s8),
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
                  _WeekStrip(activity: Map<String, int>.from(data['activity'] as Map? ?? const {})),
                  if (all.isEmpty)
                    _EmptyToday(
                      icon: Icons.flag_rounded,
                      title: 'ما عندك مهام اليوم',
                      line: 'اللي يبدأ بعدين تلقاه في تعهّداتي',
                      action: 'تعهّد جديد',
                      onAction: _newCommitment,
                    )
                  else if (tasks.isEmpty)
                    _EmptyToday(
                      icon: Icons.task_alt_rounded,
                      title: 'خلّصت اللي عليك اليوم',
                      line: 'كفو! نشوفك بكرة',
                      action: 'تعهّد جديد',
                      onAction: _newCommitment,
                    ),
                  for (final (i, (title, list)) in sections.indexed) ...[
                    SectionHeader(title, count: arabicDigits(list.length), action: i == 0 ? newButton : null),
                    ...list.map(quest),
                  ],
                  if (doneToday.isNotEmpty || postponed.isNotEmpty || weekDone.isNotEmpty) ...[
                    const SizedBox(height: Space.s2),
                    _ElsewhereRow(
                      doneToday: doneToday.length,
                      postponed: postponed.length,
                      weekDone: weekDone.length,
                      onTap: () => _open('/commitments'),
                    ),
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

// the top: my avatar in my level's ring, «هلا ...», my level and weeks, points and pardon cards
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
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'مستواي',
          child: GestureDetector(
            onTap: onLevel,
            child: Container(
              width: 48,
              height: 48,
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
        const SizedBox(width: 14),
        Expanded(
          child: InkWell(
            onTap: onLevel,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'هلا' : 'هلا $name',
                    style: text.headlineSmall!.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (level != null)
                  Text(
                    weeks > 0 ? '${levelsAr[level] ?? level} · ${arabicDigits(weeks)} أسابيع متتالية' : (levelsAr[level] ?? level),
                    style: text.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
        if (stats != null) ...[
          ResourceChip(ResourceKind.points, (stats!['points'] ?? 0) as num, onTap: onLevel),
          const SizedBox(width: 6),
          ResourceChip(ResourceKind.pardon, (stats!['availableGraceDays'] ?? 0) as num, onTap: onLevel),
        ],
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'تعهّداتي',
          onPressed: onCommitments,
          icon: Icon(Icons.format_list_bulleted_rounded, color: c.inkMuted),
        ),
      ],
    );
  }
}

// the 7 days of this week (Sunday first): a blue bar for a day with a done task, today in ink
class _WeekStrip extends StatelessWidget {
  final Map<String, int> activity;

  const _WeekStrip({required this.activity});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sunday = today.subtract(Duration(days: today.weekday % 7));
    String key(DateTime d) => '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Builder(builder: (context) {
              final day = sunday.add(Duration(days: i));
              final isToday = day == today;
              final done = (activity[key(day)] ?? 0) > 0;
              final color = isToday ? (done ? c.accent : c.ink) : (done ? c.accent : c.line);
              return Column(
                children: [
                  AnimatedContainer(
                    duration: Motion.base,
                    height: 6,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.full)),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isToday ? 'اليوم' : weekDaysAr[i],
                      style: text.labelSmall!.copyWith(
                        fontSize: 11,
                        color: isToday ? c.ink : c.inkSubtle,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ],
    );
  }
}

// nothing left today: one icon, one line, one button
class _EmptyToday extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line;
  final String action;
  final VoidCallback onAction;

  const _EmptyToday({required this.icon, required this.title, required this.line, required this.action, required this.onAction});

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
            const SizedBox(height: Space.s4),
            AtButton(action, icon: const Icon(Icons.add_rounded, size: 20), onPressed: onAction),
          ],
        ),
      ),
    );
  }
}

// «خلّصتها اليوم ٢ · مؤجلة ١» → «تعهّداتي»
class _ElsewhereRow extends StatelessWidget {
  final int doneToday;
  final int postponed;
  final int weekDone;
  final VoidCallback onTap;

  const _ElsewhereRow({required this.doneToday, required this.postponed, required this.weekDone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final parts = [
      if (doneToday > 0) 'خلّصتها اليوم ${arabicDigits(doneToday)}',
      if (postponed > 0) 'مؤجلة ${arabicDigits(postponed)}',
      if (weekDone > 0) 'خلصت الأسبوع ${arabicDigits(weekDone)}',
    ];
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.task_alt_rounded, color: c.success),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parts.join(' · '), style: text.labelLarge),
                Text('تلقاها في تعهّداتي', style: text.labelSmall),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: c.inkSubtle),
        ],
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
    // the manual pardon card is for habits (goals use pardon cards by themselves); postponing fits any task with times left
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
