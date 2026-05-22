import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/mcts_engine.dart';

void main() {
  test('tactical trap corpus has labeled replayable samples', () {
    final file = File('docs/ai_eval/tactics/tactical_trap_corpus.json');
    expect(file.existsSync(), isTrue);

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['schemaVersion'], 1);
    expect(json['corpusId'], 'capture_tactical_traps_v1');
    final families =
        (json['families'] as List<dynamic>).cast<Map<String, dynamic>>();
    final activeFamilyIds = families
        .where((family) => family['status'] == 'active')
        .map((family) => family['id'] as String)
        .toSet();
    expect(activeFamilyIds, hasLength(greaterThanOrEqualTo(3)));

    final samples =
        (json['samples'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(samples.length, greaterThanOrEqualTo(520));

    final splits = <String, int>{};
    final familiesWithSamples = <String>{};
    final samplesByFamily = <String, int>{};
    for (final sample in samples) {
      final id = sample['id'] as String;
      familiesWithSamples.add(sample['family'] as String);
      samplesByFamily.update(sample['family'] as String, (count) => count + 1,
          ifAbsent: () => 1);
      splits.update(sample['split'] as String, (count) => count + 1,
          ifAbsent: () => 1);

      expect(sample['boardSize'], anyOf(9, 13), reason: id);
      expect(sample['captureTarget'], 5, reason: id);
      expect(sample['sideToMove'], anyOf('black', 'white'), reason: id);
      expect(sample['trapType'], isA<String>(), reason: id);
      expect(sample['correctMoveCategory'], isA<String>(), reason: id);
      expect(sample['failureReason'], isA<Map>(), reason: id);
      expect(sample['acceptedMovePolicy'], isA<Map>(), reason: id);
      expect(sample['blunderMoves'], isNotEmpty, reason: id);
      expect(sample['failureContinuation'], isNotEmpty, reason: id);

      final replay = _replayToEntry(sample);
      final blunderMove = (sample['blunderMoves'] as List).single as String;
      final continuation =
          (sample['failureContinuation'] as List).cast<String>();
      expect(continuation.first, blunderMove, reason: id);
      expect(_moveColor(blunderMove), replay.board.currentPlayer, reason: id);
      expect(_isLegalMove(replay.board, blunderMove), isTrue, reason: id);
      expect(replay.playedMoves, sample['entryPly'], reason: id);

      final expectedOutcome =
          sample['expectedOutcomeAfterBlunder'] as Map<String, dynamic>;
      final continuationCaptureDelta =
          _replayContinuationCaptureDelta(replay.board, continuation);
      expect(
        expectedOutcome['capturedStoneCount'],
        continuationCaptureDelta,
        reason: id,
      );

      final finalCaptureDelta =
          _replayFinalCaptureDelta(sample['sgf'] as String);
      expect(
        expectedOutcome['capturedStoneCount'],
        finalCaptureDelta,
        reason: id,
      );
      expect(finalCaptureDelta, greaterThanOrEqualTo(5), reason: id);
    }

    expect(familiesWithSamples, contains('doomed_rescue_twist_ladder'));
    expect(familiesWithSamples, contains('edge_escape_dead_chain'));
    expect(familiesWithSamples, contains('connect_and_die'));
    expect(familiesWithSamples, contains('net_containment'));
    expect(familiesWithSamples, contains('throw_in_snapback'));
    for (final family in activeFamilyIds) {
      expect(samplesByFamily[family], greaterThan(0), reason: family);
    }
    expect(splits['train'], greaterThan(0));
    expect(splits['eval'], greaterThan(0));
  });
}

_EntryReplay _replayToEntry(Map<String, dynamic> sample) {
  final sgf = sample['sgf'] as String;
  final size = _sizeFromSgf(sgf);
  final board = SimBoard(size, captureTarget: sample['captureTarget'] as int);
  _applySetup(board, sgf);
  board.currentPlayer = SimBoard.black;

  final entryPly = sample['entryPly'] as int;
  var playedMoves = 0;
  for (final match in RegExp(r';([BW])\[([a-z]{2})\]').allMatches(sgf)) {
    if (playedMoves >= entryPly) break;
    final color = match.group(1) == 'B' ? SimBoard.black : SimBoard.white;
    final point = match.group(2)!;
    expect(board.currentPlayer, color, reason: '$sgf before $point');
    final index = _index(size, point);
    expect(board.applyMove(index ~/ size, index % size), isTrue,
        reason: '$sgf at $point');
    playedMoves++;
  }
  return _EntryReplay(board, playedMoves);
}

int _replayContinuationCaptureDelta(
  SimBoard entryBoard,
  List<String> continuation,
) {
  final board = SimBoard.copy(entryBoard);
  var lastDelta = 0;
  for (final move in continuation) {
    final color = _moveColor(move);
    expect(board.currentPlayer, color, reason: move);
    final point = _movePoint(move);
    final before =
        color == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
    final index = _index(board.size, point);
    expect(board.applyMove(index ~/ board.size, index % board.size), isTrue,
        reason: move);
    final after =
        color == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
    lastDelta = after - before;
  }
  return lastDelta;
}

int _replayFinalCaptureDelta(String sgf) {
  final size = _sizeFromSgf(sgf);
  final board = SimBoard(size, captureTarget: 5);
  _applySetup(board, sgf);
  board.currentPlayer = SimBoard.black;

  var lastDelta = 0;
  for (final move in RegExp(r';([BW])\[([a-z]{2})\]').allMatches(sgf)) {
    final color = move.group(1) == 'B' ? SimBoard.black : SimBoard.white;
    final point = move.group(2)!;
    expect(board.currentPlayer, color, reason: '$sgf before $point');
    final before =
        color == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
    final index = _index(size, point);
    expect(board.applyMove(index ~/ size, index % size), isTrue,
        reason: '$sgf at $point');
    final after =
        color == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
    lastDelta = after - before;
  }
  return lastDelta;
}

void _applySetup(SimBoard board, String sgf) {
  final setupMatch =
      RegExp(r'^\(;FF\[4\]GM\[1\]SZ\[\d+\]([^;]*)').firstMatch(sgf);
  expect(setupMatch, isNotNull, reason: sgf);
  final setup = setupMatch!.group(1)!;
  for (final point in _setupPoints(setup, 'AB')) {
    board.cells[_index(board.size, point)] = SimBoard.black;
  }
  for (final point in _setupPoints(setup, 'AW')) {
    board.cells[_index(board.size, point)] = SimBoard.white;
  }
}

int _sizeFromSgf(String sgf) {
  final sizeMatch = RegExp(r'SZ\[(\d+)\]').firstMatch(sgf);
  expect(sizeMatch, isNotNull, reason: sgf);
  return int.parse(sizeMatch!.group(1)!);
}

Iterable<String> _setupPoints(String setup, String property) sync* {
  final match = RegExp('$property((?:\\[[a-z]{2}\\])+)', multiLine: false)
      .firstMatch(setup);
  if (match == null) return;
  for (final point in RegExp(r'\[([a-z]{2})\]').allMatches(match.group(1)!)) {
    yield point.group(1)!;
  }
}

bool _isLegalMove(SimBoard board, String move) {
  final point = _movePoint(move);
  final index = _index(board.size, point);
  return board.analyzeMove(index ~/ board.size, index % board.size).isLegal;
}

int _moveColor(String move) {
  if (move.startsWith('B[')) return SimBoard.black;
  if (move.startsWith('W[')) return SimBoard.white;
  throw ArgumentError.value(move, 'move');
}

String _movePoint(String move) {
  final match = RegExp(r'^[BW]\[([a-z]{2})\]$').firstMatch(move);
  if (match == null) throw ArgumentError.value(move, 'move');
  return match.group(1)!;
}

int _index(int size, String point) =>
    (point.codeUnitAt(1) - 'a'.codeUnitAt(0)) * size +
    point.codeUnitAt(0) -
    'a'.codeUnitAt(0);

class _EntryReplay {
  const _EntryReplay(this.board, this.playedMoves);

  final SimBoard board;
  final int playedMoves;
}
