import '../board_models.dart';

/// Pure Dots and Boxes on a 4×4 dot grid → 3×3 = 9 boxes.
///
/// Edge ids: horizontal edges first (rows 0..3, cols 0..2) → id = r*3 + c (0..11);
/// vertical edges next (rows 0..2, cols 0..3) → id = 12 + r*4 + c (12..23).
/// Completing a box grants another turn (so turn is not simple parity).
class DotsAndBoxes {
  static const int dots = 4;
  static const int boxN = 3; // 3×3 boxes
  static const int totalEdges = 24;

  static int hId(int r, int c) => r * boxN + c; // r 0..3, c 0..2
  static int vId(int r, int c) => 12 + r * dots + c; // r 0..2, c 0..3

  /// The 4 edges bounding box (r,c), r/c in 0..2.
  static List<int> boxEdges(int r, int c) =>
      [hId(r, c), hId(r + 1, c), vId(r, c), vId(r, c + 1)];

  static DotsState replay(List<RawMove> moves, List<String> players) {
    final drawn = <int>{};
    final boxes = List.generate(boxN, (_) => List.filled(boxN, -1));
    int current = 0;

    for (final m in moves) {
      final edge = (m.data['edge'] as num?)?.toInt();
      final p = players.indexOf(m.userId);
      if (edge == null || edge < 0 || edge >= totalEdges || p < 0) continue;
      if (drawn.contains(edge)) continue;
      drawn.add(edge);

      var completed = 0;
      for (var r = 0; r < boxN; r++) {
        for (var c = 0; c < boxN; c++) {
          if (boxes[r][c] == -1 && boxEdges(r, c).every(drawn.contains)) {
            boxes[r][c] = p;
            completed++;
          }
        }
      }
      current = completed > 0 ? p : 1 - p; // extra turn on box completion
    }

    int winner = -1;
    if (drawn.length >= totalEdges) {
      var a = 0, b = 0;
      for (final row in boxes) {
        for (final v in row) {
          if (v == 0) a++;
          if (v == 1) b++;
        }
      }
      winner = a == b ? 2 : (a > b ? 0 : 1);
    }

    return DotsState(
      drawn: drawn,
      boxes: boxes,
      result: BoardResult(currentPlayer: current, winner: winner),
    );
  }
}

class DotsState {
  const DotsState({
    required this.drawn,
    required this.boxes,
    required this.result,
  });
  final Set<int> drawn;
  final List<List<int>> boxes;
  final BoardResult result;
}
