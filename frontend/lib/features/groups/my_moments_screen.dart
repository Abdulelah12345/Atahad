import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'group_api.dart';
import 'group_ui.dart';
import 'group_widgets.dart';
import 'moment_viewer.dart';
import 'moments_tab.dart';

// OWNER: Fai - «لحظاتي»: all my moments in all my groups (GET /moment/my), on the same paper as the moments
class MyMomentsScreen extends StatefulWidget {
  final GroupApi api;
  final int? me;

  const MyMomentsScreen({super.key, required this.api, required this.me});

  @override
  State<MyMomentsScreen> createState() => _MyMomentsScreenState();
}

class _MyMomentsScreenState extends State<MyMomentsScreen> {
  Key _key = UniqueKey();
  bool _changed = false;

  Future<void> _open(List<Map<String, dynamic>> moments, int index) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => MomentViewer(api: widget.api, moments: moments, start: index, me: widget.me)),
    );
    if (changed == true) {
      _changed = true;
      setState(() => _key = UniqueKey());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final paper = paperColor(c);
    final rule = c.isDark ? c.line : const Color(0xFFD8CFC0);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: paper,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.s4),
                child: Row(
                  children: [
                    HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'رجوع',
                      background: c.surface,
                      color: c.ink,
                      onPressed: () => Navigator.pop(context, _changed),
                    ),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('لحظاتي', style: text.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
                          Text('كل لحظاتك في كل مجموعاتك', style: text.labelSmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AsyncView<List<Map<String, dynamic>>>(
                  key: _key,
                  load: () => inArabic(widget.api.myMoments()),
                  builder: (context, moments, reload) {
                    if (moments.isEmpty) {
                      return const EmptyView(message: 'ما شاركت لحظات للحين. صوّر وأنت تنجز من تبويب اللحظات بأي مجموعة.', icon: Icons.photo_camera_outlined);
                    }
                    // by group, in the order of the newest moment
                    final byGroup = <String, List<Map<String, dynamic>>>{};
                    for (final m in moments) {
                      byGroup.putIfAbsent('${m['groupName'] ?? 'لحظات خاصة'}', () => []).add(m);
                    }
                    return RefreshIndicator(
                      onRefresh: reload,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: Space.s8),
                        children: [
                          for (final entry in byGroup.entries) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Row(
                                children: [
                                  Text(entry.key, style: text.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Container(height: 1, color: rule)),
                                  const SizedBox(width: 10),
                                  Text(arabicDigits(entry.value.length), style: text.labelSmall),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final width = (box.maxWidth - 16) / 2;
                                  return Wrap(
                                    spacing: 16,
                                    runSpacing: 18,
                                    children: [
                                      for (var i = 0; i < entry.value.length; i++)
                                        SizedBox(
                                          width: width,
                                          child: Appear(
                                            index: i,
                                            child: PrintedPhoto(
                                              moment: entry.value[i],
                                              mine: true,
                                              label: entry.value[i]['visibility'] == 'PRIVATE' ? 'لي بس' : 'أنت',
                                              angle: const [-3.0, 2.5, 1.5, -2.0, -1.0, 3.0][i % 6] * math.pi / 180,
                                              onTap: () => _open(entry.value, i),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
