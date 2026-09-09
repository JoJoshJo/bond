import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/board_models.dart';
import '../../data/engines/dots_and_boxes_engine.dart';
import 'board_colors.dart';

class DotsAndBoxesBoard extends StatelessWidget {
  const DotsAndBoxesBoard({
    super.key,
    required this.moves,
    required this.players,
    required this.myTurn,
    required this.onEdge,
  });

  final List<RawMove> moves;
  final List<String> players;
  final bool myTurn;
  final void Function(int edge) onEdge;

  static const _dot = 14.0;

  @override
  Widget build(BuildContext context) {
    final s = DotsAndBoxes.replay(moves, players);
    final over = s.result.isOver;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.clamp(0, 320).toDouble();
          final cell = (w - _dot * DotsAndBoxes.dots) / DotsAndBoxes.boxN;

          Widget dot() => Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
              );

          Widget edge(int id, double ww, double hh) {
            final drawn = s.drawn.contains(id);
            final tappable = myTurn && !over && !drawn;
            return GestureDetector(
              onTap: tappable ? () => onEdge(id) : null,
              child: Container(
                width: ww,
                height: hh,
                alignment: Alignment.center,
                child: Container(
                  width: ww == _dot ? 6 : ww,
                  height: hh == _dot ? 6 : hh,
                  decoration: BoxDecoration(
                    color: drawn
                        ? AppColors.mintDeep
                        : (tappable ? AppColors.mintSoft : AppColors.border),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }

          Widget box(int r, int c) {
            final owner = s.boxes[r][c];
            return Container(
              width: cell,
              height: cell,
              alignment: Alignment.center,
              color: owner == -1
                  ? Colors.transparent
                  : boardPlayerColors[owner].withValues(alpha: 0.3),
            );
          }

          Widget dotRow(int r) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < DotsAndBoxes.boxN; c++) ...[
                    dot(),
                    edge(DotsAndBoxes.hId(r, c), cell, _dot),
                  ],
                  dot(),
                ],
              );

          Widget midRow(int r) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < DotsAndBoxes.boxN; c++) ...[
                    edge(DotsAndBoxes.vId(r, c), _dot, cell),
                    box(r, c),
                  ],
                  edge(DotsAndBoxes.vId(r, DotsAndBoxes.boxN), _dot, cell),
                ],
              );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < DotsAndBoxes.boxN; r++) ...[
                dotRow(r),
                midRow(r),
              ],
              dotRow(DotsAndBoxes.boxN),
            ],
          );
        },
      ),
    );
  }
}
