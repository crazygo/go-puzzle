import 'dart:io';
import 'dart:typed_data';

import 'package:go_puzzle/game/board_image_recognizer.dart';
import 'package:go_puzzle/models/board_position.dart';

Future<void> main() async {
  final dir = Directory('test/assets/recognition_samples');
  final truthFiles = dir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var totalPoints = 0;
  var totalCorrectPoints = 0;
  var totalExpectedStones = 0;
  var totalPredictedStones = 0;
  var totalCorrectStones = 0;
  final failedSamples = <String>[];

  for (final truthFile in truthFiles) {
    final sampleId = truthFile.uri.pathSegments.last.replaceAll('.txt', '');
    final imageFile = File('${dir.path}/$sampleId.png');
    final truth = await _loadTruth(truthFile);
    final result = BoardImageRecognizer.recognize(
      Uint8List.fromList(await imageFile.readAsBytes()),
    );

    final stats = _score(result, truth);
    totalPoints += stats.totalPoints;
    totalCorrectPoints += stats.correctPoints;
    totalExpectedStones += stats.expectedStones;
    totalPredictedStones += stats.predictedStones;
    totalCorrectStones += stats.correctStones;
    if (!stats.exact || result.boardSize != truth.boardSize) {
      failedSamples.add(sampleId);
    }

    print('sample: $sampleId');
    print(
      '  size expected=${truth.boardSize} predicted=${result.boardSize} '
      'confidence=${(result.confidence * 100).toStringAsFixed(1)}%',
    );
    print(
      '  points ${stats.correctPoints}/${stats.totalPoints} '
      '(${_pct(stats.correctPoints, stats.totalPoints)})',
    );
    print(
      '  stones correct=${stats.correctStones} expected=${stats.expectedStones} '
      'predicted=${stats.predictedStones} precision=${_pct(stats.correctStones, stats.predictedStones)} '
      'recall=${_pct(stats.correctStones, stats.expectedStones)}',
    );
    print(
      '  predicted B=${stats.predictedBlack} W=${stats.predictedWhite} '
      'empty=${stats.predictedEmpty}',
    );
    if (stats.mismatches.isEmpty) {
      print('  mismatches: none');
    } else {
      print('  mismatches:');
      for (final mismatch in stats.mismatches.take(40)) {
        print('    $mismatch');
      }
      if (stats.mismatches.length > 40) {
        print('    ... ${stats.mismatches.length - 40} more');
      }
    }
  }

  print('');
  print('overall:');
  print(
    '  points $totalCorrectPoints/$totalPoints '
    '(${_pct(totalCorrectPoints, totalPoints)})',
  );
  print(
    '  stones correct=$totalCorrectStones expected=$totalExpectedStones '
    'predicted=$totalPredictedStones '
    'precision=${_pct(totalCorrectStones, totalPredictedStones)} '
    'recall=${_pct(totalCorrectStones, totalExpectedStones)}',
  );
  print(
    '  exact samples ${truthFiles.length - failedSamples.length}/${truthFiles.length}',
  );
  if (failedSamples.isNotEmpty) {
    print('  failed samples: ${failedSamples.join(', ')}');
  }
}

Future<_Truth> _loadTruth(File file) async {
  final lines = await file.readAsLines();
  final boardSize = int.parse(lines.first.split(RegExp(r'\s+')).last);
  final board = List.generate(
    boardSize,
    (_) => List<StoneColor>.filled(boardSize, StoneColor.empty),
  );
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',');
    final color = parts[0] == 'B' ? StoneColor.black : StoneColor.white;
    final position = _parseGoCoord(parts[1], boardSize);
    board[position.row][position.col] = color;
  }
  return _Truth(boardSize: boardSize, board: board);
}

_Stats _score(BoardRecognitionResult result, _Truth truth) {
  if (result.boardSize != truth.boardSize) {
    return _Stats(
      totalPoints: truth.boardSize * truth.boardSize,
      correctPoints: 0,
      expectedStones: _countStones(truth.board),
      predictedStones: _countStones(result.board),
      correctStones: 0,
      predictedBlack: _countColor(result.board, StoneColor.black),
      predictedWhite: _countColor(result.board, StoneColor.white),
      predictedEmpty: _countColor(result.board, StoneColor.empty),
      mismatches: ['board size mismatch'],
    );
  }

  var correctPoints = 0;
  var expectedStones = 0;
  var predictedStones = 0;
  var correctStones = 0;
  var predictedBlack = 0;
  var predictedWhite = 0;
  var predictedEmpty = 0;
  final mismatches = <String>[];

  for (var row = 0; row < truth.boardSize; row++) {
    for (var col = 0; col < truth.boardSize; col++) {
      final expected = truth.board[row][col];
      final predicted = result.board[row][col];
      if (expected != StoneColor.empty) expectedStones++;
      if (predicted != StoneColor.empty) predictedStones++;
      if (predicted == StoneColor.black) predictedBlack++;
      if (predicted == StoneColor.white) predictedWhite++;
      if (predicted == StoneColor.empty) predictedEmpty++;
      if (expected == predicted) {
        correctPoints++;
        if (expected != StoneColor.empty) correctStones++;
      } else {
        mismatches.add(
          '${_formatCoord(BoardPosition(row, col), truth.boardSize)} '
          'expected=${_shortColor(expected)} predicted=${_shortColor(predicted)}',
        );
      }
    }
  }

  return _Stats(
    totalPoints: truth.boardSize * truth.boardSize,
    correctPoints: correctPoints,
    expectedStones: expectedStones,
    predictedStones: predictedStones,
    correctStones: correctStones,
    predictedBlack: predictedBlack,
    predictedWhite: predictedWhite,
    predictedEmpty: predictedEmpty,
    mismatches: mismatches,
  );
}

int _countStones(List<List<StoneColor>> board) {
  return board.expand((row) => row).where((c) => c != StoneColor.empty).length;
}

int _countColor(List<List<StoneColor>> board, StoneColor color) {
  return board.expand((row) => row).where((c) => c == color).length;
}

BoardPosition _parseGoCoord(String coord, int boardSize) {
  var col = coord.codeUnitAt(0) - 'A'.codeUnitAt(0);
  if (col > 8) col--;
  final rowNumber = int.parse(coord.substring(1));
  return BoardPosition(boardSize - rowNumber, col);
}

String _formatCoord(BoardPosition position, int boardSize) {
  final colCode = position.col >= 8 ? position.col + 1 : position.col;
  return '${String.fromCharCode('A'.codeUnitAt(0) + colCode)}'
      '${boardSize - position.row}';
}

String _shortColor(StoneColor color) {
  return switch (color) {
    StoneColor.black => 'B',
    StoneColor.white => 'W',
    StoneColor.empty => '.',
  };
}

String _pct(int numerator, int denominator) {
  if (denominator == 0) return 'n/a';
  return '${(numerator / denominator * 100).toStringAsFixed(1)}%';
}

class _Truth {
  const _Truth({required this.boardSize, required this.board});
  final int boardSize;
  final List<List<StoneColor>> board;
}

class _Stats {
  const _Stats({
    required this.totalPoints,
    required this.correctPoints,
    required this.expectedStones,
    required this.predictedStones,
    required this.correctStones,
    required this.predictedBlack,
    required this.predictedWhite,
    required this.predictedEmpty,
    required this.mismatches,
  });

  final int totalPoints;
  final int correctPoints;
  final int expectedStones;
  final int predictedStones;
  final int correctStones;
  final int predictedBlack;
  final int predictedWhite;
  final int predictedEmpty;
  final List<String> mismatches;

  bool get exact => mismatches.isEmpty;
}
