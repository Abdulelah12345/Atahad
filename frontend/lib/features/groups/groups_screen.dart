import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';

// OWNER: Fai - a simple version (GET /group-member/my)
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المجموعات')),
      body: AsyncView<List<dynamic>>(
        load: () async => await api.get('/api/v1/group-member/my') as List<dynamic>,
        builder: (context, groups, reload) {
          if (groups.isEmpty) return const EmptyView(message: 'ما انضميت لمجموعة للحين.', icon: Icons.groups_outlined);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(Space.s4),
              itemCount: groups.length,
              separatorBuilder: (context, i) => const SizedBox(height: Space.s3),
              itemBuilder: (context, i) {
                final g = groups[i] as Map;
                final name = '${g['groupName'] ?? ''}';
                final color = AtColors.team((g['groupId'] as int? ?? 0) - 1);
                return AppCard(
                  color: color,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(name.isEmpty ? '' : name.substring(0, 1), style: text.titleMedium!.copyWith(color: Colors.white)),
                      ),
                      const SizedBox(width: Space.s3),
                      Expanded(child: Text(name, style: text.headlineSmall!.copyWith(color: Colors.white))),
                      Text('${arabicDigits(g['points'] ?? 0)} نقطة', style: text.labelLarge!.copyWith(color: Colors.white)),
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
