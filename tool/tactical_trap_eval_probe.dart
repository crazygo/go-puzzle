// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/katago_model_adapter.dart';
import 'package:go_puzzle/game/mcts_engine.dart';

import 'node_katago_onnx_model_adapter.dart';

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final corpusPath =
      opts['corpus'] ?? 'docs/ai_eval/tactics/tactical_trap_corpus.json';
  final configIds = (opts['configs'] ??
          'heuristic_counter_standard_v1,mcts_counter_standard_v1,hybrid_tactical_counter_standard_v1')
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  final split = opts['split'];
  final limit = int.tryParse(opts['limit'] ?? '');
  final outPath = opts['out'];
  final katagoAdapterMode = opts['katago-adapter'] ?? 'unavailable';
  final katagoModelAdapter = katagoAdapterMode == 'node'
      ? NodeKatagoOnnxModelAdapter()
      : const UnavailableAsyncKatagoOnnxModelAdapter();

  final corpus =
      jsonDecode(File(corpusPath).readAsStringSync()) as Map<String, dynamic>;
  final samples = (corpus['samples'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .where((sample) => split == null || sample['split'] == split)
      .take(limit ?? 1 << 30)
      .toList(growable: false);

  final configSummaries = <Map<String, Object?>>[];
  try {
    for (final configId in configIds) {
      final config = AiAlgorithmRegistry.configById(configId);
      final agent = AiAlgorithmRegistry.createAsyncAgent(
        config,
        katagoModelAdapter: katagoModelAdapter,
      );
      final results = <Map<String, Object?>>[];
      for (final sample in samples) {
        final board = _replayToEntry(sample);
        CaptureAiMove? move;
        String? failureReason;
        try {
          move = await agent.chooseMove(SimBoard.copy(board));
        } catch (error) {
          failureReason = error.toString();
        }
        final selected = move == null
            ? null
            : _moveText(board.currentPlayer, board.size, move.position.row,
                move.position.col);
        final legal = move != null &&
            board.analyzeMove(move.position.row, move.position.col).isLegal;
        final blunderMoves =
            (sample['blunderMoves'] as List<dynamic>).cast<String>().toSet();
        final isBlunder = selected != null && blunderMoves.contains(selected);
        final failureProof = isBlunder
            ? _proveFailureContinuation(
                board,
                (sample['failureContinuation'] as List<dynamic>).cast<String>(),
                sample['expectedOutcomeAfterBlunder'] as Map<String, dynamic>,
              )
            : _FailureProof.notApplicable();
        final isAccepted = legal && !failureProof.proven;
        results.add({
          'sampleId': sample['id'],
          'family': sample['family'],
          'trapType': sample['trapType'],
          'split': sample['split'],
          'selectedMove': selected,
          'legal': legal,
          'blunder': isBlunder,
          'provenFailure': failureProof.proven,
          if (failureProof.capturedStoneCount != null)
            'provenFailureCapturedStoneCount': failureProof.capturedStoneCount,
          if (failureReason != null) 'failureReason': failureReason,
          'accepted': isAccepted,
        });
      }
      configSummaries.add(_summarizeConfig(configId, results));
    }
  } finally {
    if (katagoModelAdapter is NodeKatagoOnnxModelAdapter) {
      await katagoModelAdapter.close();
    }
  }

  final output = {
    'schemaVersion': 1,
    'probe': 'tactical_trap_eval_probe_v1',
    'corpusId': corpus['corpusId'],
    'configIds': configIds,
    'split': split ?? 'all',
    'katagoAdapter': katagoAdapterMode,
    'sampleCount': samples.length,
    'summaries': configSummaries,
  };

  final encoded = const JsonEncoder.withIndent('  ').convert(output);
  if (outPath == null) {
    print(encoded);
  } else {
    File(outPath)
      ..createSync(recursive: true)
      ..writeAsStringSync('$encoded\n');
    print('WROTE $outPath');
  }
}

Map<String, Object?> _summarizeConfig(
  String configId,
  List<Map<String, Object?>> results,
) {
  final total = results.length;
  final overall = _countResults(results);
  final byFamily = <String, _Counter>{};
  final bySplit = <String, _Counter>{};
  final byFamilyAndSplit = <String, _Counter>{};
  for (final result in results) {
    final family = result['family']! as String;
    final split = result['split']! as String;
    byFamily.putIfAbsent(family, _Counter.new).add(result);
    bySplit.putIfAbsent(split, _Counter.new).add(result);
    byFamilyAndSplit.putIfAbsent('$family::$split', _Counter.new).add(result);
  }
  final evalCounter = bySplit['eval'] ?? _Counter();
  return {
    'configId': configId,
    'samples': total,
    'legalMoves': overall.legal,
    'illegalOrNoMove': total - overall.legal,
    'blunders': overall.blunders,
    'provenFailures': overall.provenFailures,
    'accepted': overall.accepted,
    'trapBlunderRate': overall.trapBlunderRate,
    'acceptedMoveRate': overall.acceptedMoveRate,
    'evalAcceptedMoveRate': evalCounter.acceptedMoveRate,
    'evalProvenFailures': evalCounter.provenFailures,
    'byFamily': [
      for (final entry in byFamily.entries)
        {'family': entry.key, ...entry.value.toJson()}
    ],
    'bySplit': [
      for (final entry in bySplit.entries)
        {'split': entry.key, ...entry.value.toJson()}
    ],
    'byFamilyAndSplit': [
      for (final entry in byFamilyAndSplit.entries)
        {
          'family': entry.key.split('::').first,
          'split': entry.key.split('::').last,
          ...entry.value.toJson(),
        }
    ],
    'results': results,
  };
}

_Counter _countResults(List<Map<String, Object?>> results) {
  final counter = _Counter();
  for (final result in results) {
    counter.add(result);
  }
  return counter;
}

_FailureProof _proveFailureContinuation(
  SimBoard entryBoard,
  List<String> continuation,
  Map<String, dynamic> expectedOutcome,
) {
  if (continuation.isEmpty) return const _FailureProof(false, null);
  final board = SimBoard.copy(entryBoard);
  var lastDelta = 0;
  for (final move in continuation) {
    final color = _moveColor(move);
    if (board.currentPlayer != color) return const _FailureProof(false, null);
    final point = _movePoint(move);
    final index = _index(board.size, point);
    final before =
        color == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
    if (!board.applyMove(index ~/ board.size, index % board.size)) {
      return const _FailureProof(false, null);
    }
    final after =
        color == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
    lastDelta = after - before;
  }
  final expectedCaptured = expectedOutcome['capturedStoneCount'] as int;
  return _FailureProof(
      lastDelta == expectedCaptured && lastDelta >= 5, lastDelta);
}

SimBoard _replayToEntry(Map<String, dynamic> sample) {
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
    if (board.currentPlayer != color) {
      throw StateError('Unexpected player before ${match.group(2)} in $sgf');
    }
    final index = _index(size, match.group(2)!);
    if (!board.applyMove(index ~/ size, index % size)) {
      throw StateError('Illegal replay move ${match.group(2)} in $sgf');
    }
    playedMoves++;
  }
  return board;
}

void _applySetup(SimBoard board, String sgf) {
  final setupMatch =
      RegExp(r'^\(;FF\[4\]GM\[1\]SZ\[\d+\]([^;]*)').firstMatch(sgf);
  if (setupMatch == null) throw StateError('Missing SGF setup: $sgf');
  final setup = setupMatch.group(1)!;
  for (final point in _setupPoints(setup, 'AB')) {
    board.cells[_index(board.size, point)] = SimBoard.black;
  }
  for (final point in _setupPoints(setup, 'AW')) {
    board.cells[_index(board.size, point)] = SimBoard.white;
  }
}

int _sizeFromSgf(String sgf) {
  final sizeMatch = RegExp(r'SZ\[(\d+)\]').firstMatch(sgf);
  if (sizeMatch == null) throw StateError('Missing board size: $sgf');
  return int.parse(sizeMatch.group(1)!);
}

Iterable<String> _setupPoints(String setup, String property) sync* {
  final match = RegExp('$property((?:\\[[a-z]{2}\\])+)', multiLine: false)
      .firstMatch(setup);
  if (match == null) return;
  for (final point in RegExp(r'\[([a-z]{2})\]').allMatches(match.group(1)!)) {
    yield point.group(1)!;
  }
}

String _moveText(int color, int size, int row, int col) {
  final prefix = color == SimBoard.black ? 'B' : 'W';
  return '$prefix[${_point(col, row)}]';
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

String _point(int col, int row) =>
    String.fromCharCodes([col + 'a'.codeUnitAt(0), row + 'a'.codeUnitAt(0)]);

int _index(int size, String point) =>
    (point.codeUnitAt(1) - 'a'.codeUnitAt(0)) * size +
    point.codeUnitAt(0) -
    'a'.codeUnitAt(0);

Map<String, String> _parseArgs(List<String> args) {
  final parsed = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    final next = i + 1 < args.length ? args[i + 1] : null;
    if (next != null && !next.startsWith('--')) {
      parsed[key] = next;
      i++;
    } else {
      parsed[key] = 'true';
    }
  }
  return parsed;
}

class _Counter {
  int total = 0;
  int legal = 0;
  int blunders = 0;
  int provenFailures = 0;
  int accepted = 0;

  void add(Map<String, Object?> result) {
    total++;
    if (result['legal'] == true) legal++;
    if (result['blunder'] == true) blunders++;
    if (result['provenFailure'] == true) provenFailures++;
    if (result['accepted'] == true) accepted++;
  }

  double get trapBlunderRate => total == 0 ? 0 : blunders / total;

  double get acceptedMoveRate => total == 0 ? 0 : accepted / total;

  Map<String, Object?> toJson() => {
        'samples': total,
        'legalMoves': legal,
        'illegalOrNoMove': total - legal,
        'blunders': blunders,
        'provenFailures': provenFailures,
        'accepted': accepted,
        'trapBlunderRate': trapBlunderRate,
        'acceptedMoveRate': acceptedMoveRate,
      };
}

class _FailureProof {
  const _FailureProof(this.proven, this.capturedStoneCount);

  factory _FailureProof.notApplicable() => const _FailureProof(false, null);

  final bool proven;
  final int? capturedStoneCount;
}
