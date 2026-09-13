import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ai/data/ai_repository.dart';
import 'insights_models.dart';

/// Reads the couple's relationship stats (extended `get_connection_snapshot`)
/// and asks the creature to write a warm reflection over them.
class InsightsRepository {
  InsightsRepository(this._client, this._ai);

  final SupabaseClient _client;
  final AiRepository _ai;

  Future<InsightsStats> fetchStats() async {
    final rows = await _client.rpc('get_connection_snapshot') as List<dynamic>;
    if (rows.isEmpty) {
      return const InsightsStats(
        bondScore: 0,
        activeDays7: 0,
        memoriesCount: 0,
        promptsAnswered: 0,
        gamesPlayed: 0,
        messagesCount: 0,
      );
    }
    return InsightsStats.fromRow(rows.first as Map<String, dynamic>);
  }

  /// Generate a warm 2-paragraph reflection over the stats, in Usora's creature
  /// voice (reuses the `creature` AI job — no ai-router redeploy).
  Future<String> generateNarrative(InsightsStats s, String coupleName) async {
    final facts = <String>[
      if (s.daysTogether != null) '${s.daysTogether} days together',
      'bond score ${s.bondScore} (${s.stageLabel} stage)',
      '${s.memoriesCount} memories saved',
      '${s.promptsAnswered} daily prompts answered',
      '${s.gamesPlayed} games played together',
      '${s.messagesCount} messages exchanged',
      'active ${s.activeDays7} of the last 7 days',
    ].join(', ');

    final prompt = '''
Write a warm, personal reflection for the couple called "$coupleName", looking back
on their bond so far. Here is their story in numbers: $facts.

Voice: you are Usora, their companion creature — speak TO them as "you two", warm and
a little poetic, genuinely moved by how they show up for each other. Two short
paragraphs, at most ~4 sentences total. Weave in one or two of the numbers naturally
(don't list them all, don't make it a stats report). No bullet points, no headings.
At most one emoji. Make them feel seen. Reply with ONLY the reflection.''';

    // Pass the same shape of context the creature chat sends, for consistency.
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final res = await _ai.getAI('creature', prompt,
        context: {'coupleName': coupleName, 'today': today});
    return res.text.trim();
  }
}
