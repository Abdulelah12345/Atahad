import 'dart:convert';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import 'package:flutter/material.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'proofs_api.dart';

class ActivityHeading extends StatelessWidget {
  final String title;
  final String? goalTitle;
  final String? taskTitle;
  final TextStyle? style;
  final TextAlign textAlign;
  const ActivityHeading(
      {super.key,
      required this.title,
      this.goalTitle,
      this.taskTitle,
      this.style,
      this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final goal = goalTitle?.trim();
    final task = taskTitle?.trim();
    var heading = task != null && task.isNotEmpty ? task : title.trim();
    // Older links may still contain the duplicated combined title.
    final parts = heading.split(' - ');
    if (parts.length == 2 && parts[0].trim() == parts[1].trim()) {
      heading = parts[0].trim();
    }
    final subtitle = task != null &&
            task.isNotEmpty &&
            goal != null &&
            goal.isNotEmpty &&
            goal != task
        ? goal
        : null;
    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(heading, style: style, textAlign: textAlign),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: textAlign),
        ],
      ],
    );
  }
}

class ProofPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const ProofPage(
      {super.key, required this.title, required this.child, this.actions});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: ChipTheme(
                    data: Theme.of(context).chipTheme.copyWith(
                          selectedColor: context.colors.primarySoft,
                          secondarySelectedColor: context.colors.primarySoft,
                          checkmarkColor: context.colors.primary,
                          labelStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: context.colors.ink),
                          secondaryLabelStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: context.colors.ink),
                        ),
                    child: child))),
      );
}

class ProofNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  const ProofNotice(this.text, {super.key, this.icon = Icons.info_outline});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Space.s4),
        decoration: BoxDecoration(
            color: context.colors.primarySoft,
            borderRadius: BorderRadius.circular(Radii.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: context.colors.primary, size: 21),
          const SizedBox(width: Space.s3),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

class ProofEmpty extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  const ProofEmpty(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.fact_check_outlined});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: context.colors.primarySoft),
              child: Icon(icon, size: 38, color: context.colors.primary)),
          const SizedBox(height: 20),
          Text(title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.colors.inkMuted),
              textAlign: TextAlign.center),
        ]),
      );
}

String displayDate(Object? value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '—';
  return arabicDigits('${date.day}/${date.month}/${date.year}');
}

String dateInput(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

IconData methodIcon(String? value) => switch (value) {
      'PHOTO' => Icons.photo_camera_outlined,
      'TIMER' => Icons.timer_outlined,
      'QUIZ' => Icons.quiz_outlined,
      'LOCATION' => Icons.location_on_outlined,
      _ => Icons.fact_check_outlined,
    };

void proofError(BuildContext context, Object error) =>
    showMessage(context, friendlyError(error));

Future<bool> confirmDelete(BuildContext context, String text) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('حذف الطلب؟'),
              content: Text(text),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('تراجع')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('احذف الطلب')),
              ],
            )) ??
    false;

class EvidenceImage extends StatelessWidget {
  final String source;
  const EvidenceImage(this.source, {super.key});
  @override
  Widget build(BuildContext context) {
    if (source.startsWith('capture:')) {
      final id = int.tryParse(source.substring(8));
      if (id == null) return const SizedBox.shrink();
      return _OwnedCaptureImage(id: id);
    }
    Widget image;
    const fallback =
        Padding(padding: EdgeInsets.all(20), child: Text('تعذر عرض الصورة'));
    if (source.startsWith('data:image/')) {
      try {
        image = Image.memory(
            base64Decode(source.substring(source.indexOf(',') + 1)),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => fallback);
      } catch (_) {
        image = fallback;
      }
    } else if (Uri.tryParse(source)?.scheme == 'https' ||
        Uri.tryParse(source)?.scheme == 'http') {
      image = Image.network(source,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => fallback);
    } else {
      return const SizedBox.shrink();
    }
    return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320), child: image));
  }
}

// يبقى تحميل المرفق محفوظا أثناء تحديث عداد المؤقت؛ لا نعيد طلب الصورة كل ثانية.
class _OwnedCaptureImage extends StatefulWidget {
  final int id;
  const _OwnedCaptureImage({required this.id});
  @override
  State<_OwnedCaptureImage> createState() => _OwnedCaptureImageState();
}

class _OwnedCaptureImageState extends State<_OwnedCaptureImage> {
  late Future<dynamic> _image = _load();
  Future<dynamic> _load() => context
      .read<ApiClient>()
      .get('/api/v1/proof-workspace/attachment/${widget.id}');
  @override
  void didUpdateWidget(_OwnedCaptureImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _image = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('تعذر عرض المرفق');
          }
          if (!snapshot.hasData) {
            return const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator()));
          }
          return EvidenceImage('${(snapshot.data as Map)['imageData']}');
        },
      );
}
