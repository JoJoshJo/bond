import 'package:flutter/foundation.dart';

import '../../ai/data/ai_models.dart';

/// Where a proposed calendar change stands.
enum ProposalStatus { pending, applying, applied, declined, failed }

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
    this.proposal,
    this.proposalStatus = ProposalStatus.pending,
    this.showUpgrade = false,
    this.proposalError,
  });

  final bool fromCreature; // true = creature, false = the couple
  final String text;
  final bool thinking; // a transient "…" placeholder while awaiting a reply
  final List<MovieCard> movies;
  final List<PlaceCard> places;

  /// A calendar change awaiting Yes/No (shown as a confirmation card).
  final CalendarProposal? proposal;
  final ProposalStatus proposalStatus;

  /// Show the existing Usora+ upgrade button under this turn.
  final bool showUpgrade;

  /// DEV ONLY: the raw error when a confirmed change failed to save.
  final String? proposalError;

  CreatureChatMessage copyWith({
    String? text,
    bool? thinking,
    List<MovieCard>? movies,
    List<PlaceCard>? places,
    ProposalStatus? proposalStatus,
    String? proposalError,
  }) =>
      CreatureChatMessage(
        fromCreature: fromCreature,
        text: text ?? this.text,
        thinking: thinking ?? this.thinking,
        movies: movies ?? this.movies,
        places: places ?? this.places,
        proposal: proposal,
        proposalStatus: proposalStatus ?? this.proposalStatus,
        showUpgrade: showUpgrade,
        proposalError: proposalError ?? this.proposalError,
      );
}
