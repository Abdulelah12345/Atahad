import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/widgets.dart';
import 'walking_screen.dart';

class WalkingListScreen extends StatefulWidget {
  const WalkingListScreen({super.key});
  @override
  State<WalkingListScreen> createState() => _WalkingListScreenState();
}

class _WalkingListScreenState extends State<WalkingListScreen> {
  late Future<List<Map<String, dynamic>>> _tasks = _load();
  Future<List<Map<String, dynamic>>> _load() async {
    final data = await context.read<ApiClient>().get(
      '/api/v1/commitment-week/today',
    );
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => e['proofMethod'] == 'STEPS')
        .toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تعهّدات المشي')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _tasks,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(walkingError(snapshot.error!)),
                  AtButton(
                    'حاول ثانية',
                    onPressed: () => setState(() => _tasks = _load()),
                  ),
                ],
              ),
            ),
          );
        }
        final tasks = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'تقدر تحدّث خطواتك وترفع صورة اليوم خلال مهلة المزامنة، حتى لو عندك التزام آخر ينتظر التسوية.',
            ),
            const SizedBox(height: 16),
            if (tasks.isEmpty)
              const AppCard(child: Text('ما عندك تعهّد مشي نشط حاليًا.')),
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: ListTile(
                    leading: const Icon(Icons.directions_walk_rounded),
                    title: Text('${task['title']}'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () =>
                        context.push('/walking/${task['weekId']}', extra: task),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
