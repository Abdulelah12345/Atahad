import '../../core/utils/format.dart';

// Arabic labels for the values that come from the backend
const proofMethodsAr = {
  'PHOTO': 'صورة',
  'LOCATION': 'الموقع',
  'QUIZ': 'اختبار',
  'TIMER': 'مؤقت',
};

// the level of the group challenge (GroupGoal.difficulty), null = the old goals (everyone donated)
const difficultyAr = {'SOLO': 'فردي', 'HARD': 'صعب'};

String difficultyOf(Map<String, dynamic> goal) => '${goal['difficulty'] ?? 'HARD'}';

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

// the reasons of the group points (PointLogService)
const pointReasonsAr = {
  'GOLDEN_WEEK': 'أسبوع ذهبي: الكل كمّل',
  'MATCH_WIN': 'فوز بالمنافسة',
  'MATCH_ALL_DONE': 'الكل كمّل أسبوع المنافسة',
  'LEAST_PROCRASTINATION': 'الأقل تسويف بالمنافسة',
  'GRACE_DAY_REDEEMED': 'انصرفت: بطاقة عفو لكل عضو',
};

// the app messages in the chat come from the backend in English, this puts them in Arabic
String systemTextAr(String text) {
  final rules = <RegExp, String Function(Match m)>{
    RegExp(r'^(.+) joined the group$'): (m) => '${m[1]} انضم للمجموعة',
    RegExp(r'^(.+) left the group$'): (m) => '${m[1]} طلع من المجموعة',
    RegExp(r'^(.+) was removed: failed twice in this group$'): (m) => '${m[1]} طلع من المجموعة لأنه ما كمّل أسبوعه مرتين',
    RegExp(r'^(.+) was removed: did not pay the group donation for (\d+) days$'): (m) =>
        '${m[1]} طلع من المجموعة لأنه ما دفع تبرّع المجموعة ${arabicDigits(m[2])} أيام',
    RegExp(r'^(.+) was removed: (.+)$'): (m) => '${m[1]} طلع من المجموعة',
    RegExp(r'^(.+) challenged you to a one week match$'): (m) => 'مجموعة ${m[1]} تتحداكم أسبوع كامل',
    RegExp(r'^(.+) accepted the match, it starts (\S+)$'): (m) => 'مجموعة ${m[1]} قبلت التحدي، المنافسة تبدأ ${_date(m[2])}',
    RegExp(r'^The match with (.+) starts (\S+)$'): (m) => 'المنافسة مع ${m[1]} تبدأ ${_date(m[2])}',
    RegExp(r'^(.+) declined the match$'): (m) => 'مجموعة ${m[1]} رفضت التحدي',
    RegExp(r'^Match result: (.+) (\d+)% - (\d+)% (.+), a draw$'): (m) =>
        'نتيجة المنافسة: ${m[1]} ${arabicDigits(m[2])}٪ - ${arabicDigits(m[3])}٪ ${m[4]}، تعادل',
    RegExp(r'^Match result: (.+) (\d+)% - (\d+)% (.+), the winner is (.+)$'): (m) =>
        'نتيجة المنافسة: ${m[1]} ${arabicDigits(m[2])}٪ - ${arabicDigits(m[3])}٪ ${m[4]}، الفايز ${m[5]} 🏆',
    RegExp(r'^New goal: (.+), (\d+) times a week for (\d+) weeks, ([\d.]+) SAR for every missed time$'): (m) =>
        'هدف جديد: ${m[1]}، ${arabicDigits(m[2])} مرات بالأسبوع لمدة ${arabicDigits(m[3])} أسابيع، و${arabicDigits(m[4])} ريال تبرّع عن كل مرة تفوت',
    RegExp(r'^New goal: (.+), a plan of (\d+) weeks \(week 1: (.+), (\d+) times\), ([\d.]+) SAR for every missed time$'): (m) =>
        'هدف جديد: ${m[1]}، خطة ${arabicDigits(m[2])} أسابيع (الأسبوع الأول: ${m[3]}، ${arabicDigits(m[4])} مرات)، و${arabicDigits(m[5])} ريال تبرّع عن كل مرة تفوت',
    RegExp(r'^The goal (.+) ended, vote for the next goal$'): (m) => 'خلص هدف «${m[1]}»، صوّتوا على الهدف الجاي',
  };
  for (final rule in rules.entries) {
    final m = rule.key.firstMatch(text.trim());
    if (m != null) return rule.value(m);
  }
  return text; // the weekly summary is already in Arabic
}

String _date(String? value) => dayAr(value);

// the group errors from the backend in Arabic
String groupErrorAr(String message) {
  const exact = {
    'Invalid invite code': 'كود الدعوة غلط، أو المجموعة انحذفت.',
    'Member already joined this group': 'هو موجود بالمجموعة من قبل.',
    'This member was removed from this group and cannot join it again': 'انطلع من هالمجموعة قبل، وما يقدر يرجع لها.',
    'No member with this phone number, ask him to register first': 'ما فيه أحد مسجّل بهالرقم، خله يسجّل في أتعهّد أول.',
    'Group owner cannot leave the group, archive it instead': 'منشئ المجموعة ما يقدر يطلع، يقدر يحذفها.',
    'Only the group owner can do this': 'هذي لمنشئ المجموعة بس.',
    'You are not in this group': 'ما عدت بهالمجموعة.',
    'Group not found': 'ما لقينا المجموعة، تأكد من الكود.',
    'Member not found': 'ما لقينا هالشخص.',
    'You cannot challenge your own group': 'ما تقدر تتحدى مجموعتك.',
    'Both groups need a running goal': 'لازم المجموعتين عندها هدف شغّال.',
    'Both groups must have an active goal': 'لازم المجموعتين عندها هدف شغّال.',
    'Both goals must continue until the match ends': 'هدف وحدة من المجموعتين يخلص قبل نهاية أسبوع المنافسة.',
    'There is already a match between the two groups': 'فيه تحدي مفتوح بينكم من قبل.',
    'Match not found': 'التحدي ما عاد موجود.',
    'Your group must have an active goal': 'لازم يكون عندكم هدف شغّال عشان نقترح مجموعات.',
    'Your group must have at least 2 members': 'لازم يكون بالمجموعة عضوين على الأقل.',
    'The group already has a goal, one goal at a time': 'فيه هدف شغّال، هدف وحدة بس بنفس الوقت.',
    'The group has a running goal, wait until it ends': 'فيه هدف شغّال، انتظروا لين يخلص.',
    'The group has no goal now, choose the next goal': 'ما فيه هدف شغّال الحين، اختاروا الهدف الجاي.',
    'Proposal not found': 'الاقتراح ما عاد موجود.',
    'Proposal not found in this group': 'الاقتراح ما عاد موجود.',
    'This proposal is closed': 'الاقتراح انقفل.',
    'Voting on this proposal is closed': 'التصويت على هالاقتراح انقفل.',
    'You already voted for this proposal': 'صوتك محسوب من قبل.',
    'You already alerted this friend today': 'نبّهته اليوم، تقدر تنبّهه بكرة.',
    'You cannot alert yourself': 'ما تقدر تنبّه نفسك.',
    'Your friend already finished this week': 'خلّص أسبوعه، ما يحتاج تنبيه.',
    'Your friend sent an excuse, alerts are stopped': 'أرسل عذر، التنبيهات واقفة عنه.',
    'No task of this goal this week': 'ما عليك مهمة من هالهدف هالأسبوع.',
    'You are not in this goal': 'أنت مو داخل هالهدف، تدخل مع الهدف الجاي.',
    'Choose the place first': 'اختر مكانك أول.',
    'This goal is not proved with the location': 'هالهدف ما يتثبت بالموقع.',
    'A TIMER goal needs the minutes of one time': 'حدد كم دقيقة للمرة الوحدة.',
    'Write the times per week and the weeks, or choose a plan of weeks': 'حدد المرات والأسابيع، أو اختر خطة أسابيع.',
    'Send a photo or a video': 'أرسل صورة أو فيديو.',
    'Only photos and videos are allowed': 'الصور والفيديو بس.',
    'The file must be 20 MB max': 'الملف أكبر من ٢٠ ميقا.',
    'The file was not saved, try again': 'ما انحفظ الملف، جرّب مرة ثانية.',
    'You can only delete your own message': 'تقدر تحذف رسايلك بس.',
    'You can only delete your own moment': 'تقدر تحذف لحظاتك بس.',
    'Choose the group to share with': 'اختر المجموعة اللي تشارك فيها.',
    'This account is banned': 'هالحساب موقوف.',
    'This member is banned from groups': 'هالشخص موقوف من المجموعات.',
    'No moments from your friends yet': 'ما فيه لحظات من أصحابك للحين.',
    'No settlement yet, the first one is on sunday': 'أول ملخص يطلع يوم الأحد.',
    'Your group already has a match, one match at a time': 'عندكم منافسة حاليّة أو في انتظار الرد على تحدي مرسل، منافسة وحدة بس بنفس الوقت.',
    'The other group is in a match now, try after it ends': 'المجموعة الثانية عندها منافسة حاليّة، تحدّوها بعد ما تخلص.',
    'One of the groups is in a match now, one match at a time': 'وحدة من المجموعتين عندها منافسة حاليّة، منافسة وحدة بس بنفس الوقت.',
    'Difficulty must be SOLO or HARD': 'اختر مستوى التحدي.',
  };
  final m = message.trim();
  if (exact.containsKey(m)) return exact[m]!;
  final full = RegExp(r'^Group is full, maximum (\d+) members$').firstMatch(m);
  if (full != null) return 'المجموعة مليانة، أقصى شي ${arabicDigits(full[1])} أعضاء.';
  final min = RegExp(r'^A group goal needs at least (\d+) members$').firstMatch(m);
  if (min != null) return 'هدف المجموعة يحتاج ${arabicDigits(min[1])} أعضاء على الأقل.';
  final quiet = RegExp(r'^No alerts after midnight, try again after (\d+) AM$').firstMatch(m);
  if (quiet != null) return 'ما فيه تنبيهات بعد نص الليل، جرّب بعد الساعة ${arabicDigits(quiet[1])} الصبح.';
  final ban = RegExp(r'^This member is banned from groups until (\S+)$').firstMatch(m);
  if (ban != null) return 'هالشخص موقوف من المجموعات لين ${dayAr(ban[1])}.';
  return message;
}
