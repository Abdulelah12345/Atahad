import '../../core/utils/format.dart';

// Arabic labels for the values that come from the backend
const proofMethodsAr = {
  'PHOTO': 'صورة',
  'LOCATION': 'الموقع',
  'QUIZ': 'اختبار',
  'TIMER': 'مؤقت',
};

// the weekly titles (GroupTitleService)
const titlesAr = {
  'IRON': 'الحديدي',
  'ROCKET': 'الصاروخ',
  'OWL': 'البومة',
  'ALARMIST': 'المنبّه',
  'COMEBACK': 'رجعة قوية',
  'EXCUSE_KING': 'ملك الأعذار',
  'TOP_DONOR': 'أكثر متبرّع',
};

const titlesHint = {
  'IRON': 'كمّل بأكثر مرات وبدون أعذار',
  'ROCKET': 'أول واحد كمّل الأسبوع',
  'OWL': 'أكثر إثباتات بالليل',
  'ALARMIST': 'أكثر واحد نبّه المجموعة',
  'COMEBACK': 'فاته الأسبوع اللي قبل وكمّل هالأسبوع',
  'EXCUSE_KING': 'أكثر أعذار مقبولة',
  'TOP_DONOR': 'أكثر واحد تبرّع هالأسبوع',
};

// "2026-10-24T16:34:38" -> "٤:٣٤ م"
String timeAr(Object? value) {
  final date = DateTime.tryParse('${value ?? ''}');
  if (date == null) return '';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return arabicDigits('$hour:$minute ${date.hour < 12 ? 'ص' : 'م'}');
}

// "2026-10-24..." -> "٢٤/١٠"
String dayAr(Object? value) {
  final date = DateTime.tryParse('${value ?? ''}');
  if (date == null) return '';
  return arabicDigits('${date.day}/${date.month}');
}
