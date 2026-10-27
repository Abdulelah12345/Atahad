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
            itemBuilder: (context) => [
              menuItem(context, 'withdraw', Icons.directions_walk_rounded, 'انسحب'),
              menuItem(context, 'delete', Icons.delete_outline_rounded, 'احذف', danger: true),
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
                _JourneyHeader(progress: p),
                const SizedBox(height: Space.s4),
                ..._weeks(context, tasks, (p['currentWeek'] ?? 0) as int),
              ],
            ),
          );
        },
      ),
    );
  }

  // the journey (design: GoalJourney): one stage per week on a line, done ones checked, this week raised
  List<Widget> _weeks(BuildContext context, List<JsonMap> tasks, int currentWeek) {
    final byWeek = <int, List<JsonMap>>{};
    for (final t in tasks) {
      byWeek.putIfAbsent((t['weekNumber'] ?? 0) as int, () => []).add(t);
    }
    final weeks = byWeek.keys.toList()..sort();
    return [
      for (final (i, week) in weeks.indexed)
        _Stage(
          week: week,
          tasks: byWeek[week]!,
          state: week < currentWeek ? _StageState.done : (week == currentWeek ? _StageState.now : _StageState.later),
          last: i == weeks.length - 1,
        ),
    ];
  }
}

enum _StageState { done, now, later }

class _JourneyHeader extends StatelessWidget {
  final JsonMap progress;

  const _JourneyHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final p = progress;
    final percent = ((p['percent'] ?? 0) as num).toDouble().clamp(0, 100);
    final currentWeek = (p['currentWeek'] ?? 0) as int;
    final total = (p['totalWeeks'] ?? 0) as int;
    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
        boxShadow: [BoxShadow(color: c.line, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p['endDate'] != null)
                      Row(children: [
                        Icon(Icons.flag_rounded, size: 15, color: c.accent),
                        const SizedBox(width: 4),
                        Text('ينتهي ${arabicDigits(p['endDate'])}', style: text.labelSmall),
                      ]),
                    const SizedBox(height: 2),
                    Text('${p['title'] ?? ''}', style: text.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    commitmentStatusBadge(p['status'] as String?),
                  ],
                ),
              ),
              const SizedBox(width: Space.s3),
              // the ring: this week out of all of them
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: percent / 100),
                      duration: Motion.reward,
                      curve: Motion.easeOut,
                      builder: (context, v, _) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: c.surfaceSunken,
                        valueColor: AlwaysStoppedAnimation(c.accent),
                      ),
                    ),
                    Center(
                      child: Text(
                        currentWeek == 0 ? '٠/${arabicDigits(total)}' : '${arabicDigits(currentWeek)}/${arabicDigits(total)}',
                        style: text.titleSmall!.copyWith(fontWeight: FontWeight.w800),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s3),
          Row(
            children: [
              _Mini(icon: Icons.task_alt_rounded, value: '${arabicDigits(p['totalCompleted'] ?? 0)}/${arabicDigits(p['totalRequired'] ?? 0)}', label: 'مرة'),
              _Mini(icon: Icons.workspace_premium_rounded, value: arabicDigits(p['fullWeeks'] ?? 0), label: 'أسبوع كامل'),
              _Mini(icon: Icons.hourglass_bottom_rounded, value: arabicDigits(p['weeksLeft'] ?? 0), label: 'أسابيع باقية'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Mini({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c.inkSubtle),
          const SizedBox(width: 4),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$value ', style: text.labelLarge!.copyWith(fontWeight: FontWeight.w800)),
                TextSpan(text: label, style: text.labelSmall),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// one stage: a node on the line, and the card of its task(s)
class _Stage extends StatelessWidget {
  final int week;
  final List<JsonMap> tasks;
  final _StageState state;
  final bool last;

  const _Stage({required this.week, required this.tasks, required this.state, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final now = state == _StageState.now;
    final done = state == _StageState.done;
    final node = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? c.accent : (now ? c.surface : c.surfaceSunken),
        border: now ? Border.all(color: c.urgent, width: 3) : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
          : state == _StageState.later
              ? Icon(Icons.lock_outline_rounded, size: 16, color: c.inkSubtle)
              : Text(arabicDigits(week), style: text.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: c.urgentText)),
    );
    final status = switch (state) {
      _StageState.done => 'خلصت',
      _StageState.now => 'هالأسبوع',
      _StageState.later => 'جاية',
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                node,
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(color: done ? c.accent : c.line, borderRadius: BorderRadius.circular(Radii.full)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.s3),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: now ? c.surface : c.surface.withValues(alpha: done ? 1 : 0.7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: now ? c.urgent : c.line, width: now ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المرحلة ${arabicDigits(week)} · $status',
                        style: text.labelSmall!.copyWith(color: now ? c.urgentText : null, fontWeight: now ? FontWeight.w700 : null)),
                    for (final t in tasks) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text('${t['title']} × ${arabicDigits(t['timesPerWeek'])}',
                                style: text.titleSmall!.copyWith(color: state == _StageState.later ? c.inkMuted : c.ink)),
                          ),
                          RiyalAmount(t['amountPerTime'] as num?, style: text.labelMedium!.copyWith(color: c.goldText)),
                        ],
                      ),
                      if (now) ...[
                        const SizedBox(height: 8),
                        Pips(
                          done: ((t['completedCount'] ?? 0) as int) + ((t['excusedCount'] ?? 0) as int),
                          total: (t['timesPerWeek'] ?? 0) as int,
                          width: 0,
                          height: 8,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
