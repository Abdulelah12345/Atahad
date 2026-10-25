import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import 'group_api.dart';
import 'group_widgets.dart';

// a moment like Locket: the live camera in a square, tap = photo, hold = video (5 seconds max, without sound),
// then send it to the group. Returns true when it was sent.
class MomentCameraScreen extends StatefulWidget {
  final GroupApi api;
  final int groupId;

  const MomentCameraScreen({super.key, required this.api, required this.groupId});

  @override
  State<MomentCameraScreen> createState() => _MomentCameraScreenState();
}

class _MomentCameraScreenState extends State<MomentCameraScreen> with SingleTickerProviderStateMixin {
  static const _maxVideo = Duration(seconds: 5);

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  String? _cameraError;
  FlashMode _flash = FlashMode.off;

  bool _recording = false;
  Timer? _videoTimer;
  late final AnimationController _progress = AnimationController(vsync: this, duration: _maxVideo);

  XFile? _file; // the photo or the video after the capture
  bool _isVideo = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  @override
  void dispose() {
    _videoTimer?.cancel();
    _progress.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = 'ما فيه كاميرا بهالجهاز (الآيفون الوهمي ما فيه كاميرا، جرّب على جوالك).');
        return;
      }
      // the front camera first, like Locket
      final front = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      await _start(front >= 0 ? front : 0);
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'ما قدرنا نفتح الكاميرا. اسمح للتطبيق يستخدمها من الإعدادات.');
    }
  }

  Future<void> _start(int index) async {
    final old = _controller;
    final controller = CameraController(_cameras[index], ResolutionPreset.high, enableAudio: false);
    setState(() {
      _controller = null;
      _cameraIndex = index;
    });
    await old?.dispose();
    try {
      await controller.initialize();
      await controller.setFlashMode(_flash);
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'ما قدرنا نفتح الكاميرا. اسمح للتطبيق يستخدمها من الإعدادات.');
    }
  }

  void _flip() {
    if (_cameras.length < 2 || _recording) return;
    _start((_cameraIndex + 1) % _cameras.length);
  }

  Future<void> _toggleFlash() async {
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture || _recording) return;
    try {
      final file = await c.takePicture();
      setState(() {
        _file = file;
        _isVideo = false;
      });
    } catch (_) {}
  }

  Future<void> _startVideo() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _recording) return;
    try {
      await c.startVideoRecording();
      setState(() => _recording = true);
      _progress.forward(from: 0);
      _videoTimer = Timer(_maxVideo, _stopVideo);
    } catch (_) {}
  }

  Future<void> _stopVideo() async {
    final c = _controller;
    if (c == null || !_recording) return;
    _videoTimer?.cancel();
    _progress.stop();
    try {
      final file = await c.stopVideoRecording();
      setState(() {
        _recording = false;
        _file = file;
        _isVideo = true;
      });
    } catch (_) {
      setState(() => _recording = false);
    }
  }

  void _retake() => setState(() {
        _file = null;
        _error = null;
      });

  Future<void> _send() async {
    final file = _file;
    if (file == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final url = await widget.api.uploadMedia(file.path);
      await widget.api.addMoment({
        'mediaUrl': url,
        'mediaType': _isVideo ? 'VIDEO' : 'PHOTO',
        'visibility': 'GROUP',
        'groupId': widget.groupId,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() {
        _sending = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size.width - Space.s4 * 2;
    return Scaffold(
      backgroundColor: c.deep,
      appBar: AppBar(
        backgroundColor: c.deep,
        foregroundColor: Colors.white,
        title: Text('لحظة للمجموعة', style: text.headlineSmall!.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.s4),
          child: Column(
            children: [
              // the square: the live camera, or the photo / video after the capture
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.xl * 1.5),
                    child: SizedBox(width: size, height: size, child: _square(c, text)),
                  ),
                  if (_recording)
                    Positioned(
                      top: Space.s4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _progress,
                          builder: (context, _) {
                            final left = (_maxVideo.inSeconds * (1 - _progress.value)).ceil();
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s1),
                              decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(Radii.full)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                  const SizedBox(width: Space.s2),
                                  Text(arabicDigits('0:${left.toString().padLeft(2, '0')}'),
                                      style: text.labelLarge!.copyWith(color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.s4),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s3),
                  child: Text(_error!, style: text.bodySmall!.copyWith(color: c.danger), textAlign: TextAlign.center),
                ),
              if (_file == null) _cameraButtons(c, text) else _sendButtons(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _square(AtColors c, TextTheme text) {
    if (_file != null) {
      return _isVideo
          ? Container(color: Colors.black, child: const Icon(Icons.play_circle_outline_rounded, size: 72, color: Colors.white))
          : Image.file(File(_file!.path), fit: BoxFit.cover);
    }
    if (_cameraError != null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(Space.s6),
        child: Text(_cameraError!, style: text.bodyMedium!.copyWith(color: Colors.white), textAlign: TextAlign.center),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    // fill the square without stretching the picture
    final preview = controller.value.previewSize;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: preview?.height ?? 1,
        height: preview?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _cameraButtons(AtColors c, TextTheme text) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 30,
              onPressed: _toggleFlash,
              icon: Icon(_flash == FlashMode.off ? Icons.flash_off_rounded : Icons.flash_on_rounded, color: Colors.white),
            ),
            // the shutter: tap = photo, hold = video
            GestureDetector(
              onTap: _takePhoto,
              onLongPressStart: (_) => _startVideo(),
              onLongPressEnd: (_) => _stopVideo(),
              child: SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => CircularProgressIndicator(
                        value: _recording ? _progress.value : 1,
                        strokeWidth: 5,
                        color: _recording ? c.danger : c.gold,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    AnimatedContainer(
                      duration: Motion.fast,
                      width: _recording ? 40 : 66,
                      height: _recording ? 40 : 66,
                      decoration: BoxDecoration(
                        color: _recording ? c.danger : Colors.white,
                        borderRadius: BorderRadius.circular(_recording ? Radii.sm : Radii.full),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              iconSize: 30,
              onPressed: _flip,
              icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: Space.s3),
        Text(_recording ? 'يسجّل بدون صوت... شيل إصبعك عشان يوقف' : 'اضغط للصورة، وطوّل الضغط لفيديو ٥ ثواني',
            style: text.labelSmall!.copyWith(color: Colors.white70)),
      ],
    );
  }

  Widget _sendButtons(AtColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 32,
          onPressed: _sending ? null : _retake,
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
        SizedBox(
          width: 84,
          height: 84,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(backgroundColor: c.gold, foregroundColor: c.onGold, shape: const CircleBorder(), padding: EdgeInsets.zero),
            child: _sending
                ? SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: c.onGold))
                : const Icon(Icons.send_rounded, size: 34),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}
