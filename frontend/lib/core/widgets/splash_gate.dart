import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_logo.dart';

// the splash: the signature is written and the spark comes out of the riyal (assets/splash, 4.2s, by the theme)
// it covers the app once when it opens, a tap skips it; with reduced motion the logo shows for a moment
// the native launch screen has the same background color, so there is no flash before it
class SplashGate extends StatefulWidget {
  final Widget child;

  const SplashGate({super.key, required this.child});

  // the first frame of the videos (also in LaunchScreen.storyboard and launch_background.xml)
  static const lightBg = Color(0xFFF0F3F9);
  static const darkBg = Color(0xFF0E2250);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  VideoPlayerController? _video;
  bool _started = false;
  bool _fading = false;
  bool _done = false;
  bool _dark = false;
  Timer? _safety;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _dark = Theme.of(context).brightness == Brightness.dark;
    if (MediaQuery.of(context).disableAnimations) {
      _safety = Timer(const Duration(milliseconds: 900), _finish);
      return;
    }
    _safety = Timer(const Duration(seconds: 7), _finish); // never stuck on the splash
    final video = VideoPlayerController.asset(_dark ? 'assets/splash/splash_dark.mp4' : 'assets/splash/splash_light.mp4');
    _video = video;
    video.initialize().then((_) {
      if (!mounted || _done) return;
      video
        ..setVolume(0)
        ..addListener(_onTick)
        ..play();
      setState(() {});
    }).catchError((Object _) => _finish());
  }

  void _onTick() {
    final v = _video!.value;
    if (v.isInitialized && v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 80)) {
      _finish();
    }
  }

  void _finish() {
    if (_fading || !mounted) return;
    _safety?.cancel();
    setState(() => _fading = true);
  }

  @override
  void dispose() {
    _safety?.cancel();
    _video?.removeListener(_onTick);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final video = _video;
    final ready = video != null && video.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedOpacity(
          opacity: _fading ? 0 : 1,
          duration: const Duration(milliseconds: 350),
          onEnd: () {
            if (_fading && mounted) {
              setState(() => _done = true);
              _video?.dispose();
              _video = null;
            }
          },
          child: GestureDetector(
            onTap: _finish,
            child: ColoredBox(
              color: _dark ? SplashGate.darkBg : SplashGate.lightBg,
              child: ready
                  // the video at 62% of the screen width (the logo stays small and calm), its edges fade into the background
                  ? Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.62,
                        child: AspectRatio(
                          aspectRatio: video.value.aspectRatio,
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (rect) => const RadialGradient(
                              radius: 0.75,
                              colors: [Colors.white, Colors.white, Colors.transparent],
                              stops: [0, 0.6, 1],
                            ).createShader(rect),
                            child: VideoPlayer(video),
                          ),
                        ),
                      ),
                    )
                  : (_video == null ? Center(child: AppLogo(width: 200, tagline: true, white: _dark)) : const SizedBox.expand()),
            ),
          ),
        ),
      ],
    );
  }
}
