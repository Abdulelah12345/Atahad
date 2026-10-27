import '../../core/api/api_client.dart';

class LearnResource {
  final String title;
  final String type;
  final String creator;
  final String description;
  final String? imageUrl;
  final String source;
  final String? url;

  const LearnResource({
    required this.title,
    required this.type,
    required this.creator,
    required this.description,
    required this.imageUrl,
    required this.source,
    required this.url,
  });

  factory LearnResource.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString();
    String? optional(String key) {
      final value = str(key).trim();
      return value.isEmpty || value.toLowerCase() == 'null' ? null : value;
    }

    return LearnResource(
      title: str('title'),
      type: str('type').toUpperCase(),
      creator: str('creator'),
      description: str('description'),
      imageUrl: optional('imageUrl'),
      source: str('source'),
      url: optional('url'),
    );
  }
}

class LearnQuestApi {
  final ApiClient api;
  LearnQuestApi(this.api);

  Future<List<LearnResource>> search(String query, {String type = 'all'}) async {
    final endpoint = switch (type) {
      'books' => 'books',
      'podcasts' => 'podcasts',
      'courses' => 'courses',
      _ => 'search',
    };
    final result = await api.get(
      '/api/v1/learn-quest/$endpoint',
      query: {'query': query.trim()},
    );
    if (result is! List) {
      throw const FormatException('Unexpected learning resources response');
    }
    return result
        .map((item) => LearnResource.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((item) => item.title.trim().isNotEmpty)
        .toList();
  }
}
