import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:go_puzzle/game/mcts_engine.dart';

void main(List<String> args) {
  final sourcePath = args.isNotEmpty
      ? args[0]
      : 'docs/ai_eval/tactics/twist_ladder_samples.json';
  final outPath = args.length > 1
      ? args[1]
      : 'docs/ai_eval/tactics/tactical_trap_corpus.json';

  final source =
      jsonDecode(File(sourcePath).readAsStringSync()) as Map<String, dynamic>;
  final twistSamples =
      (source['samples'] as List<dynamic>).cast<Map<String, dynamic>>();

  final samples = <Map<String, Object?>>[];
  final familySizeCounters = <String, int>{};
  for (final sample in twistSamples) {
    final boardSize = sample['boardSize'] as int;
    final family = sample['failureType'] as String;
    final key = '$family::$boardSize';
    final ordinal = (familySizeCounters[key] ?? 0) + 1;
    familySizeCounters[key] = ordinal;
    samples.add(_trapSampleFromTwist(sample, ordinal));
  }
  for (final sample in [
    ..._generateEdgeEscapeDeadChainSamples(9, 40),
    ..._generateEdgeEscapeDeadChainSamples(13, 40),
    ..._generateConnectAndDieSamples(9, 40),
    ..._generateConnectAndDieSamples(13, 40),
    ..._generateNetContainmentSamples(9, 40),
    ..._generateNetContainmentSamples(13, 40),
    ..._generateThrowInSnapbackSamples(9, 40),
    ..._generateThrowInSnapbackSamples(13, 40),
  ]) {
    samples.add(sample);
  }

  final output = {
    'schemaVersion': 1,
    'corpusId': 'capture_tactical_traps_v1',
    'description':
        'Generated capture-go tactical trap corpus. Each sample labels the side to move, known blunder move(s), acceptance policy, failure reason, and train/eval split.',
    'families': [
      {
        'id': 'doomed_rescue_twist_ladder',
        'status': 'active',
        'description':
            'A chain can extend in atari, but the extension remains tactically doomed and eventually loses at least five stones.',
      },
      {
        'id': 'connect_and_die',
        'status': 'active',
        'description':
            'A connection looks locally positive but leaves the connected chain short of liberties.',
      },
      {
        'id': 'throw_in_snapback',
        'status': 'active',
        'description':
            'A sacrifice move invites capture and then wins the recapture or capture race.',
      },
      {
        'id': 'edge_escape_dead_chain',
        'status': 'active',
        'description':
            'A side or corner escape route is finite; running only increases eventual capture loss.',
      },
      {
        'id': 'net_containment',
        'status': 'active',
        'description':
            'A quiet containment move beats direct atari by removing all useful escape routes.',
      },
    ],
    'metrics': {
      'trapBlunderRate':
          'selected move is in blunderMoves, counted over evaluated samples',
      'acceptedMoveRate':
          'selected move satisfies acceptedMovePolicy and is not in blunderMoves',
      'holdoutAcceptedMoveRate':
          'acceptedMoveRate restricted to samples with split == eval',
    },
    'samples': samples,
  };

  const encoder = JsonEncoder.withIndent('  ');
  File(outPath)
    ..createSync(recursive: true)
    ..writeAsStringSync('${encoder.convert(output)}\n');
  stdout.writeln('wrote ${samples.length} trap samples to $outPath');
}

Map<String, Object?> _trapSampleFromTwist(
  Map<String, dynamic> sample,
  int ordinal,
) {
  final boardSize = sample['boardSize'] as int;
  final blunderMove = sample['blunderMove'] as String;
  final sideToMove = blunderMove.startsWith('B[') ? 'black' : 'white';
  final blunderPly = sample['blunderPly'] as int;
  final split = ordinal % 10 <= 7 && ordinal % 10 != 0 ? 'train' : 'eval';
  final sourceId = sample['id'] as String;
  return {
    'id': 'trap-$sourceId',
    'sourceSampleId': sourceId,
    'family': 'doomed_rescue_twist_ladder',
    'trapType': 'doomed_rescue',
    'boardSize': boardSize,
    'captureTarget': sample['captureTarget'],
    'split': split,
    'sideToMove': sideToMove,
    'sgf': sample['sgf'],
    'entryPly': blunderPly - 1,
    'sourceEntryPly': sample['entryPly'],
    'blunderPly': blunderPly,
    'blunderMoves': [blunderMove],
    'correctMoveCategory': 'avoid_doomed_rescue',
    'failureContinuation': _failureContinuationFromSgf(
      sample['sgf'] as String,
      entryPly: blunderPly - 1,
    ),
    'acceptedMoves': <String>[],
    'acceptedMovePolicy': {
      'type': 'avoid_listed_blunders',
      'description':
          'Any legal move outside blunderMoves is provisionally accepted until a family-specific accepted move set is generated.',
    },
    'failureReason': {
      'code': 'doomed_rescue_loses_capture_race',
      'description':
          'The marked rescue extends a white chain, but black can continue the forcing sequence and capture enough stones to reach the five-capture target.',
    },
    'expectedOutcomeAfterBlunder': {
      'winner': 'black',
      'finalCapturePly': sample['finalCapturePly'],
      'finalCaptureMove': sample['finalCaptureMove'],
      'capturedStoneCount': sample['capturedStoneCount'],
    },
    'sourceTransform': sample['sourceTransform'],
  };
}

List<Map<String, Object?>> _generateEdgeEscapeDeadChainSamples(
  int size,
  int targetCount,
) {
  final candidates = <Map<String, Object?>>[];
  final seen = <String>{};
  var ordinal = 0;
  var noiseSeed = 0;
  while (candidates.length < targetCount && noiseSeed < 2000) {
    for (final side in _edgeSides) {
      for (var start = 1; start + 6 < size; start++) {
        final sample = _buildEdgeEscapeDeadChainSample(
          size: size,
          side: side,
          start: start,
          ordinal: ordinal + 1,
          noiseSeed: noiseSeed,
        );
        noiseSeed++;
        if (sample == null) continue;
        final sgf = sample['sgf']! as String;
        if (!seen.add(sgf)) continue;
        ordinal++;
        candidates.add(sample);
        if (candidates.length >= targetCount) break;
      }
      if (candidates.length >= targetCount) break;
    }
  }
  if (candidates.length < targetCount) {
    throw StateError(
      'Only generated ${candidates.length} edge escape samples for $size x $size',
    );
  }
  return candidates;
}

Map<String, Object?>? _buildEdgeEscapeDeadChainSample({
  required int size,
  required _EdgeSide side,
  required int start,
  required int ordinal,
  required int noiseSeed,
}) {
  String edgePoint(int along) => switch (side) {
        _EdgeSide.left => _point(0, along),
        _EdgeSide.right => _point(size - 1, along),
        _EdgeSide.top => _point(along, 0),
        _EdgeSide.bottom => _point(along, size - 1),
      };
  String innerPoint(int along) => switch (side) {
        _EdgeSide.left => _point(1, along),
        _EdgeSide.right => _point(size - 2, along),
        _EdgeSide.top => _point(along, 1),
        _EdgeSide.bottom => _point(along, size - 2),
      };

  final black = <String>[
    edgePoint(start - 1),
    for (var along = start; along <= start + 5; along++) innerPoint(along),
  ];
  final white = <String>[
    for (var along = start; along <= start + 4; along++) edgePoint(along),
  ];
  final reserved = <String>{
    ...black,
    ...white,
    edgePoint(start + 5),
    edgePoint(start + 6),
  };
  _addNoise(
    size: size,
    seed: noiseSeed,
    occupied: reserved,
    black: black,
    white: white,
  );
  final firstBlackMove = _chooseFirstBlackMove(size, reserved);
  if (firstBlackMove == null) return null;
  final moves = <(int, String)>[
    (SimBoard.black, firstBlackMove),
    (SimBoard.white, edgePoint(start + 5)),
    (SimBoard.black, edgePoint(start + 6)),
  ];

  final finalCaptureDelta = _validate(
    size: size,
    black: black,
    white: white,
    moves: moves,
  );
  if (finalCaptureDelta < 5) return null;

  final id =
      'edge-escape-dead-chain-${size}x$size-${ordinal.toString().padLeft(3, '0')}';
  return {
    'id': 'trap-$id',
    'sourceSampleId': id,
    'family': 'edge_escape_dead_chain',
    'trapType': 'edge_escape_dead_chain',
    'boardSize': size,
    'captureTarget': 5,
    'split': ordinal % 10 <= 7 && ordinal % 10 != 0 ? 'train' : 'eval',
    'sideToMove': 'white',
    'sgf': _sgf(size: size, black: black, white: white, moves: moves),
    'entryPly': 1,
    'blunderPly': 2,
    'blunderMoves': [_moveText(moves[1])],
    'correctMoveCategory': 'avoid_finite_edge_escape',
    'failureContinuation': [
      for (final move in moves.skip(1)) _moveText(move),
    ],
    'acceptedMoves': <String>[],
    'acceptedMovePolicy': {
      'type': 'avoid_listed_blunders',
      'description':
          'Any legal move outside the edge escape blunder is provisionally accepted until a stronger outcome evaluator is attached.',
    },
    'failureReason': {
      'code': 'edge_escape_has_single_boundary_liberty',
      'description':
          'The white edge chain can run one step, but the board edge and black inner wall leave only one new liberty. Black fills it and captures the chain.',
    },
    'expectedOutcomeAfterBlunder': {
      'winner': 'black',
      'finalCapturePly': 3,
      'finalCaptureMove': _moveText(moves.last),
      'capturedStoneCount': finalCaptureDelta,
    },
    'sourceTransform': {
      'side': side.name,
      'start': start,
      'noiseSeed': noiseSeed,
    },
  };
}

List<Map<String, Object?>> _generateConnectAndDieSamples(
  int size,
  int targetCount,
) {
  final candidates = <Map<String, Object?>>[];
  final seen = <String>{};
  var ordinal = 0;
  var noiseSeed = 0;
  while (candidates.length < targetCount && noiseSeed < 3000) {
    for (final orientation in _connectOrientations) {
      final maxColOffset = size - orientation.width;
      final maxRowOffset = size - orientation.height;
      if (maxColOffset < 0 || maxRowOffset < 0) continue;
      for (var rowOffset = 0; rowOffset <= maxRowOffset; rowOffset++) {
        for (var colOffset = 0; colOffset <= maxColOffset; colOffset++) {
          final sample = _buildConnectAndDieSample(
            size: size,
            orientation: orientation,
            colOffset: colOffset,
            rowOffset: rowOffset,
            ordinal: ordinal + 1,
            noiseSeed: noiseSeed,
          );
          noiseSeed++;
          if (sample == null) continue;
          final sgf = sample['sgf']! as String;
          if (!seen.add(sgf)) continue;
          ordinal++;
          candidates.add(sample);
          if (candidates.length >= targetCount) break;
        }
        if (candidates.length >= targetCount) break;
      }
      if (candidates.length >= targetCount) break;
    }
  }
  if (candidates.length < targetCount) {
    throw StateError(
      'Only generated ${candidates.length} connect-and-die samples for $size x $size',
    );
  }
  return candidates;
}

Map<String, Object?>? _buildConnectAndDieSample({
  required int size,
  required _ConnectOrientation orientation,
  required int colOffset,
  required int rowOffset,
  required int ordinal,
  required int noiseSeed,
}) {
  String transform((int, int) point) {
    final transformed = orientation.transform(point.$1, point.$2);
    return _point(transformed.$1 + colOffset, transformed.$2 + rowOffset);
  }

  const baseWhite = [
    (1, 1),
    (2, 1),
    (4, 1),
    (5, 1),
    (6, 1),
  ];
  const baseBlack = [
    (0, 1),
    (1, 0),
    (2, 0),
    (3, 0),
    (4, 0),
    (5, 0),
    (6, 0),
    (1, 2),
    (2, 2),
    (3, 2),
    (4, 2),
    (5, 2),
    (6, 2),
  ];
  const baseBlunder = (3, 1);
  const baseFinal = (7, 1);

  final black = [for (final point in baseBlack) transform(point)];
  final white = [for (final point in baseWhite) transform(point)];
  final blunderPoint = transform(baseBlunder);
  final finalPoint = transform(baseFinal);
  final reserved = <String>{...black, ...white, blunderPoint, finalPoint};
  _addNoise(
    size: size,
    seed: noiseSeed,
    occupied: reserved,
    black: black,
    white: white,
  );
  final firstBlackMove = _chooseFirstBlackMove(size, reserved);
  if (firstBlackMove == null) return null;
  final moves = <(int, String)>[
    (SimBoard.black, firstBlackMove),
    (SimBoard.white, blunderPoint),
    (SimBoard.black, finalPoint),
  ];

  final finalCaptureDelta = _validate(
    size: size,
    black: black,
    white: white,
    moves: moves,
  );
  if (finalCaptureDelta < 5) return null;

  final id =
      'connect-and-die-${size}x$size-${ordinal.toString().padLeft(3, '0')}';
  return {
    'id': 'trap-$id',
    'sourceSampleId': id,
    'family': 'connect_and_die',
    'trapType': 'connect_and_die',
    'boardSize': size,
    'captureTarget': 5,
    'split': ordinal % 10 <= 7 && ordinal % 10 != 0 ? 'train' : 'eval',
    'sideToMove': 'white',
    'sgf': _sgf(size: size, black: black, white: white, moves: moves),
    'entryPly': 1,
    'blunderPly': 2,
    'blunderMoves': [_moveText(moves[1])],
    'correctMoveCategory': 'avoid_false_connection',
    'failureContinuation': [
      for (final move in moves.skip(1)) _moveText(move),
    ],
    'acceptedMoves': <String>[],
    'acceptedMovePolicy': {
      'type': 'avoid_continuation_failure',
      'description':
          'Any legal move outside the false connection is provisionally accepted until a broader outcome evaluator is attached.',
    },
    'failureReason': {
      'code': 'false_connection_self_shortage_of_liberties',
      'description':
          'The connection joins two white chains, but the merged chain has only one remaining liberty. Black fills it and captures at least five stones.',
    },
    'expectedOutcomeAfterBlunder': {
      'winner': 'black',
      'finalCapturePly': 3,
      'finalCaptureMove': _moveText(moves.last),
      'capturedStoneCount': finalCaptureDelta,
    },
    'sourceTransform': {
      'orientation': orientation.name,
      'transformedWidth': orientation.width,
      'transformedHeight': orientation.height,
      'colOffset': colOffset,
      'rowOffset': rowOffset,
      'noiseSeed': noiseSeed,
    },
  };
}

List<Map<String, Object?>> _generateNetContainmentSamples(
  int size,
  int targetCount,
) {
  final candidates = <Map<String, Object?>>[];
  final seen = <String>{};
  var ordinal = 0;
  var noiseSeed = 0;
  while (candidates.length < targetCount && noiseSeed < 4000) {
    for (final orientation in _netOrientations) {
      final maxColOffset = size - orientation.width;
      final maxRowOffset = size - orientation.height;
      if (maxColOffset < 0 || maxRowOffset < 0) continue;
      for (var rowOffset = 0; rowOffset <= maxRowOffset; rowOffset++) {
        for (var colOffset = 0; colOffset <= maxColOffset; colOffset++) {
          final sample = _buildNetContainmentSample(
            size: size,
            orientation: orientation,
            colOffset: colOffset,
            rowOffset: rowOffset,
            ordinal: ordinal + 1,
            noiseSeed: noiseSeed,
          );
          noiseSeed++;
          if (sample == null) continue;
          final sgf = sample['sgf']! as String;
          if (!seen.add(sgf)) continue;
          ordinal++;
          candidates.add(sample);
          if (candidates.length >= targetCount) break;
        }
        if (candidates.length >= targetCount) break;
      }
      if (candidates.length >= targetCount) break;
    }
  }
  if (candidates.length < targetCount) {
    throw StateError(
      'Only generated ${candidates.length} net containment samples for $size x $size',
    );
  }
  return candidates;
}

Map<String, Object?>? _buildNetContainmentSample({
  required int size,
  required _NetOrientation orientation,
  required int colOffset,
  required int rowOffset,
  required int ordinal,
  required int noiseSeed,
}) {
  String transform((int, int) point) {
    final transformed = orientation.transform(point.$1, point.$2);
    return _point(transformed.$1 + colOffset, transformed.$2 + rowOffset);
  }

  const baseWhite = [
    (2, 2),
    (3, 2),
    (4, 2),
    (5, 2),
    (6, 2),
  ];
  const baseBlack = [
    (1, 2),
    (2, 1),
    (3, 1),
    (4, 1),
    (5, 1),
    (6, 1),
    (7, 1),
    (2, 3),
    (3, 3),
    (4, 3),
    (5, 3),
    (6, 3),
    (7, 3),
  ];
  const baseBlunder = (7, 2);
  const baseFinal = (8, 2);

  final black = [for (final point in baseBlack) transform(point)];
  final white = [for (final point in baseWhite) transform(point)];
  final blunderPoint = transform(baseBlunder);
  final finalPoint = transform(baseFinal);
  final reserved = <String>{...black, ...white, blunderPoint, finalPoint};
  _addNoise(
    size: size,
    seed: noiseSeed,
    occupied: reserved,
    black: black,
    white: white,
  );
  final firstBlackMove = _chooseFirstBlackMove(size, reserved);
  if (firstBlackMove == null) return null;
  final moves = <(int, String)>[
    (SimBoard.black, firstBlackMove),
    (SimBoard.white, blunderPoint),
    (SimBoard.black, finalPoint),
  ];

  final finalCaptureDelta = _validate(
    size: size,
    black: black,
    white: white,
    moves: moves,
  );
  if (finalCaptureDelta < 5) return null;

  final id =
      'net-containment-${size}x$size-${ordinal.toString().padLeft(3, '0')}';
  return {
    'id': 'trap-$id',
    'sourceSampleId': id,
    'family': 'net_containment',
    'trapType': 'net_containment_escape',
    'boardSize': size,
    'captureTarget': 5,
    'split': ordinal % 10 <= 7 && ordinal % 10 != 0 ? 'train' : 'eval',
    'sideToMove': 'white',
    'sgf': _sgf(size: size, black: black, white: white, moves: moves),
    'entryPly': 1,
    'blunderPly': 2,
    'blunderMoves': [_moveText(moves[1])],
    'correctMoveCategory': 'avoid_contained_escape',
    'failureContinuation': [
      for (final move in moves.skip(1)) _moveText(move),
    ],
    'acceptedMoves': <String>[],
    'acceptedMovePolicy': {
      'type': 'avoid_listed_blunders',
      'description':
          'Any legal move outside the contained escape blunder is provisionally accepted until a broader outcome evaluator is attached.',
    },
    'failureReason': {
      'code': 'contained_escape_has_single_final_liberty',
      'description':
          'The white chain runs into a central net, but black stones above and below the route leave only one final liberty. Black fills it and captures at least five stones.',
    },
    'expectedOutcomeAfterBlunder': {
      'winner': 'black',
      'finalCapturePly': 3,
      'finalCaptureMove': _moveText(moves.last),
      'capturedStoneCount': finalCaptureDelta,
    },
    'sourceTransform': {
      'orientation': orientation.name,
      'transformedWidth': orientation.width,
      'transformedHeight': orientation.height,
      'colOffset': colOffset,
      'rowOffset': rowOffset,
      'noiseSeed': noiseSeed,
    },
  };
}

List<Map<String, Object?>> _generateThrowInSnapbackSamples(
  int size,
  int targetCount,
) {
  final candidates = <Map<String, Object?>>[];
  final seen = <String>{};
  var ordinal = 0;
  var noiseSeed = 0;
  while (candidates.length < targetCount && noiseSeed < 4000) {
    for (final orientation in _snapbackOrientations) {
      final maxColOffset = size - orientation.width;
      final maxRowOffset = size - orientation.height;
      if (maxColOffset < 0 || maxRowOffset < 0) continue;
      for (var rowOffset = 0; rowOffset <= maxRowOffset; rowOffset++) {
        for (var colOffset = 0; colOffset <= maxColOffset; colOffset++) {
          final sample = _buildThrowInSnapbackSample(
            size: size,
            orientation: orientation,
            colOffset: colOffset,
            rowOffset: rowOffset,
            ordinal: ordinal + 1,
            noiseSeed: noiseSeed,
          );
          noiseSeed++;
          if (sample == null) continue;
          final sgf = sample['sgf']! as String;
          if (!seen.add(sgf)) continue;
          ordinal++;
          candidates.add(sample);
          if (candidates.length >= targetCount) break;
        }
        if (candidates.length >= targetCount) break;
      }
      if (candidates.length >= targetCount) break;
    }
  }
  if (candidates.length < targetCount) {
    throw StateError(
      'Only generated ${candidates.length} throw-in snapback samples for $size x $size',
    );
  }
  return candidates;
}

Map<String, Object?>? _buildThrowInSnapbackSample({
  required int size,
  required _SnapbackOrientation orientation,
  required int colOffset,
  required int rowOffset,
  required int ordinal,
  required int noiseSeed,
}) {
  String transform((int, int) point) {
    final transformed = orientation.transform(point.$1, point.$2);
    return _point(transformed.$1 + colOffset, transformed.$2 + rowOffset);
  }

  const baseWhite = [
    (2, 1),
    (2, 2),
    (2, 3),
    (3, 3),
    (4, 3),
    (4, 2),
    (4, 1),
  ];
  const baseBlack = [
    (2, 0),
    (3, 0),
    (4, 0),
    (1, 1),
    (1, 2),
    (1, 3),
    (2, 4),
    (3, 4),
    (4, 4),
    (5, 1),
    (5, 2),
    (5, 3),
  ];
  const baseThrowIn = (3, 2);
  const baseCaptureBlunder = (3, 1);

  final black = [for (final point in baseBlack) transform(point)];
  final white = [for (final point in baseWhite) transform(point)];
  final throwInPoint = transform(baseThrowIn);
  final captureBlunderPoint = transform(baseCaptureBlunder);
  final reserved = <String>{
    ...black,
    ...white,
    throwInPoint,
    captureBlunderPoint,
  };
  _addNoise(
    size: size,
    seed: noiseSeed,
    occupied: reserved,
    black: black,
    white: white,
  );
  final moves = <(int, String)>[
    (SimBoard.black, throwInPoint),
    (SimBoard.white, captureBlunderPoint),
    (SimBoard.black, throwInPoint),
  ];

  final finalCaptureDelta = _validate(
    size: size,
    black: black,
    white: white,
    moves: moves,
  );
  if (finalCaptureDelta < 5) return null;

  final id =
      'throw-in-snapback-${size}x$size-${ordinal.toString().padLeft(3, '0')}';
  return {
    'id': 'trap-$id',
    'sourceSampleId': id,
    'family': 'throw_in_snapback',
    'trapType': 'throw_in_snapback_capture',
    'boardSize': size,
    'captureTarget': 5,
    'split': ordinal % 10 <= 7 && ordinal % 10 != 0 ? 'train' : 'eval',
    'sideToMove': 'white',
    'sgf': _sgf(size: size, black: black, white: white, moves: moves),
    'entryPly': 1,
    'blunderPly': 2,
    'blunderMoves': [_moveText(moves[1])],
    'correctMoveCategory': 'avoid_snapback_capture',
    'failureContinuation': [
      for (final move in moves.skip(1)) _moveText(move),
    ],
    'acceptedMoves': <String>[],
    'acceptedMovePolicy': {
      'type': 'avoid_listed_blunders',
      'description':
          'Any legal move outside the snapback capture is provisionally accepted until a broader outcome evaluator is attached.',
    },
    'failureReason': {
      'code': 'capture_throw_in_allows_snapback',
      'description':
          'White can capture the thrown-in black stone, but that fills the last outside liberty. Black immediately plays back at the throw-in point and captures the surrounding white chain.',
    },
    'expectedOutcomeAfterBlunder': {
      'winner': 'black',
      'finalCapturePly': 3,
      'finalCaptureMove': _moveText(moves.last),
      'capturedStoneCount': finalCaptureDelta,
    },
    'sourceTransform': {
      'orientation': orientation.name,
      'transformedWidth': orientation.width,
      'transformedHeight': orientation.height,
      'colOffset': colOffset,
      'rowOffset': rowOffset,
      'noiseSeed': noiseSeed,
    },
  };
}

List<String> _failureContinuationFromSgf(
  String sgf, {
  required int entryPly,
}) {
  final moves = RegExp(r';([BW])\[([a-z]{2})\]')
      .allMatches(sgf)
      .map((move) => '${move.group(1)}[${move.group(2)}]')
      .toList(growable: false);
  return moves.skip(entryPly).toList(growable: false);
}

String? _chooseFirstBlackMove(int size, Set<String> reserved) {
  for (var row = size - 1; row >= 0; row--) {
    for (var col = size - 1; col >= 0; col--) {
      final point = _point(col, row);
      if (reserved.contains(point)) continue;
      if (_adjacentPoints(size, point).any(reserved.contains)) continue;
      return point;
    }
  }
  return null;
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

String _moveText((int, String) move) =>
    '${move.$1 == SimBoard.black ? 'B' : 'W'}[${move.$2}]';

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

enum _EdgeSide {
  left,
  right,
  top,
  bottom,
}

const _edgeSides = [
  _EdgeSide.left,
  _EdgeSide.right,
  _EdgeSide.top,
  _EdgeSide.bottom,
];

typedef _ConnectTransform = (int, int) Function(int col, int row);

class _ConnectOrientation {
  const _ConnectOrientation({
    required this.name,
    required this.width,
    required this.height,
    required this.transform,
  });

  final String name;
  final int width;
  final int height;
  final _ConnectTransform transform;
}

const _connectBaseWidth = 8;
const _connectBaseHeight = 3;

const _connectOrientations = [
  _ConnectOrientation(
    name: 'horizontal',
    width: _connectBaseWidth,
    height: _connectBaseHeight,
    transform: _connectIdentity,
  ),
  _ConnectOrientation(
    name: 'horizontal_mirror',
    width: _connectBaseWidth,
    height: _connectBaseHeight,
    transform: _connectMirrorX,
  ),
  _ConnectOrientation(
    name: 'vertical',
    width: _connectBaseHeight,
    height: _connectBaseWidth,
    transform: _connectRotate90Cw,
  ),
  _ConnectOrientation(
    name: 'vertical_mirror',
    width: _connectBaseHeight,
    height: _connectBaseWidth,
    transform: _connectRotate90Ccw,
  ),
];

(int, int) _connectIdentity(int col, int row) => (col, row);

(int, int) _connectMirrorX(int col, int row) =>
    (_connectBaseWidth - 1 - col, row);

(int, int) _connectRotate90Cw(int col, int row) =>
    (_connectBaseHeight - 1 - row, col);

(int, int) _connectRotate90Ccw(int col, int row) =>
    (row, _connectBaseWidth - 1 - col);

typedef _NetTransform = (int, int) Function(int col, int row);

class _NetOrientation {
  const _NetOrientation({
    required this.name,
    required this.width,
    required this.height,
    required this.transform,
  });

  final String name;
  final int width;
  final int height;
  final _NetTransform transform;
}

const _netBaseWidth = 9;
const _netBaseHeight = 5;

const _netOrientations = [
  _NetOrientation(
    name: 'horizontal',
    width: _netBaseWidth,
    height: _netBaseHeight,
    transform: _netIdentity,
  ),
  _NetOrientation(
    name: 'horizontal_mirror',
    width: _netBaseWidth,
    height: _netBaseHeight,
    transform: _netMirrorX,
  ),
  _NetOrientation(
    name: 'vertical',
    width: _netBaseHeight,
    height: _netBaseWidth,
    transform: _netRotate90Cw,
  ),
  _NetOrientation(
    name: 'vertical_mirror',
    width: _netBaseHeight,
    height: _netBaseWidth,
    transform: _netRotate90Ccw,
  ),
];

(int, int) _netIdentity(int col, int row) => (col, row);

(int, int) _netMirrorX(int col, int row) => (_netBaseWidth - 1 - col, row);

(int, int) _netRotate90Cw(int col, int row) => (_netBaseHeight - 1 - row, col);

(int, int) _netRotate90Ccw(int col, int row) => (row, _netBaseWidth - 1 - col);

typedef _SnapbackTransform = (int, int) Function(int col, int row);

class _SnapbackOrientation {
  const _SnapbackOrientation({
    required this.name,
    required this.width,
    required this.height,
    required this.transform,
  });

  final String name;
  final int width;
  final int height;
  final _SnapbackTransform transform;
}

const _snapbackBaseWidth = 7;
const _snapbackBaseHeight = 5;

const _snapbackOrientations = [
  _SnapbackOrientation(
    name: 'horizontal',
    width: _snapbackBaseWidth,
    height: _snapbackBaseHeight,
    transform: _snapbackIdentity,
  ),
  _SnapbackOrientation(
    name: 'horizontal_mirror',
    width: _snapbackBaseWidth,
    height: _snapbackBaseHeight,
    transform: _snapbackMirrorX,
  ),
  _SnapbackOrientation(
    name: 'vertical',
    width: _snapbackBaseHeight,
    height: _snapbackBaseWidth,
    transform: _snapbackRotate90Cw,
  ),
  _SnapbackOrientation(
    name: 'vertical_mirror',
    width: _snapbackBaseHeight,
    height: _snapbackBaseWidth,
    transform: _snapbackRotate90Ccw,
  ),
];

(int, int) _snapbackIdentity(int col, int row) => (col, row);

(int, int) _snapbackMirrorX(int col, int row) =>
    (_snapbackBaseWidth - 1 - col, row);

(int, int) _snapbackRotate90Cw(int col, int row) =>
    (_snapbackBaseHeight - 1 - row, col);

(int, int) _snapbackRotate90Ccw(int col, int row) =>
    (row, _snapbackBaseWidth - 1 - col);
