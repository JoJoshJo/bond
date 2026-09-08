import 'package:flutter/foundation.dart';

/// Today's prompt for the couple.
@immutable
class DailyPrompt {
  const DailyPrompt({
    required this.id,
    required this.content,
    required this.category,
    required this.generatedAt,
  });

  final String id;
  final String content;
  final String category;
  final DateTime generatedAt;

  factory DailyPrompt.fromRow(Map<String, dynamic> row) => DailyPrompt(
        id: row['id'] as String,
        content: row['content'] as String,
        category: (row['category'] as String?) ?? 'reflection',
        generatedAt: DateTime.parse(row['generated_at'] as String),
      );
}

/// A partner's answer, plus any reactions on it.
@immutable
class PromptResponse {
  const PromptResponse({
    required this.id,
    required this.promptId,
    required this.userId,
    required this.response,
    required this.answeredAt,
    this.reactions = const [],
  });

  final String id;
  final String promptId;
  final String userId;
  final String response;
  final DateTime answeredAt;
  final List<PromptReaction> reactions;

  factory PromptResponse.fromRow(Map<String, dynamic> row) {
    final raw = row['prompt_response_reactions'];
    final reactions = switch (raw) {
      final List<dynamic> l => l
          .map((r) => PromptReaction(
                userId: (r as Map<String, dynamic>)['user_id'] as String,
                emoji: r['emoji'] as String,
              ))
          .toList(),
      _ => <PromptReaction>[],
    };
    return PromptResponse(
      id: row['id'] as String,
      promptId: row['prompt_id'] as String,
      userId: row['user_id'] as String,
      response: (row['response'] as String?) ?? '',
      answeredAt: DateTime.parse(row['answered_at'] as String),
      reactions: reactions,
    );
  }
}

@immutable
class PromptReaction {
  const PromptReaction({required this.userId, required this.emoji});
  final String userId;
  final String emoji;
}

/// The four UI phases, derived from responses under the mutual-lock RLS.
enum PromptPhase { loading, answer, waiting, revealed }
