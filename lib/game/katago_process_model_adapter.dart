import 'dart:convert';
import 'dart:io';

import '../models/board_position.dart';
import 'katago_model_adapter.dart';

class ProcessKatagoOnnxModelAdapter implements KatagoModelAdapter {
  const ProcessKatagoOnnxModelAdapter({
    this.pythonExecutable = 'python3',
    this.scriptPath = 'tool/katago_onnx_move.py',
    this.workingDirectory,
  });

  final String pythonExecutable;
  final String scriptPath;
  final String? workingDirectory;

  @override
  KatagoModelEvaluation chooseMove(KatagoModelRequest request) {
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
        failureReason: 'katago_onnx_no_legal_moves',
      );
    }

    final payload = jsonEncode({
      'model': request.modelAsset,
      'size': request.board.size,
      'currentPlayer': request.board.currentPlayer,
      'cells': request.board.cells,
      'legalMoves': legalMoves,
      'visits': request.visits,
      'timeBudgetMillis': request.timeBudgetMillis,
      'policyTemperature': request.policyTemperature,
      'candidateLimit': request.candidateLimit,
    });
    final result = Process.runSync(
      pythonExecutable,
      [scriptPath, payload],
      workingDirectory: workingDirectory,
    );
    final stdoutText = (result.stdout as String).trim();
    if (stdoutText.isEmpty) {
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.failed,
        failureReason: 'katago_onnx_empty_output:${result.stderr}',
      );
    }
    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map<String, Object?>) {
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.failed,
        failureReason: 'katago_onnx_bad_output:$stdoutText',
      );
    }
    final error = decoded['error'];
    if (error != null) {
      return KatagoModelEvaluation(
        status: result.exitCode == 0
            ? KatagoBackendStatus.failed
            : KatagoBackendStatus.unavailable,
        failureReason: 'katago_onnx_process_error:$error',
      );
    }
    final move = decoded['move'];
    if (move is! List || move.length != 2) {
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.failed,
        failureReason: 'katago_onnx_missing_move:$stdoutText',
      );
    }
    final row = move[0];
    final col = move[1];
    if (row is! int || col is! int) {
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.failed,
        failureReason: 'katago_onnx_bad_move:$stdoutText',
      );
    }
    return KatagoModelEvaluation(
      status: KatagoBackendStatus.ready,
      move: BoardPosition(row, col),
    );
  }
}
