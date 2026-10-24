// numbers are shown with Arabic digits (٠١٢٣)
const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String arabicDigits(Object? value) {
  final out = StringBuffer();
  for (final unit in '${value ?? ''}'.codeUnits) {
    if (unit >= 48 && unit <= 57) {
      out.write(_digits[unit - 48]);
    } else if (unit == 46) {
      out.write('٫'); // the decimal point
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

// 70 -> ٧٠٫٠٠ (the riyal symbol is a widget, see RiyalAmount)
String money(num? amount) => arabicDigits((amount ?? 0).toStringAsFixed(2));

// the week in the backend is Sunday to Saturday: SUN MON TUE WED THU FRI SAT
const weekDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
const weekDaysAr = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];

// the level in the backend -> the name in the app
const levelsAr = {
  'BEGINNER': 'مبتدئ',
  'COMMITTED': 'ملتزم',
  'PERSEVERING': 'مثابر',
  'IRON': 'حديدي',
};
