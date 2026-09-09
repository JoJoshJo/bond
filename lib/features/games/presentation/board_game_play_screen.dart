import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/board_game_controller.dart';
import '../data/board_models.dart';
import '../data/engines/connect_four_engine.dart';
import '../data/engines/dots_and_boxes_engine.dart';
import '../data/engines/tic_tac_toe_engine.dart';
import '../data/game_definitions.dart';
import 'boards/board_colors.dart';
import 'boards/connect_four_board.dart';
import 'boards/dots_and_boxes_board.dart';
import 'boards/tic_tac_toe_board.dart';

/// Shared chrome for the turn-based board games: turn banner, the board, and a
/// result overlay + XP. Switches on game_type for the board widget.
class BoardGamePlayScreen extends ConsumerWidget {
  const BoardGamePlayScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boardGameControllerProvider(sessionId));
    final controller = ref.read(boardGameControllerProvider(sessionId).notifier);
    final def = GameCatalog.byType(state.gameType);

    if (state.loading) {
      return BondScaffold(
        title: def.title,
        showBack: true,
        child: const Padding(
          padding: EdgeInsets.only(top: AppSpacing.huge),
          child: BondLoader(),
        ),
      );
    }

    if (state.error != null) {
      return BondScaffold(
        title: def.title,
        showBack: true,
        child: _notice(Icons.cloud_off_rounded, state.error!),
      );
    }

    // Board games need both partners.
    if (state.players.length < 2) {
      return BondScaffold(
        title: def.title,
        showBack: true,
        child: _notice(Icons.people_outline_rounded,
            'This one\'s for two — it\'ll be playable once your partner has joined. 🤍'),
      );
    }

    final result = _resultFor(state.gameType, state.moves, state.players);
    final myIndex = controller.myIndex;
    final myTurn = !result.isOver &&
        result.currentPlayer == myIndex &&
        state.players.length == 2;

    // Award XP once when the game ends.
    if (result.isOver && state.newScore == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => controller.finish(def.xp));
    }

    return BondScaffold(
      title: def.title,
      showBack: true,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          _banner(result, myTurn, myIndex),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Center(
              child: _board(state, myIndex, myTurn, controller),
            ),
          ),
          if (result.isOver) _resultCard(context, result, myIndex, def, state),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _notice(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.inkFaint),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center, style: AppText.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _board(BoardGameState state, int myIndex, bool myTurn,
      BoardGameController controller) {
    switch (state.gameType) {
      case 'four_in_a_row':
        return ConnectFourBoard(
          moves: state.moves,
          players: state.players,
          myTurn: myTurn,
          onDrop: (col) => controller.submit({'col': col}),
        );
      case 'tic_tac_toe':
        return TicTacToeBoard(
          moves: state.moves,
          players: state.players,
          myTurn: myTurn,
          onTap: (cell) => controller.submit({'cell': cell}),
        );
      case 'dots_and_boxes':
        return DotsAndBoxesBoard(
          moves: state.moves,
          players: state.players,
          myTurn: myTurn,
          onEdge: (edge) => controller.submit({'edge': edge}),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _banner(BoardResult r, bool myTurn, int myIndex) {
    final String label;
    Color color;
    if (r.isOver) {
      label = 'Game over';
      color = AppColors.inkMuted;
    } else if (myTurn) {
      label = 'Your turn';
      color = boardPlayerColors[myIndex.clamp(0, 1)];
    } else {
      label = 'Their turn';
      color = AppColors.inkMuted;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.circle, size: 12, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppText.title),
      ],
    );
  }

  Widget _resultCard(BuildContext context, BoardResult r, int myIndex,
      GameDefinition def, BoardGameState state) {
    final String headline;
    if (r.winner == 2) {
      headline = 'It\'s a draw 🤝';
    } else if (r.winner == myIndex) {
      headline = 'You won 🎉';
    } else {
      headline = 'Your partner won 💛';
    }
    return BondCard(
      color: AppColors.mintWash,
      elevated: false,
      child: Column(
        children: [
          Text(headline, textAlign: TextAlign.center, style: AppText.headline),
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.newScore != null
                ? '+${def.xp} bond XP  ·  you played together 🤍'
                : 'you played together 🤍',
            textAlign: TextAlign.center,
            style: AppText.bodyMedium.copyWith(color: AppColors.mintDeep),
          ),
          const SizedBox(height: AppSpacing.md),
          BondButton(
            label: 'Back to games',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scaleXY(begin: 0.96, end: 1);
  }

  BoardResult _resultFor(String type, List<RawMove> moves, List<String> players) {
    switch (type) {
      case 'four_in_a_row':
        return ConnectFour.replay(moves, players).result;
      case 'tic_tac_toe':
        return TicTacToe.replay(moves, players).result;
      case 'dots_and_boxes':
        return DotsAndBoxes.replay(moves, players).result;
      default:
        return const BoardResult(currentPlayer: 0, winner: -1);
    }
  }
}
