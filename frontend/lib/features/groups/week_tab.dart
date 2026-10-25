import 'package:flutter/material.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/widgets/widgets.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_widgets.dart';

// the end of every week (Sunday 00:00): the titles of the week and the settlement written by the AI
class WeekTab extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final String groupName;
  final List<Map<String, dynamic>> members;

  const WeekTab({super.key, required this.api, required this.groupId, required this.groupName, required this.members});

  @override
  State<WeekTab> createState() => _WeekTabState();
}

class _WeekData {
  final List<Map<String, dynamic>> titles;
  final List<Map<String, dynamic>> settlements;

  _WeekData(this.titles, this.settlements);
}

class _WeekTabState extends State<WeekTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<_WeekData> _load() async {
    final results = await Future.wait([widget.api.latestTitles(widget.groupId), widget.api.settlements(widget.groupId)]);
    final settlements = results[1]..sort((a, b) => '${b['weekStart']}'.compareTo('${a['weekStart']}'));
    return _WeekData(results[0], settlements);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    return AsyncView<_WeekData>(
      load: _load,
      builder: (context, data, reload) {
        if (data.titles.isEmpty && data.settlements.isEmpty) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(children: [
              const SizedBox(height: 120),
              EmptyView(message: 'ملخص نهاية كل أسبوع لمجموعة ${widget.groupName}: الألقاب والتسوية.', icon: Icons.emoji_events_outlined),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(Space.s4),
            children: [
              if (data.titles.isNotEmpty) ...[
                SectionTitle('ألقاب الأسبوع', trailing: Text(dayAr(data.titles.first['weekStart']), style: text.labelSmall)),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Space.s3,
                  crossAxisSpacing: Space.s3,
                  childAspectRatio: 1.25,
                  children: [for (final t in data.titles) _TitleCard(title: t)],
                ),
              ],
              for (final s in data.settlements) ...[
                SectionTitle(identical(s, data.settlements.first) ? 'ملخص نهاية الأسبوع لمجموعة ${widget.groupName}' : 'أسبوع ${dayAr(s['weekStart'])}'),
                _SettlementCard(settlement: s, members: widget.members),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TitleCard extends StatelessWidget {
  final Map<String, dynamic> title;

  const _TitleCard({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final code = '${title['title'] ?? ''}';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium_rounded, color: c.shadda),
          const Spacer(),
          Text(titlesAr[code] ?? code, style: text.titleMedium),
          Text('${title['name'] ?? ''}', style: text.labelLarge!.copyWith(color: c.primary)),
          Text(titlesHint[code] ?? '', style: text.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final Map<String, dynamic> settlement;
  final List<Map<String, dynamic>> members;

  const _SettlementCard({required this.settlement, required this.members});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final titles = _titles();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${settlement['settlementText'] ?? ''}', style: text.bodyMedium),
          if (titles.isNotEmpty) ...[
            const SizedBox(height: Space.s3),
            Wrap(spacing: Space.s2, runSpacing: Space.s2, children: [for (final t in titles) StatusBadge(t, kind: BadgeKind.success)]),
          ],
        ],
      ),
    );
  }

  // "IRON=4;ROCKET=7" (4 and 7 are group member ids, not member ids) -> the title names
  List<String> _titles() {
    final raw = '${settlement['titles'] ?? ''}';
    if (raw.isEmpty || raw == 'null') return const [];
    return raw.split(';').where((e) => e.contains('=')).map((e) => titlesAr[e.split('=').first] ?? e.split('=').first).toList();
  }
}
