import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/at_tokens.dart';

// scans the QR of a group invite and returns the invite code
// the QR content is "atahad://join/CODE" (GroupInviteResponse.qrContent), a plain code works too
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String? codeFrom(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    const prefix = 'atahad://join/';
    if (value.startsWith(prefix)) return value.substring(prefix.length);
    if (value.contains('://')) return null; // another app's QR
    return value;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = codeFrom(barcode.rawValue);
      if (code != null) {
        _done = true;
        Navigator.pop(context, code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('امسح باركود المجموعة'),
        actions: [IconButton(icon: const Icon(Icons.flash_on_rounded), onPressed: () => _controller.toggleTorch())],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.s6),
                child: Text('ما قدرنا نفتح الكاميرا. اسمح للتطبيق يستخدمها من الإعدادات، أو اكتب الكود.',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white), textAlign: TextAlign.center),
              ),
            ),
          ),
          // the frame in the middle
          IgnorePointer(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(Radii.xl)),
            ),
          ),
        ],
      ),
    );
  }
}
