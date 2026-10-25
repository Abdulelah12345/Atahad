import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitment_widgets.dart';
import 'commitments_api.dart';

// OWNER: Turki - one goal: its progress and the tasks of every week
class GoalScreen extends StatefulWidget {
  final int id;

  const GoalScreen({super.key, required this.id});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  late final _api = CommitmentsApi(context.read<ApiClient>());
  int _version = 0; // a new key reloads the AsyncView

  Future<JsonMap> _load() async {
    final values = await Future.wait([_api.progress(widget.id), _api.goalTasks(widget.id)]);
    return {'progress': values[0], 'tasks': values[1]};
  }

  Future<void> _withdraw() async {
    final ok = await confirmDialog(context,
        title: 'الانسحاب من الهدف', message: withdrawWarning, confirm: 'انسحب', danger: true);
    if (!ok || !mounted) return;
    try {
      final message = await _api.withdraw(widget.id);
      if (!mounted) return;
      await context.read<AuthState>().refreshLock();
      if (!mounted) return;
      showMessage(context, message);
      setState(() => _version++);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'حذف الهدف', message: 'الحذف بس إذا ما صار فيه شي. متأكد؟', confirm: 'احذف', danger: true);
    if (!ok || !mounted) return;
    try {
      await _api.deleteGoal(widget.id);
      if (!mounted) return;
      showMessage(context, 'انحذف الهدف.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الهدف'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'withdraw' ? _withdraw() : _delete(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'withdraw', child: Text('انسحب')),
              PopupMenuItem(value: 'delete', child: Text('احذف')),
            ],
          ),
        ],
      ),
      body: AsyncView<JsonMap>(
        key: ValueKey(_version),
        load: _load,
        builder: (context, data, reload) {
          final p = data['progress'] as JsonMap;
          final tasks = data['tasks'] as List<JsonMap>;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(Space.s4),
              children: [
                _ProgressCard(progress: p),
                ..._weeks(context, tasks, (p['currentWeek'] ?? 0) as int),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _weeks(BuildContext context, List<JsonMap> tasks, int currentWeek) {
    final text = Theme.of(context).textTheme;
    final byWeek = <int, List<JsonMap>>{};
    for (final t in tasks) {
      byWeek.putIfAbsent((t['weekNumber'] ?? 0) as int, () => []).add(t);
    }
    final weeks = byWeek.keys.toList()..sort();
    return [
      for (final week in weeks) ...[
        SectionTitle(
          'الأسبوع ${arabicDigits(week)}',
          trailing: week == currentWeek
              ? const StatusBadge('هالأسبوع', kind: BadgeKind.info)
              : week < currentWeek
                  ? const StatusBadge('خلص')
                  : null,
        ),
        for (final t in byWeek[week]!)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s2),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('${t['title']}', style: text.titleSmall)),
                      if (week == currentWeek && t['trackStatus'] != null) StatusBadge.track(t['trackStatus'] as String?),
                    ],
                  ),
                  const SizedBox(height: Space.s1),
                  InfoRow(
                    'سوّيت ${arabicDigits(t['completedCount'] ?? 0)} من ${arabicDigits(t['timesPerWeek'])}'
                    '${(t['excusedCount'] ?? 0) > 0 ? ' (معذور ${arabicDigits(t['excusedCount'])})' : ''}',
                    RiyalAmount(t['amountPerTime'] as num?, style: text.titleSmall),
                  ),
                ],
              ),
            ),
          ),
      ],
    ];
  }
}

class _ProgressCard extends StatelessWidget {
  final JsonMap progress;

  const _ProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final p = progress;
    final percent = ((p['percent'] ?? 0) as num).toDouble().clamp(0, 100);
    final currentWeek = (p['currentWeek'] ?? 0) as int;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${p['title'] ?? ''}', style: text.headlineSmall)),
              commitmentStatusBadge(p['status'] as String?),
            ],
          ),
          const SizedBox(height: Space.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${arabicDigits(percent.round())}٪', style: text.titleLarge!.copyWith(color: c.primary)),
              const SizedBox(width: Space.s2),
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s2),
                child: Text('من المطلوب لين الحين', style: text.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: Space.s2),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: c.surfaceSunken,
              color: c.shadda,
            ),
          ),
          const SizedBox(height: Space.s3),
          InfoRow('الأسبوع', Text(currentWeek == 0 ? 'ما بدأ' : '${arabicDigits(currentWeek)} من ${arabicDigits(p['totalWeeks'])}', style: text.labelLarge)),
          InfoRow('باقي', Text('${arabicDigits(p['weeksLeft'] ?? 0)} أسابيع', style: text.labelLarge)),
          InfoRow('أسابيع كاملة', Text(arabicDigits(p['fullWeeks'] ?? 0), style: text.labelLarge)),
          InfoRow('المرات', Text('${arabicDigits(p['totalCompleted'] ?? 0)} من ${arabicDigits(p['totalRequired'] ?? 0)}', style: text.labelLarge)),
          if (p['endDate'] != null) InfoRow('ينتهي', Text(arabicDigits(p['endDate']), style: text.labelLarge)),
        ],
      ),
    );
  }
}
