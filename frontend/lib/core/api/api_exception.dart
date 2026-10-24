// an error from the backend: the status code and the message ({"message": "..."})
class ApiException implements Exception {
  final int status; // 0 = the server could not be reached
  final String message;

  ApiException(this.status, this.message);

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;

  @override
  String toString() => message;
}
