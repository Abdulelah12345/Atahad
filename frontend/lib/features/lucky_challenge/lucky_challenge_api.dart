
import '../../core/api/api_client.dart';

class LuckyChallengeApi {
  final ApiClient api;

  LuckyChallengeApi(this.api);

  Future<Map<String, dynamic>> randomChallenge(String difficulty) async {
    final result = await api.post(
      '/api/v1/lucky-challenge/random/$difficulty',
      body: {},
    );
    return Map<String, dynamic>.from(result);
  }

  Future<void> acceptChallenge(int challengeId) async {
    await api.post('/api/v1/lucky-challenge/accept/$challengeId', body: {});
  }

  Future<Map<String, dynamic>> getMyChallenge() async {
    final result = await api.get('/api/v1/lucky-challenge/my');
    return Map<String, dynamic>.from(result);
  }

  Future<String> submitProof(int challengeId, String proofImage) async {
    final result = await api.post(
      '/api/v1/lucky-challenge/proof/$challengeId',
      body: {'proofImage': proofImage},
    );
    return result['message'].toString();
  }
}
