import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/mcts_engine.dart';

void main() {
  test('generated twist ladder samples are replayable capture-go cases', () {
    final file = File('docs/ai_eval/tactics/twist_ladder_samples.json');
    expect(file.existsSync(), isTrue);

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['caseFamily'], 'twist_ladder_doomed_rescue');
    final samples =
        (json['samples'] as List<dynamic>).cast<Map<String, dynamic>>();
    final bySize = <int, int>{};
    final orientationsBySize = <int, Set<String>>{};

    for (final sample in samples) {
      final boardSize = sample['boardSize'] as int;
      bySize[boardSize] = (bySize[boardSize] ?? 0) + 1;
      final sourceTransform = sample['sourceTransform'] as Map<String, dynamic>;
      final orientation = sourceTransform['orientation'] as String;
      orientationsBySize.putIfAbsent(boardSize, () => {}).add(orientation);

      expect(sample['captureTarget'], 5, reason: sample['id'] as String);
      expect(sample['sgf'], isA<String>(), reason: sample['id'] as String);
      expect(sample['entryPly'], isA<int>(), reason: sample['id'] as String);
      expect(sample['blunderPly'], isA<int>(), reason: sample['id'] as String);
      expect(sample['blunderMove'], isA<String>(),
          reason: sample['id'] as String);
      expect(sample['finalCapturePly'], isA<int>(),
          reason: sample['id'] as String);
      expect(sample['finalCaptureMove'], isA<String>(),
          reason: sample['id'] as String);

      final finalCaptureDelta =
          _replayFinalCaptureDelta(sample['sgf'] as String);
      expect(finalCaptureDelta, greaterThanOrEqualTo(5),
          reason: sample['id'] as String);
      expect(sample['finalCaptureDelta'], finalCaptureDelta,
          reason: sample['id'] as String);
      expect(sample['capturedStoneCount'], finalCaptureDelta,
          reason: sample['id'] as String);
    }

    expect(bySize[9], greaterThanOrEqualTo(100));
    expect(bySize[13], greaterThanOrEqualTo(100));
    expect(orientationsBySize[9], hasLength(greaterThanOrEqualTo(8)));
    expect(orientationsBySize[13], hasLength(greaterThanOrEqualTo(8)));
  });
}

int _replayFinalCaptureDelta(String sgf) {
  final sizeMatch = RegExp(r'SZ\[(\d+)\]').firstMatch(sgf);
  expect(sizeMatch, isNotNull, reason: sgf);
  final size = int.parse(sizeMatch!.group(1)!);
  final board = SimBoard(size, captureTarget: 5);

  final setupMatch =
      RegExp(r'^\(;FF\[4\]GM\[1\]SZ\[\d+\]([^;]*)').firstMatch(sgf);
  expect(setupMatch, isNotNull, reason: sgf);
  final setup = setupMatch!.group(1)!;
  for (final point in _setupPoints(setup, 'AB')) {
    board.cells[_index(size, point)] = SimBoard.black;
  }
  for (final point in _setupPoints(setup, 'AW')) {
    board.cells[_index(size, point)] = SimBoard.white;
  }
  board.currentPlayer = SimBoard.black;

  var lastDelta = 0;
  final moves = RegExp(r';([BW])\[([a-z]{2})\]').allMatches(sgf);
  for (final move in moves) {
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

Iterable<String> _setupPoints(String setup, String property) sync* {
  final match = RegExp('$property((?:\\[[a-z]{2}\\])+)', multiLine: false)
      .firstMatch(setup);
  if (match == null) return;
  for (final point in RegExp(r'\[([a-z]{2})\]').allMatches(match.group(1)!)) {
    yield point.group(1)!;
  }
}

int _index(int size, String point) =>
    (point.codeUnitAt(1) - 'a'.codeUnitAt(0)) * size +
    point.codeUnitAt(0) -
    'a'.codeUnitAt(0);
