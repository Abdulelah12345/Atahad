import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../proofs/activity_proof_entry.dart';
import '../proofs/proof_widgets.dart';
import '../proofs/request_forms.dart';
import '../../core/auth/auth_state.dart';
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
          IconButton(tooltip: 'تعهّداتي', icon: const Icon(Icons.list_alt_rounded), onPressed: () => _open('/commitments')),
          IconButton(tooltip: 'مستواي ونقاطي', icon: const Icon(Icons.insights_rounded), onPressed: () => _open('/stats')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('تعهّد جديد'),
        onPressed: _newCommitment,
      ),
      body: AsyncView<JsonMap>(
        key: ValueKey(_version),
        load: _load,
        builder: (context, data, reload) {
          final tasks = data['tasks'] as List<JsonMap>;
          final stats = data['stats'] as JsonMap?;
          // by the state, never by the creation date: what to do now first
          final urgent = tasks.where((t) => questStateOf(t['trackStatus'] as String?) == QuestState.urgent).toList();
          final missed = tasks.where((t) => questStateOf(t['trackStatus'] as String?) == QuestState.missed).toList();
          final fine = tasks.where((t) => questStateOf(t['trackStatus'] as String?) == QuestState.safe).toList();
          Widget quest(JsonMap t) => Padding(
                padding: const EdgeInsets.only(bottom: Space.s3),
                child: _Quest(
                  task: t,
                  onProve: () async {
                    await openActivityProof(context, Map<String, dynamic>.from(t));
                    if (context.mounted) await reload();
                  },
                  onPostpone: () => _postpone(t, reload),
                  onPardon: () => _useGraceDay(t, reload),
                  onExcuse: () => _excuse(t, reload),
                ),
              );
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, Space.s16 + Space.s4),
              children: [
                if (stats != null) ...[
                  _Resources(stats: stats, onTap: () => _open('/stats')),
                  const SizedBox(height: Space.s3),
                  // the next reward is always in sight
                  RewardProgress(
                    label: 'بطاقة العفو الجاية',
                    current: 150 - ((stats['pointsToGraceDay'] ?? 150) as int).clamp(0, 150),
                    target: 150,
                    onTap: () => _open('/stats'),
                  ),
                ],
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.s8),
                    child: EmptyView(message: 'ما عندك تعهّدات للحين. ابدأ بعادة وحدة.', icon: Icons.flag_outlined),
                  ),
                if (urgent.isNotEmpty) ...[_SectionHead('لازم اليوم', urgent.length), ...urgent.map(quest)],
                if (missed.isNotEmpty) ...[_SectionHead('يحتاج قرار', missed.length), ...missed.map(quest)],
                if (fine.isNotEmpty) ...[_SectionHead('ماشية تمام', fine.length), ...fine.map(quest)],
              ],
            ),
          );
        },
      ),
    );
  }
}

// «لازم اليوم ٢»
class _SectionHead extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHead(this.title, this.count);

  @override
  Widget build(BuildContext context) {
    return SectionTitle(title, trailing: Text(arabicDigits(count), style: Theme.of(context).textTheme.labelSmall));
  }
}

// points, pardon cards and donations, a tap opens «مستواي»
class _Resources extends StatelessWidget {
  final JsonMap stats;
  final VoidCallback onTap;

  const _Resources({required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LevelBadge(stats['level'] as String?, size: 30, showName: false),
        const SizedBox(width: Space.s3),
        Expanded(
          child: Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              ResourceChip(ResourceKind.points, (stats['points'] ?? 0) as num, onTap: onTap),
              ResourceChip(ResourceKind.pardon, (stats['availableGraceDays'] ?? 0) as num, onTap: onTap),
              ResourceChip(ResourceKind.donated, (stats['totalDonated'] ?? 0) as num, onTap: onTap),
            ],
          ),
        ),
      ],
    );
  }
}

class _Quest extends StatelessWidget {
  final JsonMap task;
  final VoidCallback onProve;
  final VoidCallback onPostpone;
  final VoidCallback onPardon;
  final VoidCallback onExcuse;

  const _Quest({required this.task, required this.onProve, required this.onPostpone, required this.onPardon, required this.onExcuse});

  @override
  Widget build(BuildContext context) {
    final t = task;
    final needed = (t['required'] ?? 0) as int;
    final completed = (t['completed'] ?? 0) as int;
    final excused = (t['excused'] ?? 0) as int;
    final state = questStateOf(t['trackStatus'] as String?);
    final settled = t['trackStatus'] == 'SETTLED';
    // postponing and the manual pardon card are for habits only (goals plan every task, and use pardon cards by themselves)
    final habitRunning = t['type'] == 'HABIT' && !settled;
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
      onPardon: habitRunning && (t['remaining'] ?? 0) as int > 0 ? onPardon : null,
      onExcuse: onExcuse,
      onPostpone: habitRunning ? onPostpone : null,
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
            AtButton('احفظ أيام هالأسبوع', onPressed: () => Navigator.pop(context, _days)),
          ],
        ),
      ),
    );
  }
}
