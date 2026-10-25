import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/at_tokens.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_widgets.dart';

// the moments full screen, swipe between them. Videos play by themselves, without sound, again and again.
// returns true when a moment was deleted
class MomentViewer extends StatefulWidget {
  final GroupApi api;
  final List<Map<String, dynamic>> moments;
  final int start;
  final int? me;

  const MomentViewer({super.key, required this.api, required this.moments, required this.start, required this.me});

  @override
  State<MomentViewer> createState() => _MomentViewerState();
}

class _MomentViewerState extends State<MomentViewer> {
  late final PageController _pages = PageController(initialPage: widget.start);
  late int _index = widget.start;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete(Map<String, dynamic> moment) async {
    if (!await confirm(context, 'تحذف اللحظة؟', 'تنحذف من المجموعة.', yes: 'احذف')) return;
    try {
      await widget.api.deleteMoment(moment['id'] as int);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final current = widget.moments[_index];
    final mine = current['memberId'] == widget.me;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          children: [
            Text(mine ? 'أنت' : '${current['name'] ?? ''}', style: text.titleMedium!.copyWith(color: Colors.white)),
            Text('${dayAr(current['createdAt'])} · ${timeAr(current['createdAt'])}', style: text.labelSmall!.copyWith(color: Colors.white70)),
          ],
        ),
        actions: [
          if (mine) IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(current)),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.moments.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final m = widget.moments[i];
          final url = GroupApi.media(m['mediaUrl']);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.s4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.xl),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: m['mediaType'] == 'VIDEO'
                      ? _MutedVideo(url: url, playing: i == _index)
                      : Image.network(url, fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MutedVideo extends StatefulWidget {
  final String url;
  final bool playing;

  const _MutedVideo({required this.url, required this.playing});

  @override
  State<_MutedVideo> createState() => _MutedVideoState();
}

class _MutedVideoState extends State<_MutedVideo> {
  late final VideoPlayerController _video = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _video.initialize().then((_) async {
      await _video.setVolume(0);
      await _video.setLooping(true);
      if (widget.playing) await _video.play();
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void didUpdateWidget(covariant _MutedVideo old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    widget.playing ? _video.play() : _video.pause();
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Center(child: Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48));
    if (!_ready) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return GestureDetector(
      onTap: () => setState(() => _video.value.isPlaying ? _video.pause() : _video.play()),
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: _video.value.size.width, height: _video.value.size.height, child: VideoPlayer(_video)),
      ),
    );
  }
}
