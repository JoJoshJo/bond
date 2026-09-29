import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_models.dart';

/// The app's ONLY entry point to AI. Calls our `ai-router` Edge Function — never
/// a provider directly. The user's JWT is attached automatically by invoke(), so
/// the function stays authenticated-only; the provider key never reaches the app.
class AiRepository {
  AiRepository(this._client);

  final SupabaseClient _client;

  /// Hard ceiling on a router call. The function's own budget is ~48s, so this
  /// only fires when the request itself is stuck; callers show their existing
  /// friendly fallback rather than spinning forever.
  static const Duration _timeout = Duration(seconds: 55);

  /// Ask the router for a given job. `job` is 'assistant' | 'personality' |
  /// 'content'; the provider is chosen server-side by config.
  Future<AiResponse> getAI(
    String job,
    String prompt, {
    Map<String, dynamic> context = const {},
    List<Map<String, String>> history = const [],
  }) async {
    final res = await _client.functions.invoke(
      'ai-router',
      body: {
        'job': job,
        'prompt': prompt,
        'context': context,
        // Short conversation memory (creature chat) — only sent when present.
        if (history.isNotEmpty) 'history': history,
      },
    ).timeout(_timeout);

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
