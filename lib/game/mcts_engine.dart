import 'dart:math' as math;

import 'game_mode.dart';
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

class SimGroupInfo {
  const SimGroupInfo({
    required this.color,
    required this.stones,
    required this.liberties,
  });

  final int color;
  final Set<int> stones;
  final Set<int> liberties;

  int get size => stones.length;
  int get libertyCount => liberties.length;
}

double scoreCriticalOwnGroupDefense(
  SimBoard board,
  int moveIndex,
  SimMoveAnalysis analysis,
) {
  if (!analysis.isLegal) return 0;
  final player = board.currentPlayer;
  final ownCaptureDelta = player == SimBoard.black
      ? analysis.blackCaptureDelta
      : analysis.whiteCaptureDelta;
  final ownCaptures =
      player == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
  if (ownCaptures + ownCaptureDelta >= board.captureTarget) {
    return 0;
  }

  var score = 0.0;
  final opponent = player == SimBoard.black ? SimBoard.white : SimBoard.black;
  final candidateGroups = _ownGroupsAdjacentToMove(
    board,
    player: player,
    moveIndex: moveIndex,
    minGroupSize: 2,
    maxLiberties: 2,
  );
  if (candidateGroups.isEmpty) return 0;

  final probe = SimBoard.copy(board);
  if (!probe.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return 0;
  }
  for (final candidate in candidateGroups) {
    final group = candidate.info;
    final anchor = candidate.anchor;
    if (group.size < 2 || group.libertyCount > 2) continue;
    if (!group.liberties.contains(moveIndex)) continue;
    if (probe.cells[anchor] != player) continue;
    final afterGroup = probe.groupAtIndex(anchor);
    final libertiesAfter = probe.libertiesForGroup(afterGroup).length;
    final libertyGain = libertiesAfter - group.libertyCount;
    if (libertyGain <= 0) continue;

    var libertyPressure = 0;
    for (final liberty in group.liberties) {
      for (final adjacent in board.adjacentIndices(liberty)) {
        if (board.cells[adjacent] == opponent) libertyPressure++;
      }
    }
    final urgentBonus = group.libertyCount == 1 ? 700.0 : 420.0;
    score += urgentBonus +
        group.size * 80.0 +
        libertyGain * 260.0 +
        libertyPressure * 140.0 +
        math.min(group.libertyCount, 2) * 40.0;
  }
  return score;
}

double scoreDoomedAtariExtensionPenalty(
  SimBoard board,
  int moveIndex,
  SimMoveAnalysis analysis,
) {
  if (!analysis.isLegal) return 0;
  final player = board.currentPlayer;
  final ownCaptureDelta = player == SimBoard.black
      ? analysis.blackCaptureDelta
      : analysis.whiteCaptureDelta;
  if (ownCaptureDelta > 0) return 0;

  var largestSavedGroupSize = 0;
  var anchor = -1;
  for (final candidate in _ownGroupsAdjacentToMove(
    board,
    player: player,
    moveIndex: moveIndex,
    maxLiberties: 1,
  )) {
    final group = candidate.info;
    if (group.libertyCount != 1 || !group.liberties.contains(moveIndex)) {
      continue;
    }
    if (group.size > largestSavedGroupSize) {
      largestSavedGroupSize = group.size;
      anchor = candidate.anchor;
    }
  }

  final probe = SimBoard.copy(board);
  if (!probe.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return 0;
  }
  if (anchor < 0) {
    if (analysis.ownRescuedStones <= 0 || probe.cells[moveIndex] != player) {
      return 0;
    }
    final formedGroup = probe.groupAtIndex(moveIndex);
    final formedLiberties = probe.libertiesForGroup(formedGroup);
    if (formedLiberties.length > 2) {
      return 0;
    }
    anchor = moveIndex;
    largestSavedGroupSize = formedGroup.length;
  }
  if (probe.cells[anchor] != player) return 0;
  var targetGroup = probe.groupAtIndex(anchor);
  var targetLiberties = probe.libertiesForGroup(targetGroup);
  if (targetLiberties.length > 2) return 0;

  final outcome = _simulateAtariChase(
    probe,
    anchor: anchor,
    targetPlayer: player,
    depth: math.min(board.size + 4, 18),
  );

  final dangerousSize = math.max(
    outcome.capturedTargetSize,
    math.max(outcome.maxGroupSize, largestSavedGroupSize),
  );
  if (outcome.capturedTargetSize >= board.captureTarget) {
    return 3600.0 + outcome.capturedTargetSize * 420.0;
  }
  if (outcome.forcedRescues >= 2 &&
      dangerousSize >= board.captureTarget &&
      outcome.finalLiberties <= 2) {
    return 2200.0 + dangerousSize * 260.0 + outcome.forcedRescues * 180.0;
  }
  if (analysis.ownRescuedStones > 0 &&
      targetGroup.length >= 2 &&
      targetLiberties.length == 2) {
    return 1700.0 + targetGroup.length * 220.0;
  }
  return 0;
}

double scoreImmediateOpponentCapturePenalty(
  SimBoard board,
  int moveIndex,
  SimMoveAnalysis analysis,
) {
  if (!analysis.isLegal) return 0;
  final player = board.currentPlayer;
  final ownCaptureDelta = player == SimBoard.black
      ? analysis.blackCaptureDelta
      : analysis.whiteCaptureDelta;
  if (ownCaptureDelta <= 0) return 0;
  final ownCaptures =
      player == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
  if (ownCaptures + ownCaptureDelta >= board.captureTarget) return 0;

  final probe = SimBoard.copy(board);
  if (!probe.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return 0;
  }
  if (probe.isTerminal) return 0;

  final opponent = probe.currentPlayer;
  final opponentCaptures = opponent == SimBoard.black
      ? probe.capturedByBlack
      : probe.capturedByWhite;
  var worstReplyDelta = 0;
  for (final replyIndex in probe.getLegalMoves()) {
    final reply = probe.analyzeMove(
      replyIndex ~/ probe.size,
      replyIndex % probe.size,
    );
    if (!reply.isLegal) continue;
    final replyCaptureDelta = opponent == SimBoard.black
        ? reply.blackCaptureDelta
        : reply.whiteCaptureDelta;
    worstReplyDelta = math.max(worstReplyDelta, replyCaptureDelta);
    if (opponentCaptures + replyCaptureDelta >= probe.captureTarget) {
      return 5200.0 + replyCaptureDelta * 520.0;
    }
  }
  if (worstReplyDelta >= board.captureTarget) {
    return 3600.0 + worstReplyDelta * 360.0;
  }
  return 0;
}

List<({int anchor, SimGroupInfo info})> _ownGroupsAdjacentToMove(
  SimBoard board, {
  required int player,
  required int moveIndex,
  int minGroupSize = 1,
  int maxLiberties = 99,
}) {
  final groups = <({int anchor, SimGroupInfo info})>[];
  final visited = <int>{};
  for (final adjacent in board.adjacentIndices(moveIndex)) {
    if (board.cells[adjacent] != player || visited.contains(adjacent)) continue;
    final stones = board.groupAtIndex(adjacent);
    visited.addAll(stones);
    final liberties = board.libertiesForGroup(stones);
    if (!liberties.contains(moveIndex) ||
        stones.length < minGroupSize ||
        liberties.length > maxLiberties) {
      continue;
    }
    groups.add((
      anchor: stones.reduce(math.min),
      info: SimGroupInfo(color: player, stones: stones, liberties: liberties),
    ));
  }
  return groups;
}

_AtariChaseOutcome _simulateAtariChase(
  SimBoard board, {
  required int anchor,
  required int targetPlayer,
  required int depth,
  int forcedRescues = 0,
}) {
  if (board.cells[anchor] != targetPlayer) {
    return _AtariChaseOutcome(
      capturedTargetSize: 0,
      maxGroupSize: 0,
      forcedRescues: forcedRescues,
      finalLiberties: 0,
    );
  }
  final targetGroup = board.groupAtIndex(anchor);
  final targetLiberties = board.libertiesForGroup(targetGroup);
  if (depth <= 0 || targetLiberties.length > 2) {
    return _AtariChaseOutcome(
      capturedTargetSize: 0,
      maxGroupSize: targetGroup.length,
      forcedRescues: forcedRescues,
      finalLiberties: targetLiberties.length,
    );
  }

  if (board.currentPlayer == targetPlayer) {
    if (targetLiberties.length != 1) {
      return _AtariChaseOutcome(
        capturedTargetSize: 0,
        maxGroupSize: targetGroup.length,
        forcedRescues: forcedRescues,
        finalLiberties: targetLiberties.length,
      );
    }
    final move = targetLiberties.first;
    final beforeCaptures = targetPlayer == SimBoard.black
        ? board.capturedByBlack
        : board.capturedByWhite;
    final rescue = SimBoard.copy(board);
    if (!rescue.applyMove(move ~/ rescue.size, move % rescue.size)) {
      return _AtariChaseOutcome(
        capturedTargetSize: targetGroup.length,
        maxGroupSize: targetGroup.length,
        forcedRescues: forcedRescues,
        finalLiberties: 0,
      );
    }
    final afterCaptures = targetPlayer == SimBoard.black
        ? rescue.capturedByBlack
        : rescue.capturedByWhite;
    if (afterCaptures - beforeCaptures >= rescue.captureTarget) {
      return _AtariChaseOutcome(
        capturedTargetSize: 0,
        maxGroupSize: targetGroup.length,
        forcedRescues: forcedRescues,
        finalLiberties: 99,
      );
    }
    final outcome = _simulateAtariChase(
      rescue,
      anchor: anchor,
      targetPlayer: targetPlayer,
      depth: depth - 1,
      forcedRescues: forcedRescues + 1,
    );
    return outcome.copyWith(
      maxGroupSize: math.max(outcome.maxGroupSize, targetGroup.length),
    );
  }

  _AtariChaseOutcome? best;
  for (final liberty in targetLiberties) {
    final probe = SimBoard.copy(board);
    if (!probe.applyMove(liberty ~/ board.size, liberty % board.size)) {
      continue;
    }
    final capturedSize =
        probe.cells[anchor] == targetPlayer ? 0 : targetGroup.length;
    final libertiesAfter = capturedSize > 0
        ? 0
        : probe.libertiesForGroup(probe.groupAtIndex(anchor)).length;
    if (capturedSize == 0 && libertiesAfter > 1) continue;
    final result = capturedSize > 0
        ? _AtariChaseOutcome(
            capturedTargetSize: capturedSize,
            maxGroupSize: targetGroup.length,
            forcedRescues: forcedRescues,
            finalLiberties: 0,
          )
        : _simulateAtariChase(
            probe,
            anchor: anchor,
            targetPlayer: targetPlayer,
            depth: depth - 1,
            forcedRescues: forcedRescues,
          );
    final normalized = result.copyWith(
      maxGroupSize: math.max(result.maxGroupSize, targetGroup.length),
    );
    if (best == null || normalized.isWorseThan(best)) {
      best = normalized;
    }
  }
  return best ??
      _AtariChaseOutcome(
        capturedTargetSize: 0,
        maxGroupSize: targetGroup.length,
        forcedRescues: forcedRescues,
        finalLiberties: targetLiberties.length,
      );
}

class _AtariChaseOutcome {
  const _AtariChaseOutcome({
    required this.capturedTargetSize,
    required this.maxGroupSize,
    required this.forcedRescues,
    required this.finalLiberties,
  });

  final int capturedTargetSize;
  final int maxGroupSize;
  final int forcedRescues;
  final int finalLiberties;

  _AtariChaseOutcome copyWith({
    int? capturedTargetSize,
    int? maxGroupSize,
    int? forcedRescues,
    int? finalLiberties,
  }) {
    return _AtariChaseOutcome(
      capturedTargetSize: capturedTargetSize ?? this.capturedTargetSize,
      maxGroupSize: maxGroupSize ?? this.maxGroupSize,
      forcedRescues: forcedRescues ?? this.forcedRescues,
      finalLiberties: finalLiberties ?? this.finalLiberties,
    );
  }

  bool isWorseThan(_AtariChaseOutcome other) {
    if (capturedTargetSize != other.capturedTargetSize) {
      return capturedTargetSize > other.capturedTargetSize;
    }
    if (maxGroupSize != other.maxGroupSize) {
      return maxGroupSize > other.maxGroupSize;
    }
    if (forcedRescues != other.forcedRescues) {
      return forcedRescues > other.forcedRescues;
    }
    return finalLiberties < other.finalLiberties;
  }
}

/// Lightweight flat-array board for MCTS simulations.
/// Uses integers instead of enums for speed.
class SimBoard {
  static const int empty = 0;
  static const int black = 1;
  static const int white = 2;

  final int size;
  final int captureTarget;
  final GameMode gameMode;
  final List<int> cells;
  int capturedByBlack;
  int capturedByWhite;
  int currentPlayer;
  int consecutivePasses;
  int _koIndex; // flat index of the forbidden ko point, -1 if none

  SimBoard(this.size,
      {this.captureTarget = 5, this.gameMode = GameMode.capture})
      : cells = List.filled(size * size, 0),
        capturedByBlack = 0,
        capturedByWhite = 0,
        currentPlayer = black,
        consecutivePasses = 0,
        _koIndex = -1;

  SimBoard._internal({
    required this.size,
    required this.captureTarget,
    required this.gameMode,
    required List<int> cells,
    required this.capturedByBlack,
    required this.capturedByWhite,
    required this.currentPlayer,
    required this.consecutivePasses,
    required int koIndex,
  })  : cells = List<int>.from(cells),
        _koIndex = koIndex;

  factory SimBoard.copy(SimBoard other) => SimBoard._internal(
        size: other.size,
        captureTarget: other.captureTarget,
        gameMode: other.gameMode,
        cells: other.cells,
        capturedByBlack: other.capturedByBlack,
        capturedByWhite: other.capturedByWhite,
        currentPlayer: other.currentPlayer,
        consecutivePasses: other.consecutivePasses,
        koIndex: other._koIndex,
      );

  /// Creates a SimBoard from a GameState, setting [aiPlayer] as [white].
  factory SimBoard.fromGameState(GameState state, {int captureTarget = 5}) {
    final sb = SimBoard(
      state.boardSize,
      captureTarget: captureTarget,
      gameMode: state.gameMode,
    );
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
    sb.consecutivePasses = state.consecutivePasses;
    return sb;
  }

  int idx(int r, int c) => r * size + c;

  int colorAt(int r, int c) => cells[idx(r, c)];

  List<int> adjacentIndices(int i) => _adjacent(i);

  Set<int> groupAtIndex(int i) => _findGroup(i);

  Set<int> libertiesForGroup(Set<int> group) => _libertiesForGroup(group);

  List<SimGroupInfo> groupsForPlayer(int playerColor) {
    final groups = <SimGroupInfo>[];
    final visited = <int>{};
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] != playerColor || visited.contains(i)) continue;
      final group = _findGroup(i);
      visited.addAll(group);
      groups.add(SimGroupInfo(
        color: playerColor,
        stones: group,
        liberties: _libertiesForGroup(group),
      ));
    }
    return groups;
  }

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
    return _libertiesForGroup(group).length;
  }

  Set<int> _libertiesForGroup(Set<int> group) {
    final libs = <int>{};
    for (final pos in group) {
      for (final adj in _adjacent(pos)) {
        if (cells[adj] == empty) libs.add(adj);
      }
    }
    return libs;
  }

  /// Applies a move at (r, c). Returns true when valid and applied.
  bool applyMove(int r, int c) {
    if (r < 0 || r >= size || c < 0 || c >= size) return false;

    final i = idx(r, c);
    if (cells[i] != empty) return false;

    final color = currentPlayer;
    final opponent = color == black ? white : black;

    cells[i] = color;
    consecutivePasses = 0;

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

    if (i == _koIndex && captured.length == 1) {
      cells[i] = empty;
      return false;
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

  void applyPass() {
    _koIndex = -1;
    consecutivePasses++;
    currentPlayer = currentPlayer == black ? white : black;
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

  bool get isTerminal => gameMode == GameMode.capture
      ? capturedByBlack >= captureTarget || capturedByWhite >= captureTarget
      : isTerritoryTerminal;

  bool get isTerritoryTerminal => consecutivePasses >= 2;

  /// Returns [black], [white], or 0 (no winner yet).
  int get winner {
    if (gameMode == GameMode.capture) {
      if (capturedByBlack >= captureTarget) return black;
      if (capturedByWhite >= captureTarget) return white;
      return 0;
    }
    if (!isTerritoryTerminal) return 0;
    final blackArea = areaScore(black);
    final whiteArea = areaScore(white);
    if (blackArea == whiteArea) return 0;
    return blackArea > whiteArea ? black : white;
  }

  int areaScore(int player) {
    var stones = 0;
    var territory = 0;
    final visited = <int>{};
    for (var i = 0; i < cells.length; i++) {
      final color = cells[i];
      if (color == player) {
        stones++;
        continue;
      }
      if (color != empty || visited.contains(i)) continue;
      final queue = <int>[i];
      final region = <int>{i};
      visited.add(i);
      final borders = <int>{};
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        for (final adj in _adjacent(cur)) {
          final adjColor = cells[adj];
          if (adjColor == empty) {
            if (visited.add(adj)) {
              region.add(adj);
              queue.add(adj);
            }
          } else {
            borders.add(adjColor);
          }
        }
      }
      if (borders.length == 1 && borders.contains(player)) {
        territory += region.length;
      }
    }
    return stones + territory;
  }

  int estimateAreaDifference({required int forPlayer}) {
    final playerScore = areaScore(forPlayer);
    final opponentScore = areaScore(forPlayer == black ? white : black);
    return playerScore - opponentScore;
  }

  double estimateTerritoryInfluence({required int forPlayer}) {
    final opponent = forPlayer == black ? white : black;
    var score = 0.0;
    for (var i = 0; i < cells.length; i++) {
      final color = cells[i];
      if (color == forPlayer) {
        score += 1.6;
        continue;
      }
      if (color == opponent) {
        score -= 1.6;
        continue;
      }
      var playerDist = 999;
      var opponentDist = 999;
      for (final adj in _adjacentWithinRadius(i, radius: 3)) {
        final adjColor = cells[adj];
        if (adjColor == forPlayer) {
          playerDist = math.min(playerDist, _distance(i, adj));
        } else if (adjColor == opponent) {
          opponentDist = math.min(opponentDist, _distance(i, adj));
        }
      }
      if (playerDist == opponentDist) continue;
      if (playerDist < opponentDist) {
        score += 1.0 / playerDist;
      } else if (opponentDist < playerDist) {
        score -= 1.0 / opponentDist;
      }
    }
    return score;
  }

  Iterable<int> _adjacentWithinRadius(int i, {required int radius}) sync* {
    final row = i ~/ size;
    final col = i % size;
    for (var dr = -radius; dr <= radius; dr++) {
      for (var dc = -radius; dc <= radius; dc++) {
        final nr = row + dr;
        final nc = col + dc;
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        if (dr == 0 && dc == 0) continue;
        yield idx(nr, nc);
      }
    }
  }

  int _distance(int a, int b) {
    final ar = a ~/ size;
    final ac = a % size;
    final br = b ~/ size;
    final bc = b % size;
    return (ar - br).abs() + (ac - bc).abs();
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
              if (cells[ni] == empty) {
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

    if (_koIndex < 0 || !candidates.contains(_koIndex)) {
      return candidates.toList();
    }
    return [
      for (final index in candidates)
        if (index != _koIndex ||
            analyzeMove(index ~/ size, index % size).isLegal)
          index,
    ];
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
