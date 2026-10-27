import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../proofs/activity_proof_entry.dart';
import '../proofs/proof_widgets.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitment_widgets.dart';
import 'commitments_api.dart';

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
    return {'tasks': tasks, 'stats': stats};
  }

  Future<void> _open(String location) async {
    await context.push(location);
    if (mounted) setState(() => _version++);
  }

  Future<void> _newCommitment() async {
    final location = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('عادة'),
              subtitle: const Text('شي يتكرر كل أسبوع بدون نهاية'),
              onTap: () => Navigator.pop(context, '/habit/add'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: const Text('هدف بخطة من الذكاء'),
              subtitle: const Text('شي له نهاية، الخطة تزيد أسبوع بأسبوع'),
              onTap: () => Navigator.pop(context, '/goal/new'),
            ),
            const SizedBox(height: Space.s2),
          ],
        ),
      ),
    );
    if (location != null && mounted) await _open(location);
  }

  // postpone inside this week: pick other days, only the reminders move
  Future<void> _postpone(JsonMap task, Future<void> Function() reload) async {
    final JsonMap week;
    try {
      week = await _api.currentWeek(task['commitmentId'] as int);
    } catch (error) {
      if (mounted) showError(context, error);
      return;
    }
    if (!mounted) return;
    final days = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PostponeSheet(
        title: '${task['title']}',
        required: (task['required'] ?? 0) as int,
        planned: ((week['plannedDays'] as List?) ?? const []).map((d) => '$d').toSet(),
      ),
    );
    if (days == null || !mounted) return;
    try {
      await _api.changeWeekPlan(task['weekId'] as int, days);
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
      showMessage(context, 'ما عندك يوم سماح متاح. كل ١٥٠ نقطة تعطيك يوم.');
      return;
    }
    final day = usable.first;
    final ok = await confirmDialog(
      context,
      title: 'تستخدم يوم سماح؟',
      message: 'ينحسب لـ "${task['title']}" مرة معذورة هالأسبوع، وإذا عليها عقوبة ما انقضت تنلغي. '
          'يوم واحد بس بالأسبوع.\n\nبنستخدم اللي ينتهي ${arabicDigits(day['expiresAt'])} '
          '(باقي عندك ${arabicDigits(usable.length)}).',
      confirm: 'استخدمه',
    );
    if (!ok || !mounted) return;
    try {
      await _api.useGraceDay(day['id'] as int, task['weekId'] as int);
      if (!mounted) return;
      showMessage(context, 'استخدمت يوم سماح.');
      await reload();
    } catch (error) {
      if (mounted) _showGraceOrPlanError(error);
    }
  }

  // the backend answers these two in English, the known ones are shown in Arabic
  void _showGraceOrPlanError(Object error) {
    const known = {
      'Only one grace day can be used in a week':
      'استخدمت يوم سماح هالأسبوع، يوم واحد بس بالأسبوع.',
      'This week does not need a grace day': 'هالأسبوع ما يحتاج يوم سماح.',
      'Grace day has expired': 'يوم السماح هذا انتهى.',
      'Grace day already used': 'يوم السماح هذا مستخدم.',
      'This week is not running': 'هالأسبوع خلص.',
      'You planned more days than the times of this week':
      'اخترت أيام أكثر من مرات هالأسبوع.',
    };

    final message = error is ApiException ? known[error.message] : null;

    message != null ? showMessage(context, message) : showError(context, error);
  }

  // Lucky Challenge card
  Widget _luckyChallengeCard() {
    return AppCard(
      onTap: () => context.push('/lucky-challenge'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.casino_outlined,
              color: context.colors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحدي الحظ 🎲',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'فاجئني بتحدي اليوم واكسب 20 نقطة!',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '3 فرص يوميًا',
                  style: TextStyle(
                    color: context.colors.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthState>().profile?['name'] ?? '';

    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('هلا $name'),
        actions: [
          IconButton(
            tooltip: 'إضافة نشاط',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/commitments/new'),
          ),
        ],
      ),
      body: AsyncView<List<dynamic>>(
        load: () async => await context.read<ApiClient>().get(
          '/api/v1/commitment-week/today',
        ) as List<dynamic>,
        builder: (context, tasks, reload) {
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyView(
                    message: 'ما عندك تعهّدات للحين. ابدأ بعادة وحدة.',
                    icon: Icons.flag_outlined,
                  ),
                  AtButton(
                    'إضافة نشاط',
                    expand: false,
                    onPressed: () => context.push('/commitments/new'),
                  ),
                  const SizedBox(height: Space.s3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s4),
                    child: _luckyChallengeCard(),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(Space.s4),
              itemCount: tasks.length + 1,
              separatorBuilder: (context, i) =>
              const SizedBox(height: Space.s3),
              itemBuilder: (context, i) {
                if (i == tasks.length) {
                  return _luckyChallengeCard();
                }
                final t = tasks[i] as Map;

                return AppCard(
                  onTap: () async {
                    await openActivityProof(
                      context,
                      Map<String, dynamic>.from(t),
                    );

                    if (context.mounted) {
                      await reload();
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: ActivityHeading(
                                  title: '${t['title']}',
                                  goalTitle: t['goalTitle'] as String?,
                                  taskTitle: t['taskTitle'] as String?,
                                  style: text.headlineSmall)),
                          StatusBadge.track(t['trackStatus'] as String?),
                        ],
                      ),
                      const SizedBox(height: Space.s1),
                      Text(
                        'باقي ${arabicDigits(t['remaining'])} من ${arabicDigits(t['required'])} هالأسبوع',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: Space.s3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Space.s3, vertical: Space.s2),
                        decoration: BoxDecoration(
                            color: context.colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(Radii.md)),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text('لكل مرة تفوتك',
                                    style: text.bodySmall)),
                            RiyalAmount(t['amountPerTime'] as num?),
                          ],
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  // "٢ لازم اليوم" when some must be done today
  String _todayLine(List<JsonMap> tasks) {
    final must = tasks.where((t) => t['trackStatus'] == 'MUST_TODAY').length;
    final planned = tasks.where((t) => t['plannedToday'] == true && t['trackStatus'] != 'SETTLED').length;
    if (must > 0) return '${arabicDigits(must)} لازم اليوم';
    if (planned > 0) return '${arabicDigits(planned)} مخطط لها اليوم';
    return '';
  }
}

class _StatsStrip extends StatelessWidget {
  final JsonMap stats;
  final VoidCallback onTap;

  const _StatsStrip({required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget item(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: text.titleMedium),
              Text(label, style: text.labelSmall),
            ],
          ),
        );
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          item(levelsAr[stats['level']] ?? '${stats['level'] ?? '-'}', 'المستوى'),
          item(arabicDigits(stats['consecutiveWeeks'] ?? 0), 'أسابيع متتالية'),
          item(arabicDigits(stats['points'] ?? 0), 'نقطة'),
          item(arabicDigits(stats['availableGraceDays'] ?? 0), 'أيام سماح'),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final JsonMap task;
  final VoidCallback onTap;
  final VoidCallback onPostpone;
  final VoidCallback onGraceDay;

  const _TaskCard({required this.task, required this.onTap, required this.onPostpone, required this.onGraceDay});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = task;
    final needed = (t['required'] ?? 0) as int;
    final completed = (t['completed'] ?? 0) as int;
    final excused = (t['excused'] ?? 0) as int;
    // postponing and the manual grace day are for habits only (goals plan every task, and use grace days by themselves)
    final habitRunning = t['type'] == 'HABIT' && t['trackStatus'] != 'SETTLED';
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${t['title']}', style: text.headlineSmall)),
              StatusBadge.track(t['trackStatus'] as String?),
            ],
          ),
          const SizedBox(height: Space.s1),
          Text(
            [
              'باقي ${arabicDigits(t['remaining'])} من ${arabicDigits(needed)} هالأسبوع',
              if (t['daysLeft'] != null) '${arabicDigits(t['daysLeft'])} أيام باقية',
              if (t['type'] == 'GOAL') 'هدف',
            ].join(' · '),
            style: text.bodySmall,
          ),
          if (t['plannedToday'] == true && t['trackStatus'] != 'SETTLED')
            Padding(
              padding: const EdgeInsets.only(top: Space.s1),
              child: Text('اليوم يومك 💪 سوّه أو أجّل', style: text.labelMedium!.copyWith(color: context.colors.primary)),
            ),
          const SizedBox(height: Space.s3),
          // one box for every time this week: done / excused / left
          Row(
            children: List.generate(needed, (i) {
              final c = context.colors;
              final color = i < completed
                  ? c.shadda
                  : i < completed + excused
                      ? c.info
                      : c.surfaceSunken;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsetsDirectional.only(end: Space.s1),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.full)),
                ),
              );
            }),
          ),
          const SizedBox(height: Space.s3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
            decoration: BoxDecoration(color: context.colors.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(
              children: [
                Expanded(child: Text('لكل مرة تفوتك', style: text.bodySmall)),
                RiyalAmount(t['amountPerTime'] as num?),
              ],
            ),
          ),
          if (habitRunning) ...[
            const SizedBox(height: Space.s2),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.event_repeat_rounded, size: 18),
                  label: const Text('أجّل'),
                  onPressed: onPostpone,
                ),
                if ((t['remaining'] ?? 0) as int > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.beach_access_rounded, size: 18),
                    label: const Text('يوم سماح'),
                    onPressed: onGraceDay,
                  ),
              ],
            ),
          ],
        ],
      ),
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
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('أجّل "${widget.title}"', style: text.titleMedium),
            const SizedBox(height: Space.s1),
            Text(
              'اختار الأيام اللي تبي نذكّرك فيها هالأسبوع (${arabicDigits(widget.required)} أيام بالكثير). '
              'التأجيل يغيّر التذكير بس، والمرات المطلوبة ما تتغير.',
              style: text.bodySmall,
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
            FilledButton(
              onPressed: () => Navigator.pop(context, _days),
              child: const Text('احفظ أيام هالأسبوع'),
            ),
          ],
        ),
      ),
    );
  }
}
