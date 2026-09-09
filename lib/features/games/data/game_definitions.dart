import 'package:flutter/material.dart';

/// One round: a question + the options a player picks from.
class GameRound {
  const GameRound(this.question, this.options);
  final String question;
  final List<String> options;
}

/// A game plugged into the engine: metadata + its rounds. Every game here uses
/// the same primitive (pick one option per round), which is exactly why adding a
/// new one is content-only. Scored variants (e.g. Prediction) come later.
class GameDefinition {
  const GameDefinition({
    required this.type,
    required this.title,
    required this.tagline,
    required this.icon,
    required this.xp,
    this.rounds = const [],
    this.board = false,
    this.skill = false,
    this.spicy = false,
    this.shots = 5,
  });

  final String type; // matches game_sessions.game_type
  final String title;
  final String tagline;
  final IconData icon;
  final List<GameRound> rounds;
  final int xp; // awarded on completion
  final bool board; // true = a turn-based board game (not round-based)
  final bool skill; // true = a solo-scored skill/timing game (compare scores)
  final bool spicy; // true = only shown while spicy mode is active
  final int shots; // skill games: attempts per player

  int get roundCount => rounds.length;
}

/// The launch catalog: engine + 3 games (async-first). Others are fast-follows.
class GameCatalog {
  const GameCatalog._();

  static const wouldYouRather = GameDefinition(
    type: 'would_you_rather',
    title: 'Would You Rather',
    tagline: 'Pick one — see how you match',
    icon: Icons.alt_route_rounded,
    xp: 20,
    rounds: [
      GameRound('Would you rather…', ['A cozy night in', 'A night out']),
      GameRound('Would you rather…', ['Beach holiday', 'Mountain cabin']),
      GameRound('Would you rather…', ['Breakfast in bed', 'Sunrise walk']),
      GameRound('Would you rather…', ['Read the book', 'Watch the film']),
      GameRound('Would you rather…', ['Plan everything', 'Go with the flow']),
    ],
  );

  static const thisOrThat = GameDefinition(
    type: 'this_or_that',
    title: 'This or That',
    tagline: 'Quick-fire preferences',
    icon: Icons.swap_horiz_rounded,
    xp: 15,
    rounds: [
      GameRound('Pick your side', ['Coffee', 'Tea']),
      GameRound('Pick your side', ['Sweet', 'Savory']),
      GameRound('Pick your side', ['Early bird', 'Night owl']),
      GameRound('Pick your side', ['Cats', 'Dogs']),
      GameRound('Pick your side', ['Text', 'Call']),
      GameRound('Pick your side', ['Save it', 'Spend it']),
    ],
  );

  static const coupleQuiz = GameDefinition(
    type: 'couple_quiz',
    title: 'Couple Quiz',
    tagline: 'How aligned are you?',
    icon: Icons.favorite_rounded,
    xp: 25,
    rounds: [
      GameRound('Ideal weekend together?',
          ['Adventure out', 'Relax at home', 'See friends', 'Try something new']),
      GameRound('Best kind of date night?',
          ['Dinner out', 'Movie & snacks', 'Cook together', 'Something active']),
      GameRound('Love language you lean to?',
          ['Words', 'Quality time', 'Touch', 'Little gifts']),
      GameRound('A dream trip would be…',
          ['A big city', 'Nature escape', 'By the sea', 'Road trip']),
      GameRound('How do you recharge?',
          ['Alone time', 'Together time', 'With friends', 'Get outside']),
    ],
  );

  // ---- Turn-based board games (live-preferred, async-tolerant) ----
  static const fourInARow = GameDefinition(
    type: 'four_in_a_row',
    title: 'Four in a Row',
    tagline: 'Drop discs, connect four',
    icon: Icons.grid_4x4_rounded,
    xp: 20,
    board: true,
  );
  static const ticTacToe = GameDefinition(
    type: 'tic_tac_toe',
    title: 'Tic-Tac-Toe',
    tagline: 'Three in a row wins',
    icon: Icons.tag_rounded,
    xp: 15,
    board: true,
  );
  static const dotsAndBoxes = GameDefinition(
    type: 'dots_and_boxes',
    title: 'Dots & Boxes',
    tagline: 'Claim the most boxes',
    icon: Icons.border_all_rounded,
    xp: 20,
    board: true,
  );

  // ---- Skill games (solo-scored, compare when both have played) ----
  static const targetShot = GameDefinition(
    type: 'target_shot',
    title: 'Target Shot',
    tagline: 'Steady your aim — hit the bullseye',
    icon: Icons.gps_fixed_rounded,
    xp: 20,
    skill: true,
    shots: 5,
  );
  static const freeThrows = GameDefinition(
    type: 'free_throws',
    title: 'Free Throws',
    tagline: 'Time it right — swish it',
    icon: Icons.sports_basketball_rounded,
    xp: 20,
    skill: true,
    shots: 5,
  );

  // ---- Spicy games (only shown while spicy mode is active; suggestive, not
  // explicit — tasteful heat). All reuse the round engine (content-only). ----
  static const spicyWouldYouRather = GameDefinition(
    type: 'spicy_would_you_rather',
    title: 'Spicy Would You Rather',
    tagline: 'Turn up the heat 🌶️',
    icon: Icons.local_fire_department_rounded,
    xp: 20,
    spicy: true,
    rounds: [
      GameRound('Would you rather…',
          ['A slow dance in the dark', 'A long kiss in the rain']),
      GameRound('Would you rather…',
          ['Breakfast in bed together', 'A midnight rendezvous']),
      GameRound('Would you rather…',
          ['A candlelit bath', 'A massage by firelight']),
      GameRound('Would you rather…',
          ['Whisper a secret', 'Steal a bold kiss']),
      GameRound('Would you rather…',
          ['A weekend never leaving the room', 'A night out that ends close']),
    ],
  );

  static const spicyThisOrThat = GameDefinition(
    type: 'spicy_this_or_that',
    title: 'Spicy This or That',
    tagline: 'Quick-fire, a little flirty',
    icon: Icons.whatshot_rounded,
    xp: 15,
    spicy: true,
    rounds: [
      GameRound('Pick your vibe', ['Lights on', 'Lights off']),
      GameRound('Pick your vibe', ['Tease', 'Please']),
      GameRound('Pick your vibe', ['Slow', 'Fast']),
      GameRound('Pick your vibe', ['Silk', 'Lace']),
      GameRound('Pick your vibe', ['Give', 'Receive']),
      GameRound('Pick your vibe', ['Morning', 'Midnight']),
    ],
  );

  static const heatCheck = GameDefinition(
    type: 'heat_check',
    title: 'Heat Check',
    tagline: 'How well do you match tonight?',
    icon: Icons.favorite_rounded,
    xp: 25,
    spicy: true,
    rounds: [
      GameRound('Tonight, you\'re craving…',
          ['Romance', 'Playfulness', 'Passion', 'Closeness']),
      GameRound('Set the scene',
          ['Candles & wine', 'Music & dancing', 'Just us, no plan', 'A getaway']),
      GameRound('Your move is…',
          ['Make the first move', 'Be pursued', 'Meet in the middle', 'Tease first']),
      GameRound('The mood is…',
          ['Slow & tender', 'Bold & fiery', 'Fun & giggly', 'Deep & intense']),
      GameRound('End the night…',
          ['Tangled up together', 'Talking till late', 'Already planning round two', 'Fast asleep close']),
    ],
  );

  static const round = [wouldYouRather, thisOrThat, coupleQuiz];
  static const boards = [fourInARow, ticTacToe, dotsAndBoxes];
  static const skills = [targetShot, freeThrows];
  static const spicyGames = [spicyWouldYouRather, spicyThisOrThat, heatCheck];
  static const all = [...round, ...boards, ...skills, ...spicyGames];

  /// The games to show in the hub given spicy mode. Spicy games appear only
  /// while spicy is active (alongside the normal catalog).
  static List<GameDefinition> forHub({required bool spicy}) =>
      spicy ? all : all.where((g) => !g.spicy).toList();

  static GameDefinition byType(String type) =>
      all.firstWhere((g) => g.type == type, orElse: () => wouldYouRather);
}
