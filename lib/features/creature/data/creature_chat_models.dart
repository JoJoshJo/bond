import 'package:flutter/foundation.dart';

/// One turn in the creature conversation. Ephemeral (session-only, not stored).
@immutable
class CreatureChatMessage {
  const CreatureChatMessage({
    required this.fromCreature,
    required this.text,
    this.thinking = false,
  });

  final bool fromCreature; // true = creature, false = the couple
  final String text;
  final bool thinking; // a transient "…" placeholder while awaiting a reply

  CreatureChatMessage copyWith({String? text, bool? thinking}) =>
      CreatureChatMessage(
        fromCreature: fromCreature,
        text: text ?? this.text,
        thinking: thinking ?? this.thinking,
      );
}
