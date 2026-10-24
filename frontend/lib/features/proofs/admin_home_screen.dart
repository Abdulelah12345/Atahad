import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/widgets/widgets.dart';

// OWNER: Subhiyyah - the admin home: the review queue (GET /admin-review/queue/{adminId})
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final auth = context.watch<AuthState>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المراجعة'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthState>().logout())],
      ),
      body: AsyncView<List<dynamic>>(
        load: () async => await api.get('/api/v1/admin-review/queue/${auth.userId}') as List<dynamic>,
        builder: (context, items, reload) {
          if (items.isEmpty) return const EmptyView(message: 'ما فيه شي ينتظر المراجعة.', icon: Icons.task_alt);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(Space.s4),
              itemCount: items.length,
              separatorBuilder: (context, i) => const SizedBox(height: Space.s3),
              itemBuilder: (context, i) => AppCard(child: Text('${items[i]}', style: text.bodySmall)),
            ),
          );
        },
      ),
    );
  }
}
