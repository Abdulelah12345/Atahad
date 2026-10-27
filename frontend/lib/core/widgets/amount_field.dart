import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import 'riyal.dart';

// the amount in riyals: a big number with the riyal symbol after it, and a hint with the most it can cost a week
// accepts Arabic and Latin digits (the form parses them)
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint; // «لو فاتتك كلها: ٧٠ ريال صدقة بالأسبوع»
  final String? error; // the problem and the fix: «أقل مبلغ ٥ ريال»
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.error,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: text.labelLarge),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          validator: validator,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: text.headlineSmall!.copyWith(fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            suffixIcon: Padding(padding: const EdgeInsetsDirectional.only(end: 16), child: RiyalSymbol(size: 20, color: c.goldText)),
            suffixIconConstraints: const BoxConstraints(minHeight: 52, minWidth: 40),
            constraints: const BoxConstraints(minHeight: 52),
            helperText: error == null ? hint : null,
            helperMaxLines: 2,
            helperStyle: text.labelSmall!.copyWith(color: c.inkSubtle),
            errorText: error,
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}
