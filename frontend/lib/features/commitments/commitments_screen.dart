import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitment_widgets.dart';
import 'commitments_api.dart';

// OWNER: Turki - my habits and my goals: add, edit, withdraw, delete
class CommitmentsScreen extends StatefulWidget {
  const CommitmentsScreen({super.key});

  @override
  State<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends State<CommitmentsScreen> {
  late final _api = CommitmentsApi(context.read<ApiClient>());
  int _version = 0; // a new key reloads the lists

  void _reload() => setState(() => _version++);

  // the habits, and which of them got a proof today (from the home list) for the ✓ on today
  Set<int> _doneToday = {};

  Future<List<JsonMap>> _loadHabits() async {
    final habits = await _api.habits();
    try {
      final today = await _api.today();
      _doneToday = {
        for (final t in today)
          if (t['type'] == 'HABIT' && t['doneToday'] == true) (t['commitmentId'] as num).toInt(),
      };
    } catch (_) {} // the list works without it
    return habits;
  }

  Future<void> _open(String location, {Object? extra}) async {
    final changed = await context.push<bool>(location, extra: extra);
    if (changed == true && mounted) _reload();
  }

  Future<void> _withdraw(JsonMap commitment) async {
    final ok = await confirmDialog(
      context,
      title: 'الانسحاب من "${commitment['title']}"',
      message: withdrawWarning,
      confirm: 'انسحب',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      final message = await _api.withdraw(commitment['id'] as int);
      if (!mounted) return;
      // the withdrawal can lock the app, the router then moves to /lock
      await context.read<AuthState>().refreshLock();
      if (!mounted) return;
      showMessage(context, message);
      _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _delete(JsonMap commitment, bool isHabit) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف "${commitment['title']}"',
      message: 'ينحذف كامل وكأنه ما كان. الحذف متاح أول ساعة بس وقبل أي إثبات، بعدها تقدر تنسحب. متأكد؟',
      confirm: 'احذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      final id = commitment['id'] as int;
      if (isHabit) {
        await _api.deleteHabit(id);
      } else {
        await _api.deleteGoal(id);
      }
      if (!mounted) return;
      showMessage(context, 'انحذف.');
      _reload();
    } catch (error) {
      if (mounted) showCommitmentError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تعهّداتي'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'العادات'),
              Tab(text: 'الأهداف'),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            icon: const Icon(Icons.add_rounded),
            label: const Text('جديد'),
            onPressed: () {
              final goals = DefaultTabController.of(context).index == 1;
              _open(goals ? '/goal/new' : '/habit/add');
            },
          ),
        ),
        body: TabBarView(
          children: [
            AsyncView<List<JsonMap>>(
              key: ValueKey('habits$_version'),
              load: _loadHabits,
              builder: (context, habits, reload) => _list(
                context,
                habits,
                reload,
                empty: 'ما عندك عادات. ابدأ بعادة وحدة.',
                item: (h) => _habitCard(context, h),
              ),
            ),
            AsyncView<List<JsonMap>>(
              key: ValueKey('goals$_version'),
              load: _api.goals,
              builder: (context, goals, reload) => _list(
                context,
                goals,
                reload,
                empty: 'ما عندك أهداف. خل الذكاء يسوي لك خطة.',
                item: (g) => _goalCard(context, g),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<JsonMap> items,
    Future<void> Function() reload, {
    required String empty,
    required Widget Function(JsonMap) item,
  }) {
    if (items.isEmpty)
      return EmptyView(message: empty, icon: Icons.flag_outlined);
    // active first
    final sorted = [...items]
      ..sort(
        (a, b) => (a['status'] == 'ACTIVE' ? 0 : 1).compareTo(
          b['status'] == 'ACTIVE' ? 0 : 1,
        ),
      );
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          Space.s4,
          Space.s4,
          Space.s4,
          Space.s16 + Space.s4,
        ),
        itemCount: sorted.length,
        separatorBuilder: (context, i) => const SizedBox(height: Space.s6),
        itemBuilder: (context, i) => item(sorted[i]),
      ),
    );
  }

  Widget _menu(JsonMap c, bool isHabit) {
    final active = c['status'] == 'ACTIVE';
    final minutesLeft = editMinutesLeft(c);
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit') _open('/habit/edit', extra: c);
        if (v == 'withdraw') _withdraw(c);
        if (v == 'delete') _delete(c, isHabit);
      },
      itemBuilder: (context) => [
        if (isHabit && active)
          const PopupMenuItem(value: 'edit', child: Text('عدّل')),
        if (active)
          const PopupMenuItem(value: 'withdraw', child: Text('انسحب')),
        // deleting is for the first hour after creating it, after that withdraw
        if (minutesLeft != 0)
          PopupMenuItem(
            value: 'delete',
            child: Text(minutesLeft == null ? 'احذف' : 'احذف (باقي ${arabicDigits(minutesLeft)} دقيقة)'),
          ),
      ],
    );
  }

  Widget _habitCard(BuildContext context, JsonMap h) {
    final text = Theme.of(context).textTheme;
    final days =
        ((h['plannedDays'] as List?) ?? const [])
            .map((d) => weekDays.indexOf('$d'))
            .where((i) => i >= 0)
            .toList()
          ..sort();
    final pendingTimes = h['pendingTimesPerWeek'];
    final pendingAmount = h['pendingBaseAmount'];
    final active = h['status'] == 'ACTIVE';
    // the planned days of the week (reminders only) and today, Sunday first
    final today = DateTime.now().weekday % 7;
    final week = List.generate(
      7,
      (i) => i == today
          ? (_doneToday.contains((h['id'] as num?)?.toInt()) ? DayState.done : DayState.today)
          : days.contains(i)
              ? DayState.planned
              : DayState.empty,
    );
    return CommitmentCard(
      title: '${h['title']}',
      details: [
        '${arabicDigits(h['timesPerWeek'])} مرات بالأسبوع · ${h['proofMethod'] == 'STEPS' ? 'مجموع خطوات اليوم' : proofMethodsAr[h['proofMethod']] ?? h['proofMethod']}',
        if (h['proofMethod'] == 'STEPS') 'الهدف: ${arabicDigits(h['targetSteps'])} خطوة في اليوم',
      ],
      badge: commitmentStatusBadge(h['status'] as String?),
      menu: _menu(h, true),
      week: active ? week : null,
      amount: h['baseAmount'] as num?,
      extra: [
        if (pendingTimes != null || pendingAmount != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: Text(
              'من الأسبوع الجاي: '
              '${pendingTimes != null ? '${arabicDigits(pendingTimes)} مرات ' : ''}'
              '${pendingAmount != null ? '${money(pendingAmount as num)} للمرة' : ''}',
              style: text.labelSmall,
            ),
          ),
      ],
      action: h['proofMethod'] == 'STEPS' && active
          ? AtButton(
              'تابع خطواتك',
              kind: AtButtonKind.outline,
              icon: const Icon(Icons.directions_walk_rounded),
              onPressed: () async {
                try {
                  final week = await _api.currentWeek((h['id'] as num).toInt());
                  if (context.mounted)
                    await context.push(
                      '/walking/${week['id']}',
                      extra: {'title': h['title'], 'commitmentId': h['id']},
                    );
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            )
          : null,
    );
  }

  Widget _goalCard(BuildContext context, JsonMap g) {
    return CommitmentCard(
      title: '${g['title']}',
      details: [
        '${arabicDigits(g['totalWeeks'])} أسابيع · ${proofMethodsAr[g['proofMethod']] ?? g['proofMethod']}',
        if (g['endDate'] != null) 'ينتهي ${arabicDigits(g['endDate'])}',
      ],
      badge: commitmentStatusBadge(g['status'] as String?),
      menu: _menu(g, false),
      onTap: () => _open('/goal/${g['id']}'),
      action: AtButton('شوف التقدم', kind: AtButtonKind.outline, onPressed: () => _open('/goal/${g['id']}')),
    );
  }
}
