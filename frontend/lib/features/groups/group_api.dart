import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/config.dart';

// all the group endpoints in one place (Fai)
class GroupApi {
  final ApiClient api;

  GroupApi(this.api);

  // the photo and video links always go to the server the app uses now
  // (the seed saves /uploads/..., and an old link keeps the address of the network it was taken on)
  static String media(Object? url) {
    final link = '${url ?? ''}';
    final i = link.indexOf('/uploads/');
    return i < 0 ? link : '${AppConfig.baseUrl}${link.substring(i)}';
  }

  static const _g = '/api/v1/group';
  static const _gm = '/api/v1/group-member';
  static const _goal = '/api/v1/group-goal';
  static const _prop = '/api/v1/goal-proposal';
  static const _chat = '/api/v1/chat-message';
  static const _alert = '/api/v1/group-alert';
  static const _moment = '/api/v1/moment';

  // ---------- groups ----------
  Future<List<Map<String, dynamic>>> myGroups() async => _list(await api.get('$_gm/my'));
  Future<Map<String, dynamic>> group(int id) async => _map(await api.get('$_g/get/$id'));
  Future<Map<String, dynamic>> create(String name, String description) async =>
      _map(await api.post('$_g/add', body: {'name': name, 'description': description}));
  Future<void> update(int id, String name, String description) =>
      api.put('$_g/update/$id', body: {'name': name, 'description': description});
  Future<Map<String, dynamic>> invite(int id) async => _map(await api.get('$_g/invite/$id'));
  Future<Map<String, dynamic>> resetInvite(int id) async => _map(await api.put('$_g/resetInvite/$id'));
  Future<void> archive(int id) => api.delete('$_g/delete/$id');

  // ---------- members ----------
  Future<List<Map<String, dynamic>>> members(int groupId) async => _list(await api.get('$_gm/group/$groupId'));
  Future<void> join(String code) => api.post('$_gm/join/${Uri.encodeComponent(code.trim())}');
  Future<void> addMember(int groupId, int memberId) => api.post('$_gm/add/$groupId/$memberId');
  Future<void> addMemberByPhone(int groupId, String phone) => api.post('$_gm/addByPhone/$groupId', body: {'phone': phone});
  Future<void> leave(int groupId) => api.delete('$_gm/leave/$groupId');

  // ---------- goal ----------
  // null when the group has no goal now (the server answers 400)
  Future<Map<String, dynamic>?> activeGoal(int groupId) async {
    try {
      return _map(await api.get('$_goal/active/$groupId'));
    } on ApiException catch (e) {
      if (e.status == 400) return null;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> goalHistory(int groupId) async => _list(await api.get('$_goal/history/$groupId'));
  Future<List<Map<String, dynamic>>> board(int groupId) async => _list(await api.get('$_goal/board/$groupId'));
  Future<void> setGoal(int groupId, Map<String, Object?> body) => api.post('$_goal/add/$groupId', body: body);
  // the AI splits the goal on the weeks (the same task and times for every member in a week), nothing is saved
  Future<Map<String, dynamic>> suggestPlan(int groupId, String goal, DateTime endDate) async => _map(await api.post(
        '$_goal/suggest/$groupId',
        body: {'goal': goal, 'endDate': endDate.toIso8601String().substring(0, 10)},
      ));

  // LOCATION goal: my own place (null until I choose it), chosen from the Google search
  Future<Map<String, dynamic>?> myPlace(int groupId) async {
    final data = await api.get('$_goal/my-place/$groupId');
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> setMyPlace(int groupId, Map<String, dynamic> place) => api.put('$_goal/my-place/$groupId', body: {
        'latitude': place['latitude'],
        'longitude': place['longitude'],
        'placeName': '${place['name'] ?? ''}'.length > 100 ? '${place['name']}'.substring(0, 100) : place['name'],
      });

  Future<List<Map<String, dynamic>>> searchPlaces(String query, {double? lat, double? lng}) async =>
      _list(await api.get('/api/v1/place/search', query: {'query': query, 'lat': lat, 'lng': lng}));

  // ---------- proposals ----------
  Future<List<Map<String, dynamic>>> proposals(int groupId) async => _list(await api.get('$_prop/open/$groupId'));
  Future<void> propose(int groupId, String title, String details) =>
      api.post('$_prop/add/$groupId', body: {'title': title, 'details': details});
  Future<void> aiProposals(int groupId) => api.post('$_prop/ai/$groupId');
  Future<void> vote(int proposalId) => api.put('$_prop/vote/$proposalId');
  Future<void> reject(int proposalId) => api.put('$_prop/reject/$proposalId');

  // ---------- chat ----------
  Future<List<Map<String, dynamic>>> messages(int groupId) async => _list(await api.get('$_chat/get/$groupId'));
  Future<void> send(int groupId, String content) => api.post('$_chat/send/$groupId', body: {'content': content});
  Future<void> deleteMessage(int messageId) => api.delete('$_chat/delete/$messageId');

  // ---------- alerts ----------
  Future<Map<String, dynamic>> sendAlert(int groupId, int receiverId) async =>
      _map(await api.post('$_alert/send/$groupId/$receiverId'));
  Future<List<Map<String, dynamic>>> myAlertsToday(int groupId) async => _list(await api.get('$_alert/today/$groupId'));

  // ---------- moments ----------
  Future<List<Map<String, dynamic>>> groupMoments(int groupId) async => _list(await api.get('$_moment/group/$groupId'));
  Future<List<Map<String, dynamic>>> myMoments() async => _list(await api.get('$_moment/my'));
  Future<void> addMoment(Map<String, Object?> body) => api.post('$_moment/add', body: body);
  // uploads the photo / video from the camera, returns its link
  Future<String> uploadMedia(String filePath) async {
    final data = await api.upload('$_moment/upload', filePath);
    final url = data is Map ? data['url'] : null;
    if (url == null) throw ApiException(0, 'ما انرفع الملف، حاول مرة ثانية.');
    return '$url';
  }
  Future<void> deleteMoment(int momentId) => api.delete('$_moment/delete/$momentId');

  // ---------- the week: settlement and titles ----------
  Future<List<Map<String, dynamic>>> settlements(int groupId) async =>
      _list(await api.get('/api/v1/group-settlement/get/$groupId'));
  Future<List<Map<String, dynamic>>> latestTitles(int groupId) async =>
      _list(await api.get('/api/v1/group-title/latest/$groupId'));
  Future<List<Map<String, dynamic>>> titlesHistory(int groupId) async =>
      _list(await api.get('/api/v1/group-title/history/$groupId'));

  static List<Map<String, dynamic>> _list(dynamic data) =>
      data is List ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];

  static Map<String, dynamic> _map(dynamic data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
}
