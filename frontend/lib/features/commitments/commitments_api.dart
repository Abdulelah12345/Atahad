import '../../core/api/api_client.dart';

typedef JsonMap = Map<String, dynamic>;

// OWNER: Turki - every call of the commitments part (the member comes from the login, never from the URL)
class CommitmentsApi {
  final ApiClient client;

  CommitmentsApi(this.client);

  static const _base = '/api/v1';

  // home and stats
  Future<List<JsonMap>> today() async => _list(await client.get('$_base/commitment-week/today'));

  Future<JsonMap> stats() async => _map(await client.get('$_base/commitment/stats'));

  // the running week of a habit (its plannedDays is this week plan)
  Future<JsonMap> currentWeek(int commitmentId) async =>
      _map(await client.get('$_base/commitment-week/getCurrent/$commitmentId'));

  // postpone inside this week, it only moves the reminders
  // a goal moves the days of one of its tasks (goalTaskId)
  Future<void> changeWeekPlan(int weekId, Set<String> plannedDays, {int? goalTaskId}) =>
      client.put('$_base/commitment-week/changePlan/$weekId',
          query: goalTaskId == null ? null : {'goalTaskId': goalTaskId}, body: plannedDays.toList());

  // withdraw from a habit or a goal: it ends when this week ends
  Future<String> withdraw(int id) async => _message(await client.put('$_base/commitment/withdraw/$id'));

  Future<void> cancelWithdraw(int id) => client.put('$_base/commitment/withdraw/cancel/$id');

  // the place of a LOCATION commitment or the minutes of a TIMER one
  Future<void> setTarget(int id, JsonMap body) => client.put('$_base/commitment/target/$id', body: body);

  // habits
  Future<List<JsonMap>> habits() async => _list(await client.get('$_base/habit/getMyHabits'));

  Future<void> addHabit(JsonMap body) => client.post('$_base/habit/add', body: body);

  Future<void> updateHabit(int id, JsonMap body) => client.put('$_base/habit/update/$id', body: body);

  Future<void> deleteHabit(int id) => client.delete('$_base/habit/delete/$id');

  // goals
  Future<List<JsonMap>> goals() async => _list(await client.get('$_base/goal/getMyGoals'));

  // the AI plan, nothing is saved
  Future<JsonMap> suggestPlan(String goal, DateTime endDate, {DateTime? startDate}) async => _map(await client.post('$_base/goal/suggest',
      body: {'goal': goal, 'endDate': isoDate(endDate), if (startDate != null) 'startDate': isoDate(startDate)}));

  // saves the plan and starts the goal
  Future<JsonMap> addWithPlan(JsonMap body) async => _map(await client.post('$_base/goal/addWithPlan', body: body));

  Future<JsonMap> progress(int id) async => _map(await client.get('$_base/goal/progress/$id'));

  Future<List<JsonMap>> goalTasks(int id) async => _list(await client.get('$_base/goal-task/getByGoal/$id'));

  Future<void> deleteGoal(int id) => client.delete('$_base/goal/delete/$id');

  // grace days and points
  Future<List<JsonMap>> graceDays() async => _list(await client.get('$_base/grace-day/my'));

  // 150 points -> one grace day
  Future<JsonMap> earnGraceDay() async => _map(await client.post('$_base/grace-day/earn'));

  // use a grace day by hand on a habit week, it counts as an excused time
  Future<void> useGraceDay(int graceDayId, int weekId) => client.put('$_base/grace-day/use/$graceDayId/$weekId');

  Future<List<JsonMap>> pointLogs() async => _list(await client.get('$_base/point-log/my'));

  // Monthly Wrapped
  Future<List<JsonMap>> wrapped() async => _list(await client.get('$_base/monthly-wrapped/my'));

  Future<JsonMap> generateWrapped(String month) async =>
      _map(await client.post('$_base/monthly-wrapped/generate/$month'));

  static List<JsonMap> _list(dynamic data) =>
      data is List ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <JsonMap>[];

  static JsonMap _map(dynamic data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  static String _message(dynamic data) => data is Map && data['message'] != null ? '${data['message']}' : 'تم';
}

// 2026-10-25, the way the backend reads a LocalDate
String isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

// 2026-10, the month of the Monthly Wrapped
String isoMonth(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';
