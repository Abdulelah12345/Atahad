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
                Row(
                  children: [
                    Expanded(
                      child: AtButton('هالشهر', kind: AtButtonKind.outline, loading: _busy, onPressed: () => _generate(thisMonth)),
                    ),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: AtButton('الشهر اللي فات', kind: AtButtonKind.outline, onPressed: _busy ? null : () => _generate(lastMonth)),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s2),
                Text('يسوي الملخص من جديد لو كان موجود.', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: Space.s4),
                if (sorted.isEmpty)
                  const EmptyView(message: 'ما فيه ملخصات للحين. أول كل شهر ينزل ملخص الشهر اللي فات.', icon: Icons.auto_awesome_outlined)
                else
                  ...sorted.map((w) => Padding(padding: const EdgeInsets.only(bottom: Space.s3), child: _WrappedCard(item: w))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WrappedCard extends StatelessWidget {
  final JsonMap item;

  const _WrappedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    return AppCard(
      color: c.deep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: c.goldLight, size: 20),
              const SizedBox(width: Space.s2),
              Text(arabicDigits(item['month']), style: text.titleMedium!.copyWith(color: c.goldLight)),
            ],
          ),
          const SizedBox(height: Space.s3),
          Text('${item['summary'] ?? ''}', style: text.bodyMedium!.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
