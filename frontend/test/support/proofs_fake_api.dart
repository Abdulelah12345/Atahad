import 'dart:convert';
import 'package:atahad/core/api/api_client.dart';
import 'package:atahad/core/auth/auth_state.dart';

// بيانات اختبارات ومعاينة معزولة فقط؛ لا تتصل بقاعدة بيانات المستخدم أو الذكاء.
class ProofsFakeApi extends ApiClient {
  final bool empty;
  final List<String> posts = [];
  late final String day = DateTime.now().toIso8601String().substring(0, 10);
  late final tasks = <Map<String, dynamic>>[
    for (final (index, entry) in {
      'TIMER': 'دراسة نصف ساعة',
      'QUIZ': 'قراءة فصل من كتاب',
      'PHOTO': 'ترتيب المكتب',
      'LOCATION': 'الذهاب للنادي'
    }.entries.indexed)
      {
        'commitmentId': index + 1,
        'weekId': index + 1,
        'goalTaskId': null,
        'type': 'HABIT',
        'title': entry.value,
        'proofMethod': entry.key,
        'required': 4,
        'completed': 2,
        'excused': 0,
        'remaining': 2,
        'trackStatus': 'SAFE',
        'amountPerTime': 10,
        'plannedToday': true
      },
  ];
  late final workspace = <String, dynamic>{
    'proofs': empty
        ? []
        : [
            {
              'id': 1,
              'title': 'دراسة نصف ساعة',
              'weekId': 1,
              'goalTaskId': null,
              'status': 'ACCEPTED',
              'type': 'TIMER',
              'activityTime': '${day}T09:00:00',
              'createdAt': '${day}T09:30:00',
              'managed': true,
              'canEdit': false,
              'canDelete': false,
              'canObject': false
            },
            {
              'id': 2,
              'title': 'ترتيب المكتبة',
              'weekId': 5,
              'goalTaskId': null,
              'status': 'REJECTED',
              'type': 'PHOTO',
              'activityTime': '${day}T08:00:00',
              'reason': 'الصورة غير واضحة بما يكفي لتأكيد إنجاز النشاط.',
              'managed': true,
              'canEdit': false,
              'canDelete': false,
              'canObject': true
            },
          ],
    'excuses': empty
        ? []
        : [
            {
              'id': 11,
              'title': 'قراءة فصل من كتاب',
              'weekId': 2,
              'goalTaskId': 2,
              'type': 'SICK',
              'status': 'PENDING',
              'processingStatus': 'WAITING',
              'activityTime': day,
              'reason': 'بانتظار بدء المعالجة',
              'canEdit': true,
              'canDelete': true,
              'canObject': false
            },
            {
              'id': 12,
              'title': 'الذهاب للنادي',
              'weekId': 4,
              'goalTaskId': null,
              'type': 'TRAVEL',
              'status': 'ACCEPTED',
              'activityTime': day,
              'canEdit': false,
              'canDelete': false,
              'canObject': false
            },
          ],
    'objections': empty
        ? []
        : [
            {
              'id': 21,
              'title': 'ترتيب المكتب',
              'kind': 'PROOF',
              'status': 'PENDING',
              'reason': 'الصورة تبين المكتب بعد ترتيب الأوراق والأدوات.',
              'createdAt': '${day}T10:00:00',
              'reviewStartedAt': null,
              'canEdit': true,
              'canDelete': true
            },
          ],
    'visits': [],
  };
  late final penalties = empty
      ? <dynamic>[]
      : [
          {
            'id': 1,
            'amount': 20,
            'status': 'PENDING',
            'reason': 'LOST_DAY',
            'createdAt': '${day}T09:00:00',
            'memberName': 'عضو تجريبي',
            'title': 'نشاط القراءة'
          },
          {
            'id': 2,
            'amount': 10,
            'status': 'PAID',
            'reason': 'LOST_DAY',
            'createdAt': '${day}T08:00:00',
            'memberName': 'عضو تجريبي',
            'title': 'جلسة دراسة'
          },
        ];
  late final queue = <dynamic>[
    {
      'id': 21,
      'kind': 'OBJECTION',
      'memberId': 1,
      'memberName': 'عضو تجريبي',
      'about': 'ترتيب المكتب',
      'details': 'الصورة تبين الترتيب بعد تنفيذ النشاط.',
      'aiNote': 'تحتاج الصورة لمراجعة بشرية للتأكد من التغيير.',
      'evidence': [],
      'createdAt': '${day}T10:00:00'
    },
    {
      'id': 12,
      'kind': 'EXCUSE',
      'memberId': 2,
      'memberName': 'عضو آخر',
      'about': 'جلسة القراءة',
      'details': 'ظرف صحي',
      'aiNote': 'تعذر التحليل الآلي؛ يرجى مراجعة المرفق.',
      'evidence': [],
      'createdAt': '${day}T11:00:00'
    },
  ];
  final sessions = <int, Map<String, dynamic>>{};
  ProofsFakeApi({this.empty = false});
  dynamic clone(dynamic value) => jsonDecode(jsonEncode(value));

  Map<String, dynamic> session(int id) => sessions.putIfAbsent(
      id,
      () => {
            'proof': {
              'id': id,
              'type': id == 102
                  ? 'QUIZ'
                  : id == 103
                      ? 'PHOTO'
                      : 'TIMER',
              'result': 'PENDING',
              'processingStatus': 'WAITING',
              'beforeAfterEnabled': false,
              'attemptDeadline': '${day}T23:59:59',
              'evidenceData': 'Waiting'
            },
            'weekId': id - 100,
            'goalTaskId': null,
            'evidence': [
              {
                'type': id == 102
                    ? 'QUIZ'
                    : id == 103
                        ? 'PHOTO'
                        : 'TIMER',
                'result': 'PENDING'
              }
            ],
            'timer': id != 101
                ? null
                : {
                    'id': 101,
                    'requiredSeconds': 1500,
                    'elapsedSeconds': 540,
                    'extensionSeconds': 0,
                    'lastStartedAt': DateTime.now().toIso8601String(),
                    'deadline': '${day}T23:59:59',
                    'requiredReachedAt': null,
                    'status': 'RUNNING',
                    'feedback': null,
                    'messages':
                        'بداية موفقة، على راحتك.\nوصلتِ للنص، كملي بالوتيرة اللي تناسبك.\nكفو، أنجزتِ وقتك. ترتاحين أو تمددين؟'
                  },
          });
  @override
  Future<dynamic> get(String path, {Map<String, Object?>? query}) async {
    if (path.endsWith('/proof-workspace/my')) return clone(workspace);
    if (path.endsWith('/commitment-week/today')) {
      return empty ? [] : clone(tasks);
    }
    if (path.contains('/proof-attempt/suggest/')) {
      return {'suggestedMinutes': 25};
    }
    if (RegExp(r'/proof-attempt/\d+$').hasMatch(path)) {
      return clone(session(int.parse(path.split('/').last)));
    }
    if (path.contains('/penalty/my/') ||
        path.contains('/admin-review/penalties/')) {
      return clone(penalties);
    }
    if (path.contains('/donation-proof/my/')) return [];
    if (path.contains('/admin-review/queue/')) return clone(queue);
    if (path.contains('/commitment/lockStatus')) {
      return {'totalToDonate': 20, 'penalties': penalties, 'isLocked': false};
    }
    if (path.endsWith('/member/profile')) {
      return {
        'id': 1,
        'name': 'عضو تجريبي',
        'emailLinked': false,
        'isLocked': false
      };
    }
    return [];
  }

  @override
  Future<dynamic> post(String path,
      {Object? body, Map<String, Object?>? query, bool auth = true}) async {
    posts.add(path);
    if (path.contains('/proof-attempt/start/')) {
      final id = 100 + int.parse(path.split('/').last);
      return session(id)['proof'];
    }
    if (path.endsWith('/state') && path.contains('/timer/')) {
      return clone(session(101)['timer']);
    }
    if (path.contains('/timer/')) {
      final timer = session(101)['timer'] as Map;
      final action = path.split('/').last;
      if (action == 'pause' || action == 'finish') {
        timer['status'] = 'PAUSED';
        timer['lastStartedAt'] = null;
      }
      if (action == 'resume') {
        timer['status'] = 'RUNNING';
        timer['lastStartedAt'] = DateTime.now().toIso8601String();
      }
      return clone(timer);
    }
    if (path.contains('/quiz/create/')) {
      return {
        'quizId': 44,
        'topic': 'القراءة',
        'howToAnswer': '',
        'questions': [
          for (var i = 1; i <= 4; i++)
            {
              'number': i,
              'question': [
                'ما الذي يساعد على فهم النص؟',
                'كيف تستفيدين من ملخص الفصل؟',
                'متى تراجعين فكرة غير واضحة؟',
                'ما أفضل طريقة لتذكر ما قرأتِ؟'
              ][i - 1],
              'options': [
                'A) تدوين الأفكار الأساسية',
                'B) تجاوز كل التفاصيل',
                'C) قراءة العنوان فقط'
              ]
            },
        ]
      };
    }
    if (path.endsWith('/submit')) {
      final id = int.parse(path.split('/')[4]);
      session(id)['proof']['result'] = 'ACCEPTED';
      session(id)['evidence'][0]['result'] = 'ACCEPTED';
    }
    return {'message': 'Done'};
  }

  @override
  Future<dynamic> put(String path,
          {Object? body, Map<String, Object?>? query}) async =>
      {'message': 'Done'};
  @override
  Future<dynamic> delete(String path, {Map<String, Object?>? query}) async =>
      {'message': 'Done'};
}

class ProofsFakeAuth extends AuthState {
  ProofsFakeAuth(super.api, {bool admin = false}) {
    role = admin ? Role.admin : Role.member;
    profile = {
      'id': 1,
      'name': 'عضو تجريبي',
      'isLocked': false,
      'emailLinked': false
    };
  }
}
