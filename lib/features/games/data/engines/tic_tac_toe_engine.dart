import '../board_models.dart';

/// Pure Tic-Tac-Toe. Board is 9 cells (0..8), values -1/0/1.
class TicTacToe {
  static const _lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
    [0, 4, 8], [2, 4, 6], // diagonals
  ];

  static TicTacToeState replay(List<RawMove> moves, List<String> players) {
    final b = List.filled(9, -1);
    for (final m in moves) {
      final cell = (m.data['cell'] as num?)?.toInt();
      final p = players.indexOf(m.userId);
      if (cell == null || cell < 0 || cell >= 9 || p < 0) continue;
      if (b[cell] == -1) b[cell] = p;
    }
    int winner = -1;
    for (final l in _lines) {
      final v = b[l[0]];
      if (v != -1 && v == b[l[1]] && v == b[l[2]]) winner = v;
    }
    final over = winner != -1
        ? winner
        : (b.every((c) => c != -1) ? 2 : -1);
    return TicTacToeState(
      board: b,
      result: BoardResult(currentPlayer: moves.length % 2, winner: over),
    );
  }
}

class TicTacToeState {
  const TicTacToeState({required this.board, required this.result});
  final List<int> board;
  final BoardResult result;
}
