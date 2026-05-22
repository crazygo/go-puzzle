import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:go_puzzle/game/katago_model_adapter.dart';
import 'package:go_puzzle/game/katago_onnx_features.dart';
import 'package:go_puzzle/models/board_position.dart';

class NodeKatagoOnnxModelAdapter implements AsyncKatagoModelAdapter {
  NodeKatagoOnnxModelAdapter({
    // Kept for older probes; per-request policyPlane is authoritative.
    int policyPlane = 0,
    this.workerScript = 'tool/katago_onnx_worker.js',
    this.encoder = const KatagoOnnxFeatureEncoder(),
  }) : _legacyPolicyPlane = policyPlane;

  // ignore: unused_field
  final int _legacyPolicyPlane;
  final String workerScript;
  final KatagoOnnxFeatureEncoder encoder;
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _stderr = StringBuffer();
  var _nextId = 1;

  @override
  Future<void> preload(Iterable<KatagoModelRequest> requests) async {
    final models = requests.map((request) => request.modelAsset).toSet();
    for (final model in models) {
      final response = await _send({'type': 'load', 'model': model});
      if (response['ok'] != true) {
        throw StateError(
          'katago_node_onnx_load_failed:$model:${response['error']}',
        );
      }
    }
  }

  @override
  Future<KatagoModelEvaluation> chooseMove(KatagoModelRequest request) async {
    try {
      final legalMoves = request.board.getLegalMoves().where((moveIndex) {
        return request.board
            .analyzeMove(
              moveIndex ~/ request.board.size,
              moveIndex % request.board.size,
            )
            .isLegal;
      }).toList(growable: false);
      if (legalMoves.isEmpty) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'katago_node_onnx_no_legal_moves',
        );
      }
      final features = encoder.encode(request.board);
      final response = await _send({
        'type': 'eval',
        'model': request.modelAsset,
        'binInput': features.binInput.toList(growable: false),
        'binShape': features.binShape,
        'globalInput': features.globalInput.toList(growable: false),
        'globalShape': features.globalShape,
        'legalMoves': legalMoves,
        'boardPointCount': request.board.size * request.board.size,
        'policyPlane': request.policyPlane,
        'policyTemperature': request.policyTemperature,
        'candidateLimit': request.candidateLimit,
      }).timeout(Duration(milliseconds: request.timeBudgetMillis));
      if (response['ok'] != true) {
        return KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'katago_node_onnx_error:${response['error']}',
        );
      }
      final move = response['move'];
      if (move is! int) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'katago_node_onnx_bad_move_response',
        );
      }
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.ready,
        move: BoardPosition(
          move ~/ request.board.size,
          move % request.board.size,
        ),
        policyCandidates: _policyCandidates(
          response['policyCandidates'],
          boardSize: request.board.size,
        ),
        value: _valueEstimate(response['value']),
        scoreBelief: _scoreBelief(response['scoreBelief']),
      );
    } catch (error) {
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.failed,
        failureReason: 'katago_node_onnx_error:$error',
      );
    }
  }

  Future<Map<String, dynamic>> _send(Map<String, Object?> request) async {
    final process = await _ensureProcess();
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    process.stdin.writeln(jsonEncode({'id': id, ...request}));
    return completer.future;
  }

  Future<Process> _ensureProcess() async {
    final existing = _process;
    if (existing != null) return existing;
    if (!File(workerScript).existsSync()) {
      throw StateError('katago_node_worker_missing:$workerScript');
    }
    final process = await Process.start('node', [workerScript]);
    _process = process;
    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine);
    _stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _stderr.writeln(line));
    unawaited(process.exitCode.then((code) {
      final error = StateError(
        'katago_node_worker_exited:$code:${_stderr.toString().trim()}',
      );
      for (final completer in _pending.values) {
        if (!completer.isCompleted) completer.completeError(error);
      }
      _pending.clear();
      _process = null;
    }));
    return process;
  }

  void _handleLine(String line) {
    try {
      final json = jsonDecode(line);
      if (json is! Map<String, dynamic>) return;
      final id = json['id'];
      if (id is! int) return;
      final completer = _pending.remove(id);
      if (completer == null || completer.isCompleted) return;
      completer.complete(json);
    } catch (error) {
      for (final completer in _pending.values) {
        if (!completer.isCompleted) completer.completeError(error);
      }
      _pending.clear();
    }
  }

  Future<void> close() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    final process = _process;
    _process = null;
    process?.kill();
  }

  List<KatagoPolicyCandidate> _policyCandidates(
    Object? raw, {
    required int boardSize,
  }) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map)
          _policyCandidate(
            Map<String, dynamic>.from(entry),
            boardSize: boardSize,
          ),
    ];
  }

  KatagoPolicyCandidate _policyCandidate(
    Map<String, dynamic> entry, {
    required int boardSize,
  }) {
    final move = (entry['move'] as num).toInt();
    return KatagoPolicyCandidate(
      position: BoardPosition(move ~/ boardSize, move % boardSize),
      score: (entry['score'] as num).toDouble(),
      probability: (entry['probability'] as num).toDouble(),
      rank: (entry['rank'] as num).toInt(),
      policyPlane: (entry['policyPlane'] as num).toInt(),
    );
  }

  KatagoValueEstimate? _valueEstimate(Object? raw) {
    if (raw is! Map) return null;
    return KatagoValueEstimate(
      win: (raw['win'] as num).toDouble(),
      loss: (raw['loss'] as num).toDouble(),
      noResult: (raw['noResult'] as num).toDouble(),
    );
  }

  KatagoScoreBeliefSummary? _scoreBelief(Object? raw) {
    if (raw is! Map) return null;
    return KatagoScoreBeliefSummary(
      mean: (raw['mean'] as num).toDouble(),
      stdev: (raw['stdev'] as num).toDouble(),
      distribution: (raw['distribution'] as List?)
              ?.whereType<num>()
              .map((value) => value.toDouble())
              .toList(growable: false) ??
          const [],
    );
  }
}
