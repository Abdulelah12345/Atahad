import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../proofs/activity_proof_entry.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

// OWNER: Turki - a simple version that shows the API works (GET /commitment-week/today)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final name = context.watch<AuthState>().profile?['name'] ?? '';
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('هلا $name')),
      body: AsyncView<List<dynamic>>(
        load: () async =>
            await api.get('/api/v1/commitment-week/today') as List<dynamic>,
        builder: (context, tasks, reload) {
          if (tasks.isEmpty) {
            return const EmptyView(
                message: 'ما عندك تعهّدات للحين. ابدأ بعادة وحدة.',
                icon: Icons.flag_outlined);
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(Space.s4),
              itemCount: tasks.length,
              separatorBuilder: (context, i) =>
                  const SizedBox(height: Space.s3),
              itemBuilder: (context, i) {
                final t = tasks[i] as Map;
                return AppCard(
                  onTap: () async {
                    await openActivityProof(
                        context, Map<String, dynamic>.from(t));
                    if (context.mounted) await reload();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('${t['title']}',
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
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
