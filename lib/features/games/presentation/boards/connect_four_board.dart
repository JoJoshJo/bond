import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/board_models.dart';
import '../../data/engines/connect_four_engine.dart';
import 'board_colors.dart';

class ConnectFourBoard extends StatelessWidget {
  const ConnectFourBoard({
    super.key,
    required this.moves,
    required this.players,
    required this.myTurn,
    required this.onDrop,
  });

  final List<RawMove> moves;
  final List<String> players;
  final bool myTurn;
  final void Function(int col) onDrop;

  @override
  Widget build(BuildContext context) {
    final s = ConnectFour.replay(moves, players);
    final over = s.result.isOver;
    final lastCol = moves.isEmpty ? -1 : (moves.last.data['col'] as num).toInt();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: ConnectFour.cols / ConnectFour.rows,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.mintWash,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.mintSoft, width: 2),
          ),
          child: Column(
            children: [
              for (var r = 0; r < ConnectFour.rows; r++)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < ConnectFour.cols; c++)
                        Expanded(
                          child: GestureDetector(
                            onTap: (myTurn && !over && !ConnectFour.columnFull(s.grid, c))
                                ? () => onDrop(c)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: _cell(s.grid[r][c], c == lastCol),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(int v, bool animate) {
    final disc = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: v == -1 ? AppColors.surface : boardPlayerColors[v],
        border: v == -1 ? Border.all(color: AppColors.border) : null,
      ),
    );
    if (v != -1 && animate) {
      return disc.animate().slideY(begin: -1.2, end: 0, duration: 300.ms, curve: Curves.easeOut);
    }
    return disc;
  }
}
