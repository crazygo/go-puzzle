import 'dart:math' as math;

import '../models/board_position.dart';
import '../models/game_state.dart';

typedef SimMoveScorer = double Function(
  SimBoard board,
  int moveIndex,
  SimMoveAnalysis analysis,
);

class SimMoveAnalysis {
  const SimMoveAnalysis({
    required this.isLegal,
    this.blackCaptureDelta = 0,
    this.whiteCaptureDelta = 0,
    this.opponentAtariStones = 0,
    this.ownAtariStones = 0,
    this.ownRescuedStones = 0,
    this.adjacentOpponentStones = 0,
    this.libertiesAfterMove = 0,
    this.centerProximityScore = 0,
  });

  final bool isLegal;
  final int blackCaptureDelta;
  final int whiteCaptureDelta;
  final int opponentAtariStones;
  final int ownAtariStones;
  final int ownRescuedStones;
  final int adjacentOpponentStones;
  final int libertiesAfterMove;
  final int centerProximityScore;
}

/// Lightweight flat-array board for MCTS simulations.
/// Uses integers instead of enums for speed.
class SimBoard {
  static const int empty = 0;
  static const int black = 1;
  static const int white = 2;

  final int size;
  final int captureTarget;
  final List<int> cells;
  int capturedByBlack;
  int capturedByWhite;
  int currentPlayer;
  int _koIndex; // flat index of the forbidden ko point, -1 if none

  SimBoard(this.size, {this.captureTarget = 5})
      : cells = List.filled(size * size, 0),
        capturedByBlack = 0,
        capturedByWhite = 0,
        currentPlayer = black,
        _koIndex = -1;

  SimBoard._internal({
    required this.size,
    required this.captureTarget,
    required List<int> cells,
    required this.capturedByBlack,
    required this.capturedByWhite,
    required this.currentPlayer,
    required int koIndex,
  })  : cells = List<int>.from(cells),
        _koIndex = koIndex;

  factory SimBoard.copy(SimBoard other) => SimBoard._internal(
        size: other.size,
        captureTarget: other.captureTarget,
        cells: other.cells,
        capturedByBlack: other.capturedByBlack,
        capturedByWhite: other.capturedByWhite,
        currentPlayer: other.currentPlayer,
        koIndex: other._koIndex,
      );

  /// Creates a SimBoard from a GameState, setting [aiPlayer] as [white].
  factory SimBoard.fromGameState(GameState state, {int captureTarget = 5}) {
    final sb = SimBoard(state.boardSize, captureTarget: captureTarget);
    for (int r = 0; r < state.boardSize; r++) {
      for (int c = 0; c < state.boardSize; c++) {
        final color = state.board[r][c];
        if (color == StoneColor.black) {
          sb.cells[r * state.boardSize + c] = black;
        } else if (color == StoneColor.white) {
          sb.cells[r * state.boardSize + c] = white;
        }
      }
    }
    sb.capturedByBlack = state.capturedByBlack.length;
    sb.capturedByWhite = state.capturedByWhite.length;
    sb.currentPlayer = state.currentPlayer == StoneColor.black ? black : white;
    return sb;
  }

  int idx(int r, int c) => r * size + c;

  int colorAt(int r, int c) => cells[idx(r, c)];

  List<int> _adjacent(int i) {
    final r = i ~/ size;
    final c = i % size;
    final result = <int>[];
    if (r > 0) result.add(i - size);
    if (r < size - 1) result.add(i + size);
    if (c > 0) result.add(i - 1);
    if (c < size - 1) result.add(i + 1);
    return result;
  }

  Set<int> _findGroup(int i) {
    final color = cells[i];
    if (color == empty) return {};
    final group = <int>{i};
    final queue = [i];
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      for (final adj in _adjacent(cur)) {
        if (!group.contains(adj) && cells[adj] == color) {
          group.add(adj);
          queue.add(adj);
        }
      }
    }
    return group;
  }

  int _countLiberties(Set<int> group) {
    final libs = <int>{};
    for (final pos in group) {
      for (final adj in _adjacent(pos)) {
        if (cells[adj] == empty) libs.add(adj);
      }
    }
    return libs.length;
  }

  /// Applies a move at (r, c). Returns true when valid and applied.
  bool applyMove(int r, int c) {
    if (r < 0 || r >= size || c < 0 || c >= size) return false;

    final i = idx(r, c);
    if (cells[i] != empty) return false;
    if (i == _koIndex) return false;

    final color = currentPlayer;
    final opponent = color == black ? white : black;

    cells[i] = color;

    // Determine all opponent groups to capture simultaneously.
    final captured = <int>[];
    final checked = <int>{};
    for (final adj in _adjacent(i)) {
      if (cells[adj] == opponent && !checked.contains(adj)) {
        final group = _findGroup(adj);
        checked.addAll(group);
        // Liberty count with the new stone already placed.
        final libs = <int>{};
        for (final p in group) {
          for (final a in _adjacent(p)) {
            if (cells[a] == empty) libs.add(a);
          }
        }
        if (libs.isEmpty) captured.addAll(group);
      }
    }

    // Remove captured stones.
    for (final p in captured) {
      cells[p] = empty;
    }

    // Check suicide (only relevant when no captures).
    if (captured.isEmpty) {
      final ownGroup = _findGroup(i);
      if (_countLiberties(ownGroup) == 0) {
        cells[i] = empty;
        return false;
      }
    }

    if (color == black) {
      capturedByBlack += captured.length;
    } else {
      capturedByWhite += captured.length;
    }

    _koIndex = captured.length == 1 ? captured[0] : -1;
    currentPlayer = opponent;
    return true;
  }

  SimMoveAnalysis analyzeMove(int r, int c) {
    if (r < 0 || r >= size || c < 0 || c >= size) {
      return const SimMoveAnalysis(isLegal: false);
    }

    final beforeCurrentPlayer = currentPlayer;
    final beforeBlackCaptures = capturedByBlack;
    final beforeWhiteCaptures = capturedByWhite;
    final moveIndex = idx(r, c);

    var adjacentOpponentStones = 0;
    for (final adj in _adjacent(moveIndex)) {
      if (cells[adj] != empty && cells[adj] != beforeCurrentPlayer) {
        adjacentOpponentStones++;
      }
    }

    final ownAtariBefore = _countPlayerAtariStones(beforeCurrentPlayer);

    final simulated = SimBoard.copy(this);
    if (!simulated.applyMove(r, c)) {
      return const SimMoveAnalysis(isLegal: false);
    }

    final ownGroup = simulated._findGroup(moveIndex);
    final ownLiberties = simulated._countLiberties(ownGroup);
    final ownAtariAfter =
        simulated._countPlayerAtariStones(beforeCurrentPlayer);
    final opponentAtariAfter = simulated
        ._countPlayerAtariStones(beforeCurrentPlayer == black ? white : black);

    final center = size ~/ 2;
    final centerDistance = (r - center).abs() + (c - center).abs();
    final centerProximityScore = math.max(0, size - centerDistance);

    return SimMoveAnalysis(
      isLegal: true,
      blackCaptureDelta: simulated.capturedByBlack - beforeBlackCaptures,
      whiteCaptureDelta: simulated.capturedByWhite - beforeWhiteCaptures,
      opponentAtariStones: opponentAtariAfter,
      ownAtariStones: ownAtariAfter,
      ownRescuedStones: math.max(0, ownAtariBefore - ownAtariAfter),
      adjacentOpponentStones: adjacentOpponentStones,
      libertiesAfterMove: ownLiberties,
      centerProximityScore: centerProximityScore,
    );
  }

  bool get isTerminal =>
      capturedByBlack >= captureTarget || capturedByWhite >= captureTarget;

  /// Returns [black], [white], or 0 (no winner yet).
  int get winner {
    if (capturedByBlack >= captureTarget) return black;
    if (capturedByWhite >= captureTarget) return white;
    return 0;
  }

  /// Returns candidate legal moves focused within 2 intersections of existing
  /// stones.  Falls back to a central region on an empty board.
  List<int> getLegalMoves() {
    final candidates = <int>{};
    bool hasStones = false;

    for (int i = 0; i < size * size; i++) {
      if (cells[i] != empty) {
        hasStones = true;
        final r = i ~/ size;
        final c = i % size;
        for (int dr = -2; dr <= 2; dr++) {
          for (int dc = -2; dc <= 2; dc++) {
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              final ni = idx(nr, nc);
              if (cells[ni] == empty && ni != _koIndex) {
                candidates.add(ni);
              }
            }
          }
        }
      }
    }

    if (!hasStones) {
      // Empty board – suggest the central region.
      final center = size ~/ 2;
      for (int r = center - 4; r <= center + 4; r++) {
        for (int c = center - 4; c <= center + 4; c++) {
          if (r >= 0 && r < size && c >= 0 && c < size) {
            candidates.add(idx(r, c));
          }
        }
      }
    }

    return candidates.toList();
  }

  int _countPlayerAtariStones(int playerColor) {
    final visited = <int>{};
    var total = 0;

    for (int i = 0; i < cells.length; i++) {
      if (cells[i] != playerColor || visited.contains(i)) continue;

      final group = _findGroup(i);
      visited.addAll(group);
      if (_countLiberties(group) == 1) {
        total += group.length;
      }
    }

    return total;
  }
}

// ---------------------------------------------------------------------------
// MCTS node
// ---------------------------------------------------------------------------

class _MctsNode {
  final _MctsNode? parent;
  final int moveIdx; // flat board index; -1 for root
  final int playerWhoMoved; // color that made the move reaching this node
  final List<_MctsNode> children = [];
  int wins = 0;
  int visits = 0;
  List<int>? _untriedMoves;

  _MctsNode({
    this.parent,
    this.moveIdx = -1,
    this.playerWhoMoved = 0,
  });

  void initUntriedMoves(
    List<int> moves, {
    required SimBoard board,
    required math.Random rng,
    SimMoveScorer? scorer,
    int? candidateLimit,
  }) {
    var orderedMoves = List<int>.from(moves);
    if (scorer != null) {
      orderedMoves = _rankMoves(board, orderedMoves, scorer);
    } else {
      orderedMoves.shuffle(rng);
    }
    if (candidateLimit != null && orderedMoves.length > candidateLimit) {
      orderedMoves = orderedMoves.take(candidateLimit).toList();
    }
    _untriedMoves = orderedMoves.reversed.toList();
  }

  bool get hasUntriedMoves =>
      _untriedMoves != null && _untriedMoves!.isNotEmpty;

  int? popUntriedMove() {
    if (_untriedMoves == null || _untriedMoves!.isEmpty) return null;
    return _untriedMoves!.removeLast();
  }

  /// UCB1 score from the perspective of [playerWhoMoved].
  double ucb1(int parentVisits, {double c = 1.414}) {
    if (visits == 0) return double.infinity;
    return wins / visits + c * math.sqrt(math.log(parentVisits) / visits);
  }

  /// Child with the highest empirical win rate.
  _MctsNode? get highestWinRateChild {
    if (children.isEmpty) return null;
    return children.reduce((a, b) {
      final aRate = a.visits == 0 ? 0.0 : a.wins / a.visits;
      final bRate = b.visits == 0 ? 0.0 : b.wins / b.visits;
      if (aRate == bRate) return a.visits >= b.visits ? a : b;
      return aRate > bRate ? a : b;
    });
  }

  static List<int> _rankMoves(
    SimBoard board,
    List<int> moves,
    SimMoveScorer scorer,
  ) {
    final scored = <({int moveIndex, double score})>[];
    for (final moveIndex in moves) {
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      scored.add((
        moveIndex: moveIndex,
        score: scorer(board, moveIndex, analysis),
      ));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.moveIndex.compareTo(b.moveIndex);
    });
    return scored.map((entry) => entry.moveIndex).toList();
  }
}

// ---------------------------------------------------------------------------
// MCTS engine
// ---------------------------------------------------------------------------

/// Pure-Dart MCTS engine for the capture-stones (吃子) variant.
///
/// Reward function: a simulation ends when either side accumulates ≥ N
/// captures (where N is determined by [SimBoard.captureTarget]).
/// The winner receives reward = 1, the loser reward = 0.
///
/// Difficulty is controlled via [maxPlayouts]:
///   • 入門  (beginner) : 200  playouts
///   • 進階  (advanced) : 2000 playouts
class MctsEngine {
  MctsEngine({
    this.maxPlayouts = 200,
    this.rolloutDepth = 50,
    this.exploration = 1.414,
    this.candidateLimit,
    this.moveScorer,
    this.rolloutTemperature = 0,
    int seed = 0,
  }) : _rng = math.Random(seed);

  final int maxPlayouts;
  final int rolloutDepth;
  final double exploration;
  final int? candidateLimit;
  final SimMoveScorer? moveScorer;
  final double rolloutTemperature;
  final math.Random _rng;

  /// Returns the best [BoardPosition] for the current player in [board],
  /// or null if the game is already over or no moves exist.
  BoardPosition? getBestMove(SimBoard board) {
    if (board.isTerminal) return null;

    final moves = board.getLegalMoves();
    if (moves.isEmpty) return null;
    if (moves.length == 1) {
      return BoardPosition(moves[0] ~/ board.size, moves[0] % board.size);
    }

    final root = _MctsNode();
    root.initUntriedMoves(
      moves,
      board: board,
      rng: _rng,
      scorer: moveScorer,
      candidateLimit: candidateLimit,
    );

    for (int i = 0; i < maxPlayouts; i++) {
      final simBoard = SimBoard.copy(board);
      final leaf = _selectAndExpand(root, simBoard);
      final winner = _rollout(simBoard);
      _backpropagate(leaf, winner);
    }

    final best = root.highestWinRateChild;
    if (best == null) return null;
    return BoardPosition(
      best.moveIdx ~/ board.size,
      best.moveIdx % board.size,
    );
  }

  /// Walks down fully-expanded nodes using UCB1, then expands one untried move.
  _MctsNode _selectAndExpand(_MctsNode root, SimBoard board) {
    var node = root;

    // Selection
    while (!board.isTerminal &&
        !node.hasUntriedMoves &&
        node.children.isNotEmpty) {
      node = node.children.reduce(
        (a, b) => a.ucb1(node.visits, c: exploration) >
                b.ucb1(node.visits, c: exploration)
            ? a
            : b,
      );
      board.applyMove(node.moveIdx ~/ board.size, node.moveIdx % board.size);
    }

    // Expansion
    if (!board.isTerminal && node.hasUntriedMoves) {
      final moveIdx = node.popUntriedMove()!;
      final r = moveIdx ~/ board.size;
      final c = moveIdx % board.size;
      final playerWhoMoved = board.currentPlayer;
      if (board.applyMove(r, c)) {
        final child = _MctsNode(
          parent: node,
          moveIdx: moveIdx,
          playerWhoMoved: playerWhoMoved,
        );
        child.initUntriedMoves(
          board.getLegalMoves(),
          board: board,
          rng: _rng,
          scorer: moveScorer,
          candidateLimit: candidateLimit,
        );
        node.children.add(child);
        node = child;
      }
    }

    return node;
  }

  /// Random playout until terminal or depth limit; returns the winner color.
  int _rollout(SimBoard board) {
    int depth = 0;
    while (!board.isTerminal && depth < rolloutDepth) {
      final moves = board.getLegalMoves();
      if (moves.isEmpty) break;
      final moveIdx = _chooseRolloutMove(board, moves);
      board.applyMove(moveIdx ~/ board.size, moveIdx % board.size);
      depth++;
    }
    // Non-terminal: use capture advantage as tie-break heuristic. If captures
    // are tied, prefer the player to move because they still own initiative.
    if (!board.isTerminal) {
      if (board.capturedByBlack == board.capturedByWhite) {
        return board.currentPlayer;
      }
      return board.capturedByWhite > board.capturedByBlack
          ? SimBoard.white
          : SimBoard.black;
    }
    return board.winner;
  }

  /// Backpropagates: increments visits for every ancestor; increments wins for
  /// nodes where [playerWhoMoved] equals the [winner].
  void _backpropagate(_MctsNode node, int winner) {
    _MctsNode? cur = node;
    while (cur != null) {
      cur.visits++;
      if (winner != 0 && cur.playerWhoMoved == winner) {
        cur.wins++;
      }
      cur = cur.parent;
    }
  }

  int _chooseRolloutMove(SimBoard board, List<int> moves) {
    final scorer = moveScorer;
    if (scorer == null) return moves[_rng.nextInt(moves.length)];

    if (rolloutTemperature <= 0) {
      final rankedMoves = _MctsNode._rankMoves(board, moves, scorer);
      if (rankedMoves.isNotEmpty) return rankedMoves.first;
      return moves[_rng.nextInt(moves.length)];
    }

    final scored = <({int moveIndex, double weight})>[];
    var total = 0.0;
    for (final moveIndex in moves) {
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      final score = scorer(board, moveIndex, analysis);
      final weight = math.exp(score / rolloutTemperature);
      if (weight.isFinite && weight > 0) {
        scored.add((moveIndex: moveIndex, weight: weight));
        total += weight;
      }
    }
    if (scored.isEmpty || total <= 0) return moves[_rng.nextInt(moves.length)];

    var ticket = _rng.nextDouble() * total;
    for (final entry in scored) {
      ticket -= entry.weight;
      if (ticket <= 0) return entry.moveIndex;
    }
    return scored.last.moveIndex;
  }
}
