import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';

// small widgets used by the group pages

// the body of a bottom sheet that moves up with the keyboard
// (a snack bar shows behind a sheet, so the sheet shows its error inside it)
class SheetBody extends StatelessWidget {
  final String title;
  final Widget child;
  final String? error;

  const SheetBody({super.key, required this.title, required this.child, this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, MediaQuery.of(context).viewInsets.bottom + Space.s6),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: Space.s4),
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(Space.s3),
                decoration: BoxDecoration(color: context.colors.dangerSoft, borderRadius: BorderRadius.circular(Radii.md)),
                child: Text(error!, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.colors.danger)),
              ),
              const SizedBox(height: Space.s3),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.s5, bottom: Space.s3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: context.colors.shadda, shape: BoxShape.circle)),
          const SizedBox(width: Space.s2),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// the first letter of the name in a circle
class NameAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? color;

  const NameAvatar(this.name, {super.key, this.radius = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color ?? c.primarySoft,
      child: Text(
        name.isEmpty ? '' : name.characters.first,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color == null ? c.primary : Colors.white),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String message, {String yes = 'تأكيد'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(yes)),
      ],
    ),
  );
  return result == true;
}

// the message of an error, for the sheets
String errorText(Object error) => error is ApiException ? error.message : 'صار خطأ، حاول مرة ثانية.';
