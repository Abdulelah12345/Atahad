import 'package:flutter/material.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_ui.dart';
import 'group_widgets.dart';

// the end of every week (Sunday 00:00), design: GroupWeek: the titles of the week and the summary written by the AI
class WeekTab extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final String groupName;
  final List<Map<String, dynamic>> members;
  final int? me;

  const WeekTab({super.key, required this.api, required this.groupId, required this.groupName, required this.members, this.me});

  @override
  State<WeekTab> createState() => _WeekTabState();
}

class _WeekData {
  final List<Map<String, dynamic>> titles; // the newest week
  final Map<String, dynamic>? latest; // the newest summary
  final List<Map<String, dynamic>> settlements; // all the weeks, newest first
  final Map<String, List<Map<String, dynamic>>> history; // weekStart -> its titles with names

  _WeekData(this.titles, this.latest, this.settlements, this.history);
}

class _WeekTabState extends State<WeekTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<_WeekData> _load() async {
    final api = widget.api;
    final results = await Future.wait<Object?>([
      api.latestTitles(widget.groupId),
      api.latestSettlement(widget.groupId),
      api.settlements(widget.groupId),
      api.titlesHistory(widget.groupId),
    ]);
    final settlements = (results[2] as List<Map<String, dynamic>>)..sort((a, b) => '${b['weekStart']}'.compareTo('${a['weekStart']}'));
    final history = <String, List<Map<String, dynamic>>>{};
    for (final t in results[3] as List<Map<String, dynamic>>) {
      history.putIfAbsent('${t['weekStart']}', () => []).add(t);
    }
    return _WeekData(results[0] as List<Map<String, dynamic>>, results[1] as Map<String, dynamic>?, settlements, history);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    return AsyncView<_WeekData>(
      load: () => inArabic(_load()),
      builder: (context, data, reload) {
        if (data.titles.isEmpty && data.settlements.isEmpty) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(children: [
              const SizedBox(height: 120),
              EmptyView(message: 'ملخص نهاية كل أسبوع لمجموعة ${widget.groupName}: الألقاب وكلمة الذكاء.', icon: Icons.emoji_events_outlined),
            ]),
          );
        }
        final latest = data.latest ?? (data.settlements.isEmpty ? null : data.settlements.first);
        final weekStart = data.titles.isNotEmpty ? data.titles.first['weekStart'] : latest?['weekStart'];
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s4, 14, Space.s4, Space.s8),
            children: [
              _WeekHero(
                team: teamColor(widget.groupId),
                groupName: widget.groupName,
                weekStart: weekStart,
                titlesCount: data.titles.length,
              ),
              if (data.titles.isNotEmpty) ...[
                const GroupSection('ألقاب الأسبوع'),
                LayoutBuilder(
                  builder: (context, box) {
                    final width = (box.maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, t) in data.titles.indexed)
                          SizedBox(width: width, child: _TitleCard(title: t, index: i, isMe: t['memberId'] == widget.me)),
                      ],
                    );
                  },
                ),
              ],
              if (latest != null) ...[
                const SizedBox(height: 14),
                RaisedCard(
                  radius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_awesome_rounded, size: 16, color: c.pardon),
                        const SizedBox(width: 6),
                        Text('ملخص الذكاء', style: text.labelSmall),
                      ]),
                      const SizedBox(height: 6),
                      Text('${latest['settlementText'] ?? ''}', style: text.bodyMedium!.copyWith(height: 1.75)),
                    ],
                  ),
                ),
              ],
              if (data.settlements.length > 1) ...[
                const GroupSection('سجل الأسابيع', note: 'الألقاب وكلمة الذكاء'),
                for (final (i, s) in data.settlements.where((s) => !identical(s, latest) && s['id'] != latest?['id']).indexed) ...[
                  Appear(index: i, child: _OldWeek(settlement: s, titles: data.history['${s['weekStart']}'] ?? const [], me: widget.me)),
                  const SizedBox(height: Space.s2),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

// the team colored top with a little confetti
class _WeekHero extends StatelessWidget {
  final Color team;
  final String groupName;
  final Object? weekStart;
  final int titlesCount;

  const _WeekHero({required this.team, required this.groupName, required this.weekStart, required this.titlesCount});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const soft = Color(0xE6FFFFFF); // white text on the team colors (90%)
    // the confetti breathes a little (a celebration screen)
    Widget bit(double w, double h, Color color, double angle) => Pulse(
          scale: 1.3,
          period: Duration(milliseconds: 1100 + (w * 23).round()),
          child: Transform.rotate(
            angle: angle,
            child: Container(width: w, height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.full))),
          ),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: team, borderRadius: BorderRadius.circular(28)),
      child: Stack(
        children: [
          PositionedDirectional(top: 18, start: 26, child: bit(10, 10, const Color(0xFFF1DCA6), 0)),
          PositionedDirectional(top: 46, end: 30, child: bit(36, 10, const Color(0xFF8FB4FF), 0.42)),
          PositionedDirectional(bottom: 18, start: 56, child: bit(26, 9, const Color(0xFFF57C1F), -0.31)),
          PositionedDirectional(bottom: 30, end: 70, child: bit(8, 8, Colors.white70, 0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, 22, Space.s4, 26),
            child: Center(
              child: Column(
                children: [
                  Text(weekStart == null ? groupName : '$groupName · أسبوع ${dayAr(weekStart)}', style: text.labelMedium!.copyWith(color: soft, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text('ملخص الأسبوع', style: text.headlineMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(titlesCount == 0 ? 'كل أحد يطلع ملخص الأسبوع اللي راح' : '${arabicDigits(titlesCount)} ألقاب توزّعت هالأسبوع',
                      style: text.bodyMedium!.copyWith(color: soft)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// one title: its colored tile drops in (one after another)
class _TitleCard extends StatelessWidget {
  final Map<String, dynamic> title;
  final int index;
  final bool isMe;

  const _TitleCard({required this.title, required this.index, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final code = '${title['title'] ?? ''}';
    final card = Tooltip(
      message: titlesHint[code] ?? '',
      child: RaisedCard(
        radius: 18,
        highlight: isMe ? c.primary : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            TitleTile(code),
            const SizedBox(height: 6),
            Text(titlesAr[code] ?? code, style: text.labelMedium!.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              isMe ? 'أنت' : '${title['name'] ?? ''}',
              style: text.labelSmall!.copyWith(color: isMe ? c.primary : null, fontWeight: isMe ? FontWeight.w700 : null),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
    if (reduceMotion(context)) return card;
    // a drop with a little bounce, 100ms after the one before it
    final delay = (index * 100).clamp(0, 800);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Interval(delay / (500 + delay), 1, curve: Motion.easePop),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1).toDouble(),
        child: Transform.translate(offset: Offset(0, (1 - t) * -24), child: child),
      ),
      child: card,
    );
  }
}

class _OldWeek extends StatefulWidget {
  final Map<String, dynamic> settlement;
  final List<Map<String, dynamic>> titles;
  final int? me;

  const _OldWeek({required this.settlement, required this.titles, required this.me});

  @override
  State<_OldWeek> createState() => _OldWeekState();
}

class _OldWeekState extends State<_OldWeek> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final summary = '${widget.settlement['settlementText'] ?? ''}';
    return RaisedCard(
      onTap: () => setState(() => _open = !_open),
      child: AnimatedSize(
        duration: Motion.base,
        curve: Motion.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('أسبوع ${dayAr(widget.settlement['weekStart'])}', style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700))),
                for (final t in widget.titles.take(4))
                  Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: TitleTile('${t['title']}', size: 24)),
                const SizedBox(width: 4),
                AnimatedRotation(turns: _open ? 0.5 : 0, duration: Motion.base, child: Icon(Icons.expand_more_rounded, color: c.inkSubtle)),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: Space.s2),
              for (final t in widget.titles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      TitleTile('${t['title']}', size: 28),
                      const SizedBox(width: Space.s2),
                      Text(titlesAr['${t['title']}'] ?? '${t['title']}', style: text.labelMedium!.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(t['memberId'] == widget.me ? 'أنت' : '${t['name'] ?? ''}',
                          style: text.labelMedium!.copyWith(color: t['memberId'] == widget.me ? c.primary : c.inkMuted)),
                    ],
                  ),
                ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(summary, style: text.bodySmall!.copyWith(height: 1.7)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
