import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:go_puzzle/game/mcts_engine.dart';

const _baseMinCol = 4;
const _baseMinRow = 1;
const _baseWidth = 9;
const _baseHeight = 8;

const _baseBlack = ['gf', 'gh'];
const _baseWhite = ['fg', 'hg'];
const _baseMoves = <(int, String)>[
  (SimBoard.black, 'hf'),
  (SimBoard.white, 'gg'),
  (SimBoard.black, 'ig'),
  (SimBoard.white, 'ff'),
  (SimBoard.black, 'fe'),
  (SimBoard.white, 'fh'),
  (SimBoard.black, 'ef'),
  (SimBoard.white, 'hh'),
  (SimBoard.black, 'gi'),
  (SimBoard.white, 'ih'),
  (SimBoard.black, 'jh'),
  (SimBoard.white, 'if'),
  (SimBoard.black, 'jg'),
  (SimBoard.white, 'ge'),
  (SimBoard.black, 'he'),
  (SimBoard.white, 'gd'),
  (SimBoard.black, 'ie'),
  (SimBoard.white, 'jf'),
  (SimBoard.black, 'kf'),
  (SimBoard.white, 'je'),
  (SimBoard.black, 'jd'),
  (SimBoard.white, 'ke'),
  (SimBoard.black, 'le'),
  (SimBoard.white, 'kd'),
  (SimBoard.black, 'kc'),
  (SimBoard.white, 'ld'),
  (SimBoard.black, 'md'),
  (SimBoard.white, 'lc'),
  (SimBoard.black, 'lb'),
  (SimBoard.white, 'id'),
  (SimBoard.black, 'mc'),
];

void main(List<String> args) {
  final outPath = args.isEmpty
      ? 'docs/ai_eval/tactics/twist_ladder_samples.json'
      : args.single;
  final samples = [
    ..._generateForSize(9, 100),
    ..._generateForSize(13, 100),
  ];
  final output = {
    'schemaVersion': 1,
    'caseFamily': 'twist_ladder_doomed_rescue',
    'description':
        'Generated capture-go twist-ladder samples. Each sample is validated by replay: White enters at the blunder move, then Black eventually captures at least five stones.',
    'samples': samples,
  };
  const encoder = JsonEncoder.withIndent('  ');
  File(outPath)
    ..createSync(recursive: true)
    ..writeAsStringSync('${encoder.convert(output)}\n');
  stdout.writeln('wrote ${samples.length} samples to $outPath');
}

List<Map<String, Object?>> _generateForSize(int size, int targetCount) {
  final candidatesByOrientation = <String, List<_GeneratedTwistSample>>{};
  final seen = <String>{};
  var variant = 0;
  for (final orientation in _orientations) {
    final orientationCandidates =
        candidatesByOrientation.putIfAbsent(orientation.name, () => []);
    final maxColOffset = size - orientation.width;
    final maxRowOffset = size - orientation.height;
    if (maxColOffset < 0 || maxRowOffset < 0) continue;
    for (var rowOffset = 0; rowOffset <= maxRowOffset; rowOffset++) {
      for (var colOffset = 0; colOffset <= maxColOffset; colOffset++) {
        for (var noise = 0; noise < 12; noise++) {
          final candidate = _buildCandidate(
            size: size,
            orientation: orientation,
            colOffset: colOffset,
            rowOffset: rowOffset,
            noiseSeed: variant + noise * 97,
          );
          variant++;
          if (candidate == null || !seen.add(candidate.sgf)) continue;
          orientationCandidates.add(candidate);
        }
      }
    }
  }

  final selected = <_GeneratedTwistSample>[];
  final offsets = <String, int>{};
  while (selected.length < targetCount) {
    var addedThisRound = false;
    for (final orientation in _orientations) {
      final candidates = candidatesByOrientation[orientation.name] ?? const [];
      final offset = offsets[orientation.name] ?? 0;
      if (offset >= candidates.length) continue;
      selected.add(candidates[offset]);
      offsets[orientation.name] = offset + 1;
      addedThisRound = true;
      if (selected.length >= targetCount) break;
    }
    if (!addedThisRound) break;
  }

  if (selected.length >= targetCount) {
    return [
      for (var i = 0; i < selected.length; i++) selected[i].toJson(i + 1),
    ];
  }
  throw StateError(
      'Only generated ${selected.length} samples for $size x $size');
}

_GeneratedTwistSample? _buildCandidate({
  required int size,
  required _Orientation orientation,
  required int colOffset,
  required int rowOffset,
  required int noiseSeed,
}) {
  String transform(String point) {
    final baseCol = point.codeUnitAt(0) - 'a'.codeUnitAt(0) - _baseMinCol;
    final baseRow = point.codeUnitAt(1) - 'a'.codeUnitAt(0) - _baseMinRow;
    final transformed = orientation.transform(baseCol, baseRow);
    final col = transformed.$1;
    final row = transformed.$2;
    return _point(col + colOffset, row + rowOffset);
  }

  final black = _baseBlack.map(transform).toList();
  final white = _baseWhite.map(transform).toList();
  final moves = [
    for (final move in _baseMoves) (move.$1, transform(move.$2)),
  ];
  final occupied = <String>{...black, ...white, for (final m in moves) m.$2};
  _addNoise(
    size: size,
    seed: noiseSeed,
    occupied: occupied,
    black: black,
    white: white,
  );

  final finalCaptureDelta = _validate(
    size: size,
    black: black,
    white: white,
    moves: moves,
  );
  if (finalCaptureDelta < 5) return null;
  return _GeneratedTwistSample(
    size: size,
    black: black,
    white: white,
    moves: moves,
    sourceTransform: {
      'orientation': orientation.name,
      'transformedWidth': orientation.width,
      'transformedHeight': orientation.height,
      'colOffset': colOffset,
      'rowOffset': rowOffset,
      'noiseSeed': noiseSeed,
    },
    finalCaptureDelta: finalCaptureDelta,
  );
}

void _addNoise({
  required int size,
  required int seed,
  required Set<String> occupied,
  required List<String> black,
  required List<String> white,
}) {
  final random = math.Random(seed);
  final candidates = <String>[];
  for (var row = 0; row < size; row++) {
    for (var col = 0; col < size; col++) {
      final point = _point(col, row);
      if (occupied.contains(point)) continue;
      if (_adjacentPoints(size, point).any(occupied.contains)) continue;
      candidates.add(point);
    }
  }
  candidates.shuffle(random);
  final pairs = math.min(2, candidates.length ~/ 2);
  for (var i = 0; i < pairs; i++) {
    final b = candidates[i * 2];
    final w = candidates[i * 2 + 1];
    black.add(b);
    white.add(w);
    occupied
      ..add(b)
      ..add(w);
  }
}

int _validate({
  required int size,
  required List<String> black,
  required List<String> white,
  required List<(int, String)> moves,
}) {
  final board = SimBoard(size, captureTarget: 5);
  for (final point in black) {
    board.cells[_index(size, point)] = SimBoard.black;
  }
  for (final point in white) {
    board.cells[_index(size, point)] = SimBoard.white;
  }
  board.currentPlayer = SimBoard.black;
  var lastDelta = 0;
  for (final move in moves) {
    if (board.currentPlayer != move.$1) return -1;
    final before = move.$1 == SimBoard.black
        ? board.capturedByBlack
        : board.capturedByWhite;
    final index = _index(size, move.$2);
    if (!board.applyMove(index ~/ size, index % size)) return -1;
    final after = move.$1 == SimBoard.black
        ? board.capturedByBlack
        : board.capturedByWhite;
    lastDelta = after - before;
  }
  return lastDelta;
}

String _sgf({
  required int size,
  required List<String> black,
  required List<String> white,
  required List<(int, String)> moves,
}) {
  final buffer = StringBuffer('(;FF[4]GM[1]SZ[$size]');
  if (black.isNotEmpty) {
    buffer.write('AB${black.map((p) => '[$p]').join()}');
  }
  if (white.isNotEmpty) {
    buffer.write('AW${white.map((p) => '[$p]').join()}');
  }
  for (final move in moves) {
    buffer.write(';${move.$1 == SimBoard.black ? 'B' : 'W'}[${move.$2}]');
  }
  buffer.write(')');
  return buffer.toString();
}

int _index(int size, String point) =>
    (point.codeUnitAt(1) - 'a'.codeUnitAt(0)) * size +
    point.codeUnitAt(0) -
    'a'.codeUnitAt(0);

String _point(int col, int row) =>
    String.fromCharCodes([col + 'a'.codeUnitAt(0), row + 'a'.codeUnitAt(0)]);

Iterable<String> _adjacentPoints(int size, String point) sync* {
  final col = point.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final row = point.codeUnitAt(1) - 'a'.codeUnitAt(0);
  for (final delta in const [
    (0, -1),
    (0, 1),
    (-1, 0),
    (1, 0),
  ]) {
    final nextCol = col + delta.$1;
    final nextRow = row + delta.$2;
    if (nextCol < 0 || nextCol >= size || nextRow < 0 || nextRow >= size) {
      continue;
    }
    yield _point(nextCol, nextRow);
  }
}

const _orientations = [
  _Orientation(
    name: 'identity',
    width: _baseWidth,
    height: _baseHeight,
    transform: _identity,
  ),
  _Orientation(
    name: 'mirror_x',
    width: _baseWidth,
    height: _baseHeight,
    transform: _mirrorX,
  ),
  _Orientation(
    name: 'mirror_y',
    width: _baseWidth,
    height: _baseHeight,
    transform: _mirrorY,
  ),
  _Orientation(
    name: 'rotate_180',
    width: _baseWidth,
    height: _baseHeight,
    transform: _rotate180,
  ),
  _Orientation(
    name: 'rotate_90_cw',
    width: _baseHeight,
    height: _baseWidth,
    transform: _rotate90Cw,
  ),
  _Orientation(
    name: 'rotate_90_ccw',
    width: _baseHeight,
    height: _baseWidth,
    transform: _rotate90Ccw,
  ),
  _Orientation(
    name: 'transpose',
    width: _baseHeight,
    height: _baseWidth,
    transform: _transpose,
  ),
  _Orientation(
    name: 'anti_transpose',
    width: _baseHeight,
    height: _baseWidth,
    transform: _antiTranspose,
  ),
];

typedef _PointTransform = (int, int) Function(int col, int row);

class _Orientation {
  const _Orientation({
    required this.name,
    required this.width,
    required this.height,
    required this.transform,
  });

  final String name;
  final int width;
  final int height;
  final _PointTransform transform;
}

(int, int) _identity(int col, int row) => (col, row);

(int, int) _mirrorX(int col, int row) => (_baseWidth - 1 - col, row);

(int, int) _mirrorY(int col, int row) => (col, _baseHeight - 1 - row);

(int, int) _rotate180(int col, int row) =>
    (_baseWidth - 1 - col, _baseHeight - 1 - row);

(int, int) _rotate90Cw(int col, int row) => (_baseHeight - 1 - row, col);

(int, int) _rotate90Ccw(int col, int row) => (row, _baseWidth - 1 - col);

(int, int) _transpose(int col, int row) => (row, col);

(int, int) _antiTranspose(int col, int row) =>
    (_baseHeight - 1 - row, _baseWidth - 1 - col);

class _GeneratedTwistSample {
  const _GeneratedTwistSample({
    required this.size,
    required this.black,
    required this.white,
    required this.moves,
    required this.sourceTransform,
    required this.finalCaptureDelta,
  });

  final int size;
  final List<String> black;
  final List<String> white;
  final List<(int, String)> moves;
  final Map<String, Object?> sourceTransform;
  final int finalCaptureDelta;

  String get sgf => _sgf(size: size, black: black, white: white, moves: moves);

  Map<String, Object?> toJson(int ordinal) => {
        'id':
            'twist-ladder-${size}x$size-${ordinal.toString().padLeft(3, '0')}',
        'boardSize': size,
        'captureTarget': 5,
        'source': 'generated_from_twist_ladder_seed_v1',
        'sourceTransform': sourceTransform,
        'sgf': sgf,
        'entryPly': 18,
        'blunderPly': 18,
        'blunderMove': _moveText(moves[17]),
        'finalCapturePly': 31,
        'finalCaptureMove': _moveText(moves.last),
        'finalCaptureDelta': finalCaptureDelta,
        'capturedStoneCount': finalCaptureDelta,
        'failureType': 'doomed_rescue_twist_ladder',
      };

  String _moveText((int, String) move) =>
      '${move.$1 == SimBoard.black ? 'B' : 'W'}[${move.$2}]';
}
