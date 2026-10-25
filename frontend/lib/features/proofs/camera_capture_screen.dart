import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/widgets/widgets.dart';
import 'proof_widgets.dart';

class CapturedImage {
  final Uint8List bytes;
  final String mime;
  const CapturedImage(this.bytes, this.mime);
}

Future<CapturedImage?> takeProofPhoto(BuildContext context, String title) =>
    Navigator.of(context).push<CapturedImage>(
      MaterialPageRoute(builder: (_) => CameraCaptureScreen(title: title)),
    );

class CameraCaptureScreen extends StatefulWidget {
  final String title;
  const CameraCaptureScreen({super.key, required this.title});
  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _camera;
  String? _error;
  bool _busy = false;
  CapturedImage? _preview;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        throw StateError('No camera');
      }
      final selected = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first);
      final camera = CameraController(selected, ResolutionPreset.medium,
          enableAudio: false);
      _camera = camera;
      await camera.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'ما قدرنا نفتح الكاميرا. اسمحي باستخدامها من إعدادات المتصفح، وتأكدي أنها مو مستخدمة ببرنامج آخر.');
      }
    }
  }

  Future<void> _capture() async {
    if (_camera == null || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await _camera!.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
        throw StateError('Image too large');
      }
      setState(() {
        _preview = CapturedImage(bytes, file.mimeType ?? 'image/jpeg');
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, 'تعذر التقاط الصورة. جربي مرة ثانية.');
      }
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProofPage(
      title: widget.title,
      child: Padding(
        padding: const EdgeInsets.all(Space.s5),
        child: Column(children: [
          ProofNotice(
              _preview == null
                  ? 'خلي الشيء المرتبط بمهمتك واضحًا داخل الإطار.'
                  : 'راجعي الصورة قبل اعتمادها. لن تُرفع حتى تعتمديها.',
              icon: Icons.camera_alt_outlined),
          const SizedBox(height: 20),
          Expanded(
              child: Center(
                  child: _preview != null
                      ? InteractiveViewer(child: Image.memory(_preview!.bytes))
                      : _error != null
                          ? Text(_error!, textAlign: TextAlign.center)
                          : _camera?.value.isInitialized == true
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: CameraPreview(_camera!))
                              : const CircularProgressIndicator())),
          const SizedBox(height: 20),
          if (_preview != null) ...[
            AtButton('اعتماد وإرسال',
                onPressed: () => Navigator.pop(context, _preview)),
            const SizedBox(height: 10),
            AtButton('إعادة الالتقاط',
                kind: AtButtonKind.outline,
                onPressed: () => setState(() => _preview = null)),
          ] else
            AtButton('التقط الصورة',
                onPressed:
                    _camera?.value.isInitialized == true ? _capture : null,
                loading: _busy,
                icon: const Icon(Icons.camera_alt_outlined)),
        ]),
      ));
}
