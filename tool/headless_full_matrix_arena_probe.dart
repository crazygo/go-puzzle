// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';

import 'node_katago_onnx_model_adapter.dart';

const _openings = [
  ('empty', 'empty_v1'),
  ('cross', 'cross_v1'),
  ('twistCross', 'twist_cross_v1'),
];

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final workers = math.max(1, int.tryParse(opts['workers'] ?? '4') ?? 4);
  final boardSizes = (opts['board-sizes'] ?? opts['board-size'] ?? '9')
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .toList(growable: false);
  final repeatCount = int.tryParse(opts['repeat'] ?? '2') ?? 2;
  final captureTarget = int.tryParse(opts['capture-target'] ?? '5') ?? 5;
  final maxMoves = int.tryParse(opts['max-moves'] ?? '120') ?? 120;
  final matchSeed = int.tryParse(opts['match-seed'] ?? '20260519') ?? 20260519;
  final openingSeed = int.tryParse(opts['opening-seed'] ?? '0') ?? 0;
  final startCell = int.tryParse(opts['start-cell'] ?? '0') ?? 0;
  final endCellOpt = int.tryParse(opts['end-cell'] ?? '');
  final outPath = opts['out'] ??
      'docs/ai_eval/runs/2026-05-19-headless-full-matrix-arena-probe.json';
  final progressIntervalSeconds =
      int.tryParse(opts['progress-interval-seconds'] ?? '30') ?? 30;
  final scheduling = opts['scheduling'] ?? 'dynamic';
  final policyPlane = int.tryParse(opts['policy-plane'] ?? '0') ?? 0;
  final configIds = (opts['configs'] ?? '')
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  final configs = configIds.isEmpty
      ? AiAlgorithmRegistry.configs
      : configIds.map(AiAlgorithmRegistry.configById).toList(growable: false);
  if (configs.length < 2) {
    stderr.writeln('ERROR: at least two configs are required.');
    exitCode = 2;
    return;
  }
  if (boardSizes.isEmpty) {
    stderr.writeln('ERROR: --board-size/--board-sizes must include a value.');
    exitCode = 2;
    return;
  }
  if (scheduling != 'dynamic' && scheduling != 'fixed') {
    stderr.writeln('ERROR: --scheduling must be dynamic or fixed.');
    exitCode = 2;
    return;
  }

  final cells = _buildCellPlans(
    boardSizes: boardSizes,
    configs: configs,
    repeatCount: repeatCount,
    captureTarget: captureTarget,
    maxMoves: maxMoves,
    matchSeed: matchSeed,
    openingSeed: openingSeed,
  );
  final endCell = math.min(endCellOpt ?? cells.length, cells.length);
  final selected = cells
      .where((cell) => cell.index >= startCell && cell.index < endCell)
      .toList(growable: false);
  if (selected.isEmpty) {
    stderr.writeln('ERROR: selected cell range is empty.');
    exitCode = 2;
    return;
  }

  final runStartedAt = DateTime.now();
  final progressDir = Directory(
    '.cache/ai_eval_progress/${_progressRunId(outPath)}',
  );
  if (progressDir.existsSync()) progressDir.deleteSync(recursive: true);
  progressDir.createSync(recursive: true);
  final queueCursorPath = '${progressDir.path}/queue-cursor.txt';
  final queueLockPath = '${progressDir.path}/queue.lock';
  if (scheduling == 'dynamic') {
    File(queueCursorPath).writeAsStringSync('0');
  }

  final buckets = List.generate(workers, (_) => <_CellPlan>[]);
  if (scheduling == 'fixed') {
    for (var i = 0; i < selected.length; i++) {
      buckets[i % workers].add(selected[i]);
    }
  } else {
    for (var workerIndex = 0; workerIndex < workers; workerIndex++) {
      buckets[workerIndex] = selected;
    }
  }
  for (var workerIndex = 0; workerIndex < buckets.length; workerIndex++) {
    final assigned =
        scheduling == 'dynamic' ? selected.length : buckets[workerIndex].length;
    _writeWorkerProgress(
      progressDir: progressDir.path,
      workerIndex: workerIndex,
      completed: 0,
      assigned: assigned,
      status: assigned == 0 ? 'idle' : 'queued',
    );
  }
  Timer? progressTimer;
  if (progressIntervalSeconds > 0) {
    _printProgress(
      progressDir: progressDir,
      totalCells: selected.length,
      startedAt: runStartedAt,
      force: true,
    );
    progressTimer = Timer.periodic(
      Duration(seconds: progressIntervalSeconds),
      (_) => _printProgress(
        progressDir: progressDir,
        totalCells: selected.length,
        startedAt: runStartedAt,
      ),
    );
  }

  final futures = <Future<List<Map<String, Object?>>>>[];
  for (var workerIndex = 0; workerIndex < buckets.length; workerIndex++) {
    final bucket = buckets[workerIndex];
    if (bucket.isEmpty) continue;
    futures.add(Isolate.run(
      () => _runWorker(_WorkerRequest(
        workerIndex: workerIndex,
        policyPlane: policyPlane,
        cells: bucket,
        progressDir: progressDir.path,
        scheduling: scheduling,
        queueCursorPath: scheduling == 'dynamic' ? queueCursorPath : null,
        queueLockPath: scheduling == 'dynamic' ? queueLockPath : null,
        assignedCells:
            scheduling == 'dynamic' ? selected.length : bucket.length,
      )),
    ));
  }

  late final List<List<Map<String, Object?>>> workerResults;
  try {
    workerResults = await Future.wait(futures);
  } finally {
    progressTimer?.cancel();
    _printProgress(
      progressDir: progressDir,
      totalCells: selected.length,
      startedAt: runStartedAt,
      force: true,
    );
  }
  final matrixCells = workerResults.expand((cells) => cells).toList()
    ..sort((a, b) => (a['index']! as int).compareTo(b['index']! as int));
  final output = _mergedOutput(
    probe: 'headless_full_matrix_arena_probe_v1',
    configs: configs,
    boardSizes: boardSizes,
    repeatCount: repeatCount,
    captureTarget: captureTarget,
    maxMoves: maxMoves,
    matchSeed: matchSeed,
    openingSeed: openingSeed,
    startCell: startCell,
    endCell: endCell,
    totalCells: cells.length,
    selectedCells: matrixCells,
    workers: workers,
    scheduling: scheduling,
    policyPlane: policyPlane,
  );
  final file = File(outPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(output));
  try {
    _validateMerged(output);
  } catch (_) {
    print('WROTE FAILED ARTIFACT $outPath');
    rethrow;
  }
  print('WROTE $outPath');
}

Future<List<Map<String, Object?>>> _runWorker(_WorkerRequest request) async {
  final adapter = NodeKatagoOnnxModelAdapter(policyPlane: request.policyPlane);
  var completed = 0;
  try {
    final cells = <Map<String, Object?>>[];
    _writeWorkerProgress(
      progressDir: request.progressDir,
      workerIndex: request.workerIndex,
      completed: completed,
      assigned: request.assignedCells,
      status: 'running',
    );
    var fixedIndex = 0;
    while (true) {
      final cell = request.scheduling == 'dynamic'
          ? _takeNextQueuedCell(request)
          : fixedIndex < request.cells.length
              ? request.cells[fixedIndex++]
              : null;
      if (cell == null) break;
      final cellStartedAt = DateTime.now();
      final cellStopwatch = Stopwatch()..start();
      _writeWorkerProgress(
        progressDir: request.progressDir,
        workerIndex: request.workerIndex,
        completed: completed,
        assigned: request.assignedCells,
        status: 'running',
        currentCell: cell,
      );
      final executor = AiArenaExecutor(
        boardSize: cell.boardSize,
        captureTarget: cell.captureTarget,
        rounds: cell.repeatCount,
        maxMoves: cell.maxMoves,
        openingPolicy: cell.openingPolicy,
      );
      final match = await executor.runFrameworkMatchAsync(
        configA: AiAlgorithmRegistry.configById(cell.firstConfigId),
        configB: AiAlgorithmRegistry.configById(cell.secondConfigId),
        matchSeed: cell.matchSeed,
        openingSeed: cell.openingSeed,
        alternateColors: false,
        asyncKatagoModelAdapter: adapter,
      );
      cellStopwatch.stop();
      cells.add(_cellJson(
        plan: cell,
        match: match,
        workerIndex: request.workerIndex,
        startedAt: cellStartedAt,
        elapsed: cellStopwatch.elapsed,
      ));
      completed++;
      _writeWorkerProgress(
        progressDir: request.progressDir,
        workerIndex: request.workerIndex,
        completed: completed,
        assigned: request.assignedCells,
        status: 'running',
        currentCell: cell,
      );
    }
    _writeWorkerProgress(
      progressDir: request.progressDir,
      workerIndex: request.workerIndex,
      completed: completed,
      assigned: request.assignedCells,
      status: 'done',
    );
    return cells;
  } catch (error) {
    _writeWorkerProgress(
      progressDir: request.progressDir,
      workerIndex: request.workerIndex,
      completed: completed,
      assigned: request.assignedCells,
      status: 'error',
      error: '$error',
    );
    rethrow;
  } finally {
    await adapter.close();
  }
}

_CellPlan? _takeNextQueuedCell(_WorkerRequest request) {
  final cursorPath = request.queueCursorPath;
  final lockPath = request.queueLockPath;
  if (cursorPath == null || lockPath == null) return null;
  final lock = File(lockPath).openSync(mode: FileMode.write);
  try {
    lock.lockSync(FileLock.blockingExclusive);
    final cursorFile = File(cursorPath);
    final raw = cursorFile.existsSync() ? cursorFile.readAsStringSync() : '0';
    final next = int.tryParse(raw.trim()) ?? 0;
    if (next >= request.cells.length) return null;
    cursorFile.writeAsStringSync('${next + 1}');
    return request.cells[next];
  } finally {
    try {
      lock.unlockSync();
    } on FileSystemException {
      // Closing the file releases the OS-level lock even if unlock fails.
    }
    lock.closeSync();
  }
}

String _progressRunId(String outPath) {
  final basename = outPath.split(Platform.pathSeparator).last;
  return basename.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}

void _writeWorkerProgress({
  required String progressDir,
  required int workerIndex,
  required int completed,
  required int assigned,
  required String status,
  _CellPlan? currentCell,
  String? error,
}) {
  final file = File('$progressDir/worker-$workerIndex.json');
  file.writeAsStringSync(jsonEncode({
    'workerIndex': workerIndex,
    'completed': completed,
    'assigned': assigned,
    'status': status,
    'updatedAt': DateTime.now().toIso8601String(),
    if (currentCell != null) ...{
      'currentCell': currentCell.index,
      'boardSize': currentCell.boardSize,
      'opening': currentCell.openingName,
      'firstConfigId': currentCell.firstConfigId,
      'secondConfigId': currentCell.secondConfigId,
    },
    if (error != null) 'error': error,
  }));
}

void _printProgress({
  required Directory progressDir,
  required int totalCells,
  required DateTime startedAt,
  bool force = false,
}) {
  if (!progressDir.existsSync()) return;
  final statuses = progressDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .map((file) {
        try {
          return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        } catch (_) {
          return <String, dynamic>{};
        }
      })
      .where((json) => json.isNotEmpty)
      .toList()
    ..sort(
        (a, b) => (a['workerIndex'] as int).compareTo(b['workerIndex'] as int));
  if (statuses.isEmpty) return;

  final completed = statuses.fold<int>(
    0,
    (sum, status) => sum + (status['completed'] as int? ?? 0),
  );
  final percent = totalCells == 0 ? 100.0 : completed * 100.0 / totalCells;
  final elapsed = DateTime.now().difference(startedAt);
  final workerText = statuses.map((status) {
    final worker = status['workerIndex'];
    final done = status['completed'];
    final assigned = status['assigned'];
    final state = status['status'];
    final cell = status['currentCell'];
    final opening = status['opening'];
    final first = status['firstConfigId'];
    final second = status['secondConfigId'];
    final current = cell == null ? '' : ' cell=$cell $opening $first>$second';
    return 'w$worker $done/$assigned $state$current';
  }).join(' | ');

  final label = completed >= totalCells ? 'PROGRESS done' : 'PROGRESS';
  if (force || completed < totalCells) {
    print(
      '$label total=$completed/$totalCells '
      '(${percent.toStringAsFixed(1)}%) '
      'elapsed=${_formatElapsed(elapsed)} :: $workerText',
    );
  }
}

String _formatElapsed(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

List<_CellPlan> _buildCellPlans({
  required List<int> boardSizes,
  required List<AiAlgorithmConfig> configs,
  required int repeatCount,
  required int captureTarget,
  required int maxMoves,
  required int matchSeed,
  required int openingSeed,
}) {
  final cells = <_CellPlan>[];
  var cellIndex = 0;
  for (final boardSize in boardSizes) {
    for (var i = 0; i < configs.length - 1; i++) {
      for (var j = i + 1; j < configs.length; j++) {
        final left = configs[i];
        final right = configs[j];
        for (final (openingName, openingPolicy) in _openings) {
          for (final firstConfig in [left, right]) {
            final secondConfig = identical(firstConfig, left) ? right : left;
            cells.add(_CellPlan(
              index: cellIndex,
              boardSize: boardSize,
              captureTarget: captureTarget,
              repeatCount: repeatCount,
              maxMoves: maxMoves,
              openingName: openingName,
              openingPolicy: openingPolicy,
              firstConfigId: firstConfig.id,
              secondConfigId: secondConfig.id,
              matchSeed: matchSeed + cellIndex * 7919,
              openingSeed: openingSeed,
            ));
            cellIndex++;
          }
        }
      }
    }
  }
  return cells;
}

Map<String, Object?> _cellJson({
  required _CellPlan plan,
  required AiMatchResult match,
  required int workerIndex,
  required DateTime startedAt,
  required Duration elapsed,
}) {
  final failureReasons = match.games
      .map((game) => game.failureReason)
      .whereType<String>()
      .toSet()
      .toList()
    ..sort();
  return {
    'index': plan.index,
    'workerIndex': workerIndex,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': startedAt.add(elapsed).toIso8601String(),
    'elapsedMillis': elapsed.inMilliseconds,
    'boardSize': plan.boardSize,
    'pairId': _pairId(plan.firstConfigId, plan.secondConfigId),
    'opening': plan.openingName,
    'firstConfigId': plan.firstConfigId,
    'secondConfigId': plan.secondConfigId,
    'repeats': match.rounds,
    'firstWins': match.aWins,
    'secondWins': match.bWins,
    'draws': match.draws,
    'firstWinRate': match.aWinRate,
    'secondWinRate': match.bWinRate,
    'illegalMoves': match.games.where((game) => game.illegalMove).length,
    'timeouts': match.games.where((game) => game.timedOut).length,
    'fallbackGames': match.games.where((game) => game.fallbackUsed).length,
    'failureReasons': failureReasons,
    'games': match.games.map((game) => game.toJson()).toList(),
  };
}

Map<String, Object?> _mergedOutput({
  required String probe,
  required List<AiAlgorithmConfig> configs,
  required List<int> boardSizes,
  required int repeatCount,
  required int captureTarget,
  required int maxMoves,
  required int matchSeed,
  required int openingSeed,
  required int startCell,
  required int endCell,
  required int totalCells,
  required List<Map<String, Object?>> selectedCells,
  required int workers,
  required String scheduling,
  required int policyPlane,
}) {
  final metadata = {
    'probe': probe,
    'configs': configs.map((config) => config.id).toList(),
    'configSnapshots': configs.map((config) => config.toJson()).toList(),
    'boardSizes': boardSizes,
    'openings': _openings.map((opening) => opening.$1).toList(),
    'repeatCount': repeatCount,
    'totalCells': totalCells,
    'startCell': startCell,
    'endCell': endCell,
    'selectedCells': selectedCells.length,
    'expectedGames': selectedCells.length * repeatCount,
    'totalExpectedGames': totalCells * repeatCount,
    'actualGames': selectedCells.fold<int>(
      0,
      (sum, cell) => sum + ((cell['games']! as List).length),
    ),
    'matchSeed': matchSeed,
    'openingSeed': openingSeed,
    'captureTarget': captureTarget,
    'maxMoves': maxMoves,
    'workers': workers,
    'scheduling': scheduling,
    'katagoBackend': 'node_onnxruntime',
    'policyPlane': policyPlane,
  };
  return {
    'metadata': metadata,
    'matrixCells': selectedCells,
    'pairwiseOverall': _pairwiseOverall(selectedCells),
    'perOpeningPerformance': _perOpeningPerformance(selectedCells),
    'perFirstPlayerPerformance': _perFirstPlayerPerformance(selectedCells),
    'rankings': _rankings(selectedCells),
    'validation': _validation(selectedCells, metadata),
  };
}

List<Map<String, Object?>> _pairwiseOverall(List<Map<String, Object?>> cells) {
  final scores = <String, _Score>{};
  for (final cell in cells) {
    final key = '${cell['boardSize']}::${cell['pairId']}';
    final score = scores.putIfAbsent(
      key,
      () => _Score(
        boardSize: cell['boardSize']! as int,
        pairId: cell['pairId']! as String,
      ),
    );
    score.addPair(cell);
  }
  return scores.values.map((score) => score.toPairJson()).toList()
    ..sort((a, b) {
      final board = (a['boardSize']! as int).compareTo(b['boardSize']! as int);
      if (board != 0) return board;
      return (a['pairId']! as String).compareTo(b['pairId']! as String);
    });
}

List<Map<String, Object?>> _perOpeningPerformance(
  List<Map<String, Object?>> cells,
) {
  final scores = <String, _Score>{};
  for (final cell in cells) {
    for (final id in [cell['firstConfigId']!, cell['secondConfigId']!]) {
      final key = '${cell['boardSize']}::${cell['opening']}::$id';
      final score = scores.putIfAbsent(
        key,
        () => _Score(
          boardSize: cell['boardSize']! as int,
          opening: cell['opening']! as String,
          configId: id as String,
        ),
      );
      score.addPerspective(cell, id as String);
    }
  }
  return scores.values.map((score) => score.toGenericJson()).toList();
}

List<Map<String, Object?>> _perFirstPlayerPerformance(
  List<Map<String, Object?>> cells,
) {
  final scores = <String, _Score>{};
  for (final cell in cells) {
    final id = cell['firstConfigId']! as String;
    final key = '${cell['boardSize']}::$id';
    final score = scores.putIfAbsent(
      key,
      () => _Score(boardSize: cell['boardSize']! as int, firstConfigId: id),
    );
    score.wins += cell['firstWins']! as int;
    score.losses += cell['secondWins']! as int;
    score.draws += cell['draws']! as int;
    score.addStatus(cell);
  }
  return scores.values.map((score) => score.toGenericJson()).toList();
}

List<Map<String, Object?>> _rankings(List<Map<String, Object?>> cells) {
  final scores = <String, _Score>{};
  for (final cell in cells) {
    for (final id in [cell['firstConfigId']!, cell['secondConfigId']!]) {
      final key = '${cell['boardSize']}::$id';
      final score = scores.putIfAbsent(
        key,
        () => _Score(
            boardSize: cell['boardSize']! as int, configId: id as String),
      );
      score.addPerspective(cell, id as String);
      final ownWins = id == cell['firstConfigId']
          ? cell['firstWins']! as int
          : cell['secondWins']! as int;
      final otherWins = id == cell['firstConfigId']
          ? cell['secondWins']! as int
          : cell['firstWins']! as int;
      if (ownWins > otherWins) {
        score.matchWins++;
      } else if (ownWins < otherWins) {
        score.matchLosses++;
      } else {
        score.matchDraws++;
      }
    }
  }
  final values = scores.values.toList()
    ..sort((a, b) => a.boardSize.compareTo(b.boardSize) != 0
        ? a.boardSize.compareTo(b.boardSize)
        : b.matchWins - a.matchWins != 0
            ? b.matchWins - a.matchWins
            : b.winRate.compareTo(a.winRate));
  var rank = 1;
  return [
    for (final score in values)
      {
        'rank': rank++,
        'boardSize': score.boardSize,
        'configId': score.configId,
        'matchWins': score.matchWins,
        'matchLosses': score.matchLosses,
        'matchDraws': score.matchDraws,
        'matchWinRate':
            _rate(score.matchWins, score.matchLosses, score.matchDraws),
        'gameWins': score.wins,
        'gameLosses': score.losses,
        'draws': score.draws,
        'games': score.games,
        'gameWinRate': score.winRate,
        'illegalMoves': score.illegalMoves,
        'timeouts': score.timeouts,
        'fallbackGames': score.fallbackGames,
      }
  ];
}

Map<String, Object?> _validation(
  List<Map<String, Object?>> cells,
  Map<String, Object?> metadata,
) {
  final games = cells.fold<int>(
    0,
    (sum, cell) => sum + ((cell['games']! as List).length),
  );
  final dimensions = <String, int>{};
  for (final cell in cells) {
    final key =
        '${cell['boardSize']}::${cell['pairId']}::${cell['opening']}::${cell['firstConfigId']}';
    dimensions[key] =
        (dimensions[key] ?? 0) + ((cell['games']! as List).length);
  }
  final allGames = cells.expand((cell) => cell['games']! as List).toList();
  return {
    'cells': cells.length,
    'expectedCells': metadata['selectedCells'],
    'games': games,
    'expectedGames': metadata['expectedGames'],
    'randomGames':
        allGames.where((game) => (game as Map)['opening'] == 'random').length,
    'illegalMoves':
        cells.fold<int>(0, (sum, cell) => sum + (cell['illegalMoves']! as int)),
    'timeouts':
        cells.fold<int>(0, (sum, cell) => sum + (cell['timeouts']! as int)),
    'fallbackGames': cells.fold<int>(
        0, (sum, cell) => sum + (cell['fallbackGames']! as int)),
    'failureReasons': cells.fold<int>(
      0,
      (sum, cell) => sum + ((cell['failureReasons']! as List).length),
    ),
    'badRepeatCells': cells
        .where((cell) =>
            cell['repeats'] != metadata['repeatCount'] ||
            (cell['games']! as List).length != metadata['repeatCount'])
        .length,
    'dimensionCells': dimensions.length,
    'badDimensionCells': dimensions.values
        .where((count) => count != metadata['repeatCount'])
        .length,
  };
}

void _validateMerged(Map<String, Object?> output) {
  final validation = output['validation']! as Map<String, Object?>;
  final failures = <String>[];
  for (final key in [
    'randomGames',
    'illegalMoves',
    'timeouts',
    'fallbackGames',
    'failureReasons',
    'badRepeatCells',
    'badDimensionCells',
  ]) {
    if (validation[key] != 0) failures.add('$key ${validation[key]}');
  }
  if (validation['games'] != validation['expectedGames']) {
    failures
        .add('games ${validation['games']} != ${validation['expectedGames']}');
  }
  if (failures.isNotEmpty) {
    throw StateError(
        'Headless artifact failed validation: ${failures.join(', ')}');
  }
}

class _Score {
  _Score({
    required this.boardSize,
    this.pairId,
    this.configId,
    this.opening,
    this.firstConfigId,
  });

  final int boardSize;
  final String? pairId;
  final String? configId;
  final String? opening;
  final String? firstConfigId;
  final configWins = <String, int>{};
  final configLosses = <String, int>{};
  int wins = 0;
  int losses = 0;
  int draws = 0;
  int matchWins = 0;
  int matchLosses = 0;
  int matchDraws = 0;
  int illegalMoves = 0;
  int timeouts = 0;
  int fallbackGames = 0;
  final failureReasons = <String>{};

  int get games => wins + losses + draws;
  double get winRate => _rate(wins, losses, draws);

  void addPair(Map<String, Object?> cell) {
    final first = cell['firstConfigId']! as String;
    final second = cell['secondConfigId']! as String;
    final firstWins = cell['firstWins']! as int;
    final secondWins = cell['secondWins']! as int;
    configWins[first] = (configWins[first] ?? 0) + firstWins;
    configLosses[first] = (configLosses[first] ?? 0) + secondWins;
    configWins[second] = (configWins[second] ?? 0) + secondWins;
    configLosses[second] = (configLosses[second] ?? 0) + firstWins;
    draws += cell['draws']! as int;
    addStatus(cell);
  }

  void addPerspective(Map<String, Object?> cell, String id) {
    final isFirst = id == cell['firstConfigId'];
    wins += isFirst ? cell['firstWins']! as int : cell['secondWins']! as int;
    losses += isFirst ? cell['secondWins']! as int : cell['firstWins']! as int;
    draws += cell['draws']! as int;
    addStatus(cell);
  }

  void addStatus(Map<String, Object?> cell) {
    illegalMoves += cell['illegalMoves']! as int;
    timeouts += cell['timeouts']! as int;
    fallbackGames += cell['fallbackGames']! as int;
    failureReasons
        .addAll((cell['failureReasons']! as List).whereType<String>());
  }

  Map<String, Object?> toPairJson() {
    final ids = pairId!.split('::');
    final aWins = configWins[ids[0]] ?? 0;
    final aLosses = configLosses[ids[0]] ?? 0;
    final bWins = configWins[ids[1]] ?? 0;
    final bLosses = configLosses[ids[1]] ?? 0;
    return {
      'boardSize': boardSize,
      'pairId': pairId,
      'configAId': ids[0],
      'configBId': ids[1],
      'configAWins': aWins,
      'configALosses': aLosses,
      'configAWinRate': _rate(aWins, aLosses, draws),
      'configBWins': bWins,
      'configBLosses': bLosses,
      'configBWinRate': _rate(bWins, bLosses, draws),
      'draws': draws,
      'games': aWins + aLosses + draws,
      'illegalMoves': illegalMoves,
      'timeouts': timeouts,
      'fallbackGames': fallbackGames,
      'failureReasons': failureReasons.toList()..sort(),
    };
  }

  Map<String, Object?> toGenericJson() => {
        'boardSize': boardSize,
        if (configId != null) 'configId': configId,
        if (opening != null) 'opening': opening,
        if (firstConfigId != null) 'firstConfigId': firstConfigId,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'games': games,
        'winRate': winRate,
        'illegalMoves': illegalMoves,
        'timeouts': timeouts,
        'fallbackGames': fallbackGames,
        'failureReasons': failureReasons.toList()..sort(),
      };
}

double _rate(int wins, int losses, int draws) {
  final games = wins + losses + draws;
  return games == 0 ? 0 : wins / games;
}

String _pairId(String a, String b) {
  return (a.compareTo(b) <= 0) ? '$a::$b' : '$b::$a';
}

Map<String, String> _parseArgs(List<String> args) {
  final opts = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final eq = arg.indexOf('=');
    if (eq != -1) {
      opts[arg.substring(2, eq)] = arg.substring(eq + 1);
    } else {
      final key = arg.substring(2);
      if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        opts[key] = args[++i];
      } else {
        opts[key] = 'true';
      }
    }
  }
  return opts;
}

class _WorkerRequest {
  const _WorkerRequest({
    required this.workerIndex,
    required this.policyPlane,
    required this.cells,
    required this.progressDir,
    required this.scheduling,
    required this.queueCursorPath,
    required this.queueLockPath,
    required this.assignedCells,
  });

  final int workerIndex;
  final int policyPlane;
  final List<_CellPlan> cells;
  final String progressDir;
  final String scheduling;
  final String? queueCursorPath;
  final String? queueLockPath;
  final int assignedCells;
}

class _CellPlan {
  const _CellPlan({
    required this.index,
    required this.boardSize,
    required this.captureTarget,
    required this.repeatCount,
    required this.maxMoves,
    required this.openingName,
    required this.openingPolicy,
    required this.firstConfigId,
    required this.secondConfigId,
    required this.matchSeed,
    required this.openingSeed,
  });

  final int index;
  final int boardSize;
  final int captureTarget;
  final int repeatCount;
  final int maxMoves;
  final String openingName;
  final String openingPolicy;
  final String firstConfigId;
  final String secondConfigId;
  final int matchSeed;
  final int openingSeed;
}
