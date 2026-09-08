import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_models.dart';

/// The app's ONLY entry point to AI. Calls our `ai-router` Edge Function — never
/// a provider directly. The user's JWT is attached automatically by invoke(), so
/// the function stays authenticated-only; the provider key never reaches the app.
class AiRepository {
  AiRepository(this._client);

  final SupabaseClient _client;

  /// Ask the router for a given job. `job` is 'assistant' | 'personality' |
  /// 'content'; the provider is chosen server-side by config.
  Future<AiResponse> getAI(
    String job,
    String prompt, {
    Map<String, dynamic> context = const {},
  }) async {
    final res = await _client.functions.invoke(
      'ai-router',
      body: {'job': job, 'prompt': prompt, 'context': context},
    );

    final data = res.data;
    if (data is! Map) {
      throw Exception('Unexpected AI response: $data');
    }
    final map = data.cast<String, dynamic>();
    if (map['error'] != null) {
      throw Exception('AI error: ${map['error']} ${map['detail'] ?? ''}'.trim());
    }
    return AiResponse.fromJson(map);
  }
}
