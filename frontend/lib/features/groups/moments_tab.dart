import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/widgets/widgets.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'moment_camera_screen.dart';
import 'moment_viewer.dart';

// the moments of the group, by the week of the goal: "لحظات الأسبوع الأول من هدف «...»"
// every week is a row of small photos (like printed photos), tap one to open them full screen
class MomentsTab extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final int? me;

  const MomentsTab({super.key, required this.api, required this.groupId, required this.me});

  @override
  State<MomentsTab> createState() => _MomentsTabState();
}

class _Section {
  final String title;
  final String? subtitle;
  final List<Map<String, dynamic>> moments;

  _Section(this.title, this.subtitle, this.moments);
}

class _MomentsTabState extends State<MomentsTab> with AutomaticKeepAliveClientMixin {
  Key _key = UniqueKey();

  @override
  bool get wantKeepAlive => true;

  void _refresh() => setState(() => _key = UniqueKey());

  Future<List<_Section>> _load() async {
    final results = await Future.wait([widget.api.groupMoments(widget.groupId), widget.api.goalHistory(widget.groupId)]);
    return _sections(results[0], results[1]);
  }

  // puts every moment in the week of the goal it was taken in
  static List<_Section> _sections(List<Map<String, dynamic>> moments, List<Map<String, dynamic>> goals) {
    final groups = <String, _Section>{};
    final order = <String, DateTime>{};
    for (final m in moments) {
      final created = DateTime.tryParse('${m['createdAt']}');
      if (created == null) continue;
      final day = DateTime(created.year, created.month, created.day);
      String key = 'other';
      String title = 'لحظات قبل أهداف المجموعة';
      String? subtitle;
      for (final g in goals) {
        final start = DateTime.tryParse('${g['startDate']}');
        final end = DateTime.tryParse('${g['endDate']}');
        if (start == null || day.isBefore(start) || (end != null && day.isAfter(end))) continue;
        final week = day.difference(start).inDays ~/ 7 + 1;
        key = '${g['id']}-$week';
        title = 'لحظات الأسبوع ${_ordinal(week)}';
        subtitle = 'من هدف «${g['title'] ?? ''}»';
        break;
      }
      groups.putIfAbsent(key, () => _Section(title, subtitle, []));
      groups[key]!.moments.add(m);
      if (order[key] == null || created.isAfter(order[key]!)) order[key] = created;
    }
    final keys = groups.keys.toList()..sort((a, b) => order[b]!.compareTo(order[a]!)); // the newest week first
    return [for (final k in keys) groups[k]!];
  }

  static String _ordinal(int n) {
    const names = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر'];
    return n >= 1 && n <= names.length ? names[n - 1] : 'رقم $n';
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => MomentCameraScreen(api: widget.api, groupId: widget.groupId)),
    );
    if (added == true) _refresh();
  }

  Future<void> _open(List<Map<String, dynamic>> moments, int index) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => MomentViewer(api: widget.api, moments: moments, start: index, me: widget.me)),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('شارك لحظة'),
      ),
      body: AsyncView<List<_Section>>(
        key: _key,
        load: _load,
        builder: (context, sections, reload) {
          if (sections.isEmpty) {
            return const EmptyView(message: 'صوّروا لحظاتكم وأنتم تنجزون، وتنحفظ هنا لكل أسبوع.', icon: Icons.photo_camera_outlined);
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.only(top: Space.s4, bottom: 96),
              children: [
                for (final s in sections) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: text.headlineSmall),
                        if (s.subtitle != null) Text(s.subtitle!, style: text.bodySmall),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s4),
                      itemCount: s.moments.length,
                      itemBuilder: (context, i) => _PrintedPhoto(
                        moment: s.moments[i],
                        mine: s.moments[i]['memberId'] == widget.me,
                        // every photo a little turned, like printed photos on a table
                        angle: (i.isEven ? -1 : 1) * (2 + (i % 3)) * math.pi / 180,
                        onTap: () => _open(s.moments, i),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PrintedPhoto extends StatelessWidget {
  final Map<String, dynamic> moment;
  final bool mine;
  final double angle;
  final VoidCallback onTap;

  const _PrintedPhoto({required this.moment, required this.mine, required this.angle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final isVideo = moment['mediaType'] == 'VIDEO';
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Space.s3),
      child: Transform.rotate(
        angle: angle,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 168,
            padding: const EdgeInsets.fromLTRB(Space.s2, Space.s2, Space.s2, Space.s1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.sm),
              boxShadow: [BoxShadow(color: c.deep.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sm / 2),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: isVideo
                        ? _VideoThumb(url: '${moment['mediaUrl'] ?? ''}')
                        : Image.network(
                            '${moment['mediaUrl'] ?? ''}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(color: c.surfaceSunken, child: Icon(Icons.broken_image_outlined, color: c.inkSubtle)),
                          ),
                  ),
                ),
                const SizedBox(height: Space.s2),
                Text(mine ? 'أنت' : '${moment['name'] ?? ''}',
                    style: text.labelLarge!.copyWith(color: const Color(0xFF12302B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${dayAr(moment['createdAt'])} · ${timeAr(moment['createdAt'])}', style: text.labelSmall!.copyWith(color: const Color(0xFF5A6B66))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// the first picture of the video, with a small play mark (the video plays when it is opened)
class _VideoThumb extends StatefulWidget {
  final String url;

  const _VideoThumb({required this.url});

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  late final VideoPlayerController _video = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _video.initialize().then((_) async {
      await _video.setVolume(0);
      await _video.seekTo(Duration.zero);
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: _video.value.size.width, height: _video.value.size.height, child: VideoPlayer(_video)),
          )
        else
          Container(color: context.colors.deep),
        Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Container(
            margin: const EdgeInsets.all(Space.s2),
            padding: const EdgeInsets.all(Space.s1),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
