import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitments_api.dart';

// OWNER: Turki - Monthly Wrapped: the summary of every month, written by the AI
// it is made automatically on the first day of the month, the member can make the current one now
class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  late final _api = CommitmentsApi(context.read<ApiClient>());
  int _version = 0;
  bool _busy = false;

  Future<void> _generate(String month) async {
    setState(() => _busy = true);
    try {
      await _api.generateWrapped(month);
      if (mounted) setState(() => _version++);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = isoMonth(now);
    final lastMonth = isoMonth(DateTime(now.year, now.month - 1));
    return Scaffold(
      appBar: AppBar(title: const Text('ملخص الشهر')),
      body: AsyncView<List<JsonMap>>(
        key: ValueKey(_version),
        load: _api.wrapped,
        builder: (context, items, reload) {
          final sorted = [...items]..sort((a, b) => '${b['month']}'.compareTo('${a['month']}'));
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(Space.s4),
              children: [
                // make a summary now (it replaces the old one of that month)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _generate(thisMonth),
                        icon: _busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('هالشهر'),
                      ),
                    ),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _generate(lastMonth),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('اللي فات'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s4),
                if (sorted.isEmpty)
                  const EmptyView(message: 'أول كل شهر ينزل ملخصك', icon: Icons.auto_awesome_outlined)
                else
                  ...sorted.map((w) => Padding(padding: const EdgeInsets.only(bottom: Space.s4), child: _WrappedCard(item: w))),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

// "2026-10" -> "أكتوبر ٢٠٢٦"
String _monthName(Object? value) {
  final parts = '$value'.split('-');
  final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
  if (m == null || m < 1 || m > 12) return arabicDigits(value);
  return '${_monthsAr[m - 1]} ${arabicDigits(parts[0])}';
}

// one month as a story card (design: Wrapped): purple, the month big, the AI words as a quote
class _WrappedCard extends StatelessWidget {
  final JsonMap item;

  const _WrappedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6A4BE0), Color(0xFF4B32B8)]),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -40,
            start: -30,
            child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
          ),
          PositionedDirectional(
            bottom: 18,
            end: 22,
            child: Transform.rotate(
              angle: 0.4,
              child: Container(width: 34, height: 10, decoration: BoxDecoration(color: c.urgent, borderRadius: BorderRadius.circular(Radii.full))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s5, Space.s5, Space.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFE29A), size: 20),
                    const SizedBox(width: Space.s2),
                    Text('${_monthName(item['month'])} مع أتعهّد',
                        style: text.titleMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: Space.s4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                  child: Text('«${item['summary'] ?? ''}»', style: text.bodyMedium!.copyWith(color: Colors.white, height: 1.8)),
                ),
                const SizedBox(height: Space.s2),
                Text('ملخص من الذكاء', style: text.labelSmall!.copyWith(color: const Color(0xFFEEE9FD))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
