import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_exception.dart';

// the only place that talks to the backend. Everybody uses it like this:
//   final api = context.read<ApiClient>();
//   final list = await api.get('/api/v1/habit/getMyHabits');
//   await api.post('/api/v1/habit/add', body: {...});
// it sends the login (Basic Auth) and the session cookie with every request,
// and turns any error into an ApiException with the message from the server
class ApiClient {
  final http.Client _http = http.Client();
  String? _basic;
  String? _cookie; // JSESSIONID, some parts keep data in the session (Google Calendar)

  // set by AuthState
  void Function()? onUnauthorized; // 401: the login is not valid anymore
  void Function(String message)? onForbidden; // 403: maybe the app got locked

  static const _timeout = Duration(seconds: 90); // the AI calls can take time

  void setCredentials(String email, String password) {
    _basic = 'Basic ${base64Encode(utf8.encode('$email:$password'))}';
  }

  void clearCredentials() {
    _basic = null;
    _cookie = null;
  }

  Future<dynamic> get(String path, {Map<String, Object?>? query}) => _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, Object?>? query, bool auth = true}) =>
      _send('POST', path, body: body, query: query, auth: auth);

  Future<dynamic> put(String path, {Object? body, Map<String, Object?>? query}) =>
      _send('PUT', path, body: body, query: query);

  Future<dynamic> delete(String path, {Map<String, Object?>? query}) => _send('DELETE', path, query: query);

  Future<dynamic> _send(String method, String path,
      {Object? body, Map<String, Object?>? query, bool auth = true}) async {
    var uri = Uri.parse('${AppConfig.baseUrl}$path');
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null) params[key] = '$value';
    });
    if (params.isNotEmpty) uri = uri.replace(queryParameters: params);

    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    if (auth && _basic != null) request.headers['Authorization'] = _basic!;
    if (_cookie != null) request.headers['Cookie'] = _cookie!;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } catch (_) {
      throw ApiException(0, 'ما قدرنا نوصل للسيرفر. تأكد من الاتصال وحاول مرة ثانية.');
    }

    _keepCookie(response.headers['set-cookie']);
    final text = utf8.decode(response.bodyBytes);
    final data = _json(text);

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final message = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : 'صار خطأ (${response.statusCode})، حاول مرة ثانية.';
    if (response.statusCode == 401 && auth && _basic != null) onUnauthorized?.call();
    if (response.statusCode == 403) onForbidden?.call(message);
    throw ApiException(response.statusCode, message);
  }

  dynamic _json(String text) {
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return text; // a plain text answer
    }
  }

  void _keepCookie(String? setCookie) {
    if (setCookie == null) return;
    final match = RegExp(r'JSESSIONID=([^;,\s]+)').firstMatch(setCookie);
    if (match != null) _cookie = 'JSESSIONID=${match.group(1)}';
  }
}
