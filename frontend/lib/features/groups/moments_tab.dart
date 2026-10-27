import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_ui.dart';
import 'group_widgets.dart';
import 'moment_camera_screen.dart';
import 'moment_viewer.dart';
import 'my_moments_screen.dart';

// the moments of the group, by the week of the goal: "لحظات الأسبوع الأول من هدف «...»"
// design: Moments: paper, printed photos in two columns for every week, a big round camera button. Tap one to open them full screen
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
      String title = 'قبل أهداف المجموعة';
      String? subtitle;
      for (final g in goals) {
        final start = DateTime.tryParse('${g['startDate']}');
        final end = DateTime.tryParse('${g['endDate']}');
        if (start == null || day.isBefore(start) || (end != null && day.isAfter(end))) continue;
        final week = day.difference(start).inDays ~/ 7 + 1;
        key = '${g['id']}-$week';
        title = 'الأسبوع ${_ordinal(week)}';
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

  Future<void> _openMine() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => MyMomentsScreen(api: widget.api, me: widget.me)));
    if (changed == true) _refresh();
  }

  Future<void> _open(List<Map<String, dynamic>> moments, int index) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => MomentViewer(api: widget.api, moments: moments, start: index, me: widget.me)),
    );
    if (changed == true) _refresh();
  }

  static String _count(int n) => n == 1 ? 'لحظة' : n == 2 ? 'لحظتين' : n >= 3 && n <= 10 ? '${arabicDigits(n)} لحظات' : '${arabicDigits(n)} لحظة';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    // paper, like printed photos on a table (the dark theme keeps its own background)
    final paper = paperColor(c);
    final rule = c.isDark ? c.line : const Color(0xFFD8CFC0);
    return ColoredBox(
      color: paper,
      child: Stack(
        children: [
          AsyncView<List<_Section>>(
            key: _key,
            load: () => inArabic(_load()),
            builder: (context, sections, reload) {
              if (sections.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 140),
                  child: Column(
                    children: [
                      Padding(padding: const EdgeInsets.only(top: Space.s3), child: _MyMomentsLink(onTap: _openMine)),
                      const Expanded(child: EmptyView(message: 'صوّروا لحظاتكم وأنتم تنجزون، وتنحفظ هنا لكل أسبوع.', icon: Icons.photo_camera_outlined)),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                  padding: const EdgeInsets.only(top: Space.s3, bottom: 150),
                  children: [
                    _MyMomentsLink(onTap: _openMine),
                    for (final s in sections) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            Text(s.title, style: text.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 10),
                            Expanded(child: Container(height: 1, color: rule)),
                            const SizedBox(width: 10),
                            Text(_count(s.moments.length), style: text.labelSmall),
                          ],
                        ),
                      ),
                      if (s.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(s.subtitle!, style: text.labelSmall),
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
                                for (var i = 0; i < s.moments.length; i++)
                                  SizedBox(
                                    width: width,
                                    child: PrintedPhoto(
                                      moment: s.moments[i],
                                      mine: s.moments[i]['memberId'] == widget.me,
                                      // every photo a little turned, like printed photos on a table
                                      angle: const [-3.0, 2.5, 1.5, -2.0, -1.0, 3.0][i % 6] * math.pi / 180,
                                      onTap: () => _open(s.moments, i),
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
          // the big round camera button
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.s4, top: Space.s2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'صوّر لحظة',
                      child: Pulse(
                        scale: 1.05,
                        period: const Duration(milliseconds: 1800),
                        child: GestureDetector(
                        onTap: _add,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                            // painted in order: the soft shadow, the blue ring, then the paper gap on it
                            boxShadow: [
                              const BoxShadow(color: Color(0x4D10245E), spreadRadius: 9, blurRadius: 20, offset: Offset(0, 10)),
                              BoxShadow(color: c.primary, spreadRadius: 9),
                              BoxShadow(color: paper, spreadRadius: 5),
                            ],
                          ),
                          child: Icon(Icons.photo_camera_rounded, color: c.onPrimary, size: 32),
                        ),
                      ),
                      ),
                    ),
                    const SizedBox(height: Space.s4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: paper.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(Radii.full)),
                      child: Text('ضغطة صورة · مطوّلًا فيديو ٥ ثواني', style: text.labelSmall),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// «لحظاتي»: all my moments in all my groups
class _MyMomentsLink extends StatelessWidget {
  final VoidCallback onTap;

  const _MyMomentsLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.full),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.full),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.collections_rounded, size: 18, color: c.primary),
                const SizedBox(width: 6),
                Text('لحظاتي', style: text.labelMedium!.copyWith(color: c.primary, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class PrintedPhoto extends StatelessWidget {
  final Map<String, dynamic> moment;
  final bool mine;
  final double angle;
  final VoidCallback onTap;
  final String? label; // instead of the name (my moments show the group)

  const PrintedPhoto({super.key, required this.moment, required this.mine, required this.angle, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final isVideo = moment['mediaType'] == 'VIDEO';
    final name = label ?? (mine ? 'أنت' : '${moment['name'] ?? ''}');
    return Semantics(
      button: true,
      label: '${isVideo ? 'فيديو' : 'صورة'} من $name',
      child: Transform.rotate(
        angle: angle,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 7, 7, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Color(0x263C2D14), blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: isVideo
                        ? VideoThumb(url: GroupApi.media(moment['mediaUrl']))
                        : Image.network(
                            GroupApi.media(moment['mediaUrl']),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(color: c.surfaceSunken, child: Icon(Icons.broken_image_outlined, color: c.inkSubtle)),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(name, style: text.labelSmall!.copyWith(color: const Color(0xFF121A2E), fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(dayAr(moment['createdAt']), style: text.labelSmall!.copyWith(color: const Color(0xFF5B667C), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// the first picture of the video, with a small play mark (the video plays when it is opened)
class VideoThumb extends StatefulWidget {
  final String url;

  const VideoThumb({super.key, required this.url});

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
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
          alignment: AlignmentDirectional.topEnd,
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.all(Space.s1),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
