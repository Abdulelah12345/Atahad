import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../proofs/proof_widgets.dart';
import '../proofs/proofs_api.dart';

const _daysFull = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

// one day of the week from the strip on «اليوم»: the proofs and excuses of that day (from the backend)
class DayScreen extends StatelessWidget {
  final DateTime day;

  const DayScreen({super.key, required this.day});

  bool _sameDay(Object? value) {
    final d = DateTime.tryParse('${value ?? ''}');
    return d != null && d.year == day.year && d.month == day.month && d.day == day.day;
  }

  @override
  Widget build(BuildContext context) {
    final api = ProofsApi(context.read<ApiClient>());
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    return Scaffold(
      appBar: AppBar(title: Text(isToday ? 'اليوم' : _daysFull[day.weekday % 7])),
      body: AsyncView<Json>(
        load: api.workspace,
        builder: (context, data, reload) {
          final proofs = ProofsApi.maps(data['proofs']).where((p) => _sameDay(p['activityTime'])).toList();
          final excuses = ProofsApi.maps(data['excuses']).where((e) => _sameDay(e['activityTime'])).toList();
          final done = proofs.where((p) => p['status'] == 'ACCEPTED').length;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(Space.s4),
              children: [
                _DayHero(day: day, done: done, sent: proofs.length),
                if (proofs.isEmpty && excuses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.s8),
                    child: EmptyView(message: 'ما فيه إثباتات بهاليوم', icon: Icons.event_busy_rounded),
                  ),
                if (proofs.isNotEmpty) ...[
                  SectionHeader('الإثباتات', count: arabicDigits(proofs.length), icon: Icons.verified_rounded),
                  for (final p in proofs) _Item(item: p, icon: methodIcon(p['type'] as String?)),
                ],
                if (excuses.isNotEmpty) ...[
                  SectionHeader('الأعذار', count: arabicDigits(excuses.length), icon: Icons.shield_rounded, color: context.colors.pardon),
                  for (final e in excuses) _Item(item: e, icon: Icons.description_outlined),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayHero extends StatelessWidget {
  final DateTime day;
  final int done;
  final int sent;

  const _DayHero({required this.day, required this.done, required this.sent});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(color: c.deep, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.deepRaised, borderRadius: BorderRadius.circular(18)),
            child: Text(arabicDigits(day.day), style: text.headlineMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: Space.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_daysFull[day.weekday % 7]} ${arabicDigits(day.day)} ${_months[day.month - 1]}',
                    style: text.titleMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF8FB4FF)),
                  const SizedBox(width: 4),
                  Text(done == 0 ? 'ما انقبل شي بهاليوم' : 'انقبلت ${arabicDigits(done)} من ${arabicDigits(sent)}',
                      style: text.labelSmall!.copyWith(color: const Color(0xFFB7C5E8))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// one proof or excuse of the day with its state
class _Item extends StatelessWidget {
  final Json item;
  final IconData icon;

  const _Item({required this.item, required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final (String label, Color fg, Color bg) = switch (item['status']) {
      'ACCEPTED' => ('مقبول', c.success, c.successSoft),
      'REJECTED' => ('مرفوض', c.danger, c.dangerSoft),
      'ESCALATED' => ('عند المشرف', c.pardonText, c.pardonSoft),
      _ => ('بالمراجعة', c.warning, c.warningSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s2),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
        child: Row(
          children: [
            IconTile(icon, size: 40, fg: fg, bg: bg),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${item['title'] ?? ''}', style: text.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            TagPill(label, fg: fg, bg: bg),
          ],
        ),
      ),
    );
  }
}
