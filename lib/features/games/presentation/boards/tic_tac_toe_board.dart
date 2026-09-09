import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/board_models.dart';
import '../../data/engines/tic_tac_toe_engine.dart';
import 'board_colors.dart';

class TicTacToeBoard extends StatelessWidget {
  const TicTacToeBoard({
    super.key,
    required this.moves,
    required this.players,
    required this.myTurn,
    required this.onTap,
  });

  final List<RawMove> moves;
  final List<String> players;
  final bool myTurn;
  final void Function(int cell) onTap;

  @override
  Widget build(BuildContext context) {
    final s = TicTacToe.replay(moves, players);
    final over = s.result.isOver;
    final lastCell = moves.isEmpty ? -1 : (moves.last.data['cell'] as num).toInt();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var i = 0; i < 9; i++)
              GestureDetector(
                onTap: (myTurn && !over && s.board[i] == -1)
                    ? () => onTap(i)
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(child: _mark(s.board[i], i == lastCell)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mark(int v, bool animate) {
    if (v == -1) return const SizedBox.shrink();
    final icon = Icon(
      v == 0 ? Icons.close_rounded : Icons.circle_outlined,
      size: 56,
      color: boardPlayerColors[v],
    );
    return animate
        ? icon.animate().scaleXY(begin: 0.4, end: 1, duration: 250.ms, curve: Curves.easeOutBack)
        : icon;
  }
}
