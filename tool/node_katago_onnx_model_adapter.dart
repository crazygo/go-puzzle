import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:go_puzzle/game/katago_model_adapter.dart';
import 'package:go_puzzle/game/katago_onnx_features.dart';
import 'package:go_puzzle/models/board_position.dart';

class NodeKatagoOnnxModelAdapter implements AsyncKatagoModelAdapter {
  NodeKatagoOnnxModelAdapter({
    this.policyPlane = 0,
    this.workerScript = 'tool/katago_onnx_worker.js',
    this.encoder = const KatagoOnnxFeatureEncoder(),
  });

  final int policyPlane;
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
        'policyPlane': policyPlane,
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
}
