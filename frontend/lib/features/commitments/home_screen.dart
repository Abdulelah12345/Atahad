import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../proofs/activity_proof_entry.dart';
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

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthState>().profile?['name'] ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text('هلا $name'),
        actions: [
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
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s16 + Space.s4),
              children: [
                if (stats != null) _StatsStrip(stats: stats, onTap: () => _open('/stats')),
                SectionTitle('هالأسبوع', trailing: tasks.isEmpty ? null : Text(_todayLine(tasks), style: Theme.of(context).textTheme.labelSmall)),
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.s8),
                    child: EmptyView(message: 'ما عندك تعهّدات للحين. ابدأ بعادة وحدة.', icon: Icons.flag_outlined),
                  )
                else
                  ...tasks.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: Space.s3),
                        child: _TaskCard(
                          task: t,
                          onTap: () async {
                            await openActivityProof(context, Map<String, dynamic>.from(t));
                            if (context.mounted) await reload();
                          },
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

  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = task;
    final needed = (t['required'] ?? 0) as int;
    final completed = (t['completed'] ?? 0) as int;
    final excused = (t['excused'] ?? 0) as int;
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
        ],
      ),
    );
  }
}
