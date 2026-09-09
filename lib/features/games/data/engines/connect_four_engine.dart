import '../board_models.dart';

/// Pure Connect Four logic. Grid is [row][col], row 0 = top, discs fall down.
/// Cell values: -1 empty, 0/1 player index.
class ConnectFour {
  static const int cols = 7;
  static const int rows = 6;

  static ConnectFourState replay(List<RawMove> moves, List<String> players) {
    final grid = List.generate(rows, (_) => List.filled(cols, -1));
    int winner = -1;
    for (final m in moves) {
      final col = (m.data['col'] as num?)?.toInt();
      final p = players.indexOf(m.userId);
      if (col == null || col < 0 || col >= cols || p < 0) continue;
      for (var r = rows - 1; r >= 0; r--) {
        if (grid[r][col] == -1) {
          grid[r][col] = p;
          if (_wins(grid, r, col, p)) winner = p;
          break;
        }
      }
    }
    final over = winner != -1
        ? winner
        : (moves.length >= rows * cols ? 2 : -1);
    return ConnectFourState(
      grid: grid,
      result: BoardResult(currentPlayer: moves.length % 2, winner: over),
    );
  }

  static bool columnFull(List<List<int>> grid, int col) => grid[0][col] != -1;

  static bool _wins(List<List<int>> g, int r, int c, int p) {
    const dirs = [
      [0, 1], // horizontal
      [1, 0], // vertical
      [1, 1], // diagonal ↘
      [1, -1], // diagonal ↙
    ];
    for (final d in dirs) {
      var count = 1;
      for (final s in [1, -1]) {
        var rr = r + d[0] * s, cc = c + d[1] * s;
        while (rr >= 0 && rr < rows && cc >= 0 && cc < cols && g[rr][cc] == p) {
          count++;
          rr += d[0] * s;
          cc += d[1] * s;
        }
      }
      if (count >= 4) return true;
    }
    return false;
  }
}

class ConnectFourState {
  const ConnectFourState({required this.grid, required this.result});
  final List<List<int>> grid;
  final BoardResult result;
}
