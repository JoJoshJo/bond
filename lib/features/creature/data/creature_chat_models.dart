import 'package:flutter/foundation.dart';

import '../../ai/data/ai_models.dart';

/// One turn in the creature conversation. Ephemeral (session-only, not stored).
/// A creature turn may carry [movies] (tool-use result cards).
@immutable
class CreatureChatMessage {
  const CreatureChatMessage({
    required this.fromCreature,
    required this.text,
    this.thinking = false,
    this.movies = const [],
    this.places = const [],
  });

  final bool fromCreature; // true = creature, false = the couple
  final String text;
  final bool thinking; // a transient "…" placeholder while awaiting a reply
  final List<MovieCard> movies;
  final List<PlaceCard> places;

  CreatureChatMessage copyWith({
    String? text,
    bool? thinking,
    List<MovieCard>? movies,
    List<PlaceCard>? places,
  }) =>
      CreatureChatMessage(
        fromCreature: fromCreature,
        text: text ?? this.text,
        thinking: thinking ?? this.thinking,
        movies: movies ?? this.movies,
        places: places ?? this.places,
      );
}
