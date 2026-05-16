// Native (isolate-backed) implementation of AiSearchRunner.
//
// Uses Flutter's compute() to run the AI search in a background Dart isolate,
// keeping the UI thread free on iOS, Android, and desktop platforms.

import 'package:flutter/foundation.dart' show compute;

import 'ai_search_entry.dart' show runChooseAiMove;
import 'ai_search_runner.dart';
import 'territory_onnx_bridge.dart';

/// Creates the native isolate-backed [AiSearchRunner].
AiSearchRunner createPlatformAiSearchRunner() => _IsolateAiSearchRunner();

class _IsolateAiSearchRunner implements AiSearchRunner {
  final Set<AiSearchRequestId> _cancelled = {};
  final TerritoryOnnxBridge _territoryOnnxBridge = TerritoryOnnxBridge();
  bool _disposed = false;

  @override
  Future<AiSearchResult> search(AiSearchRequest request) async {
    if (_disposed) {
      return AiSearchResult(
        requestId: request.id,
        error: 'Runner has been disposed',
      );
    }
    try {
      if (request.params['gameMode'] == 'territory') {
        final nativeResult =
            await _territoryOnnxBridge.pickMove(request.params);
        if (_cancelled.remove(request.id)) {
          return AiSearchResult(requestId: request.id);
        }
        if (nativeResult?.usedNative == true &&
            _isUsableNativeTerritoryMove(
              nativeResult?.move,
              request.params['boardSize'] as int?,
              request.params['legalMoves'] as List?,
            )) {
          return AiSearchResult(
              requestId: request.id, move: nativeResult!.move);
        }
      }
      final move = await compute(runChooseAiMove, request.params);
      // Discard result if the request was cancelled while compute() ran.
      if (_cancelled.remove(request.id)) {
        return AiSearchResult(requestId: request.id);
      }
      return AiSearchResult(requestId: request.id, move: move);
    } catch (e) {
      _cancelled.remove(request.id);
      return AiSearchResult(requestId: request.id, error: e);
    }
  }

  @override
  void cancel(AiSearchRequestId requestId) {
    _cancelled.add(requestId);
    // Note: compute() does not support mid-flight cancellation; the isolate
    // will complete its work and the result will be silently discarded above.
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled.clear();
  }

  bool _isUsableNativeTerritoryMove(
    List<int>? move,
    int? boardSize,
    List? legalMoves,
  ) {
    if (move == null || move.length != 2) return false;
    if (move[0] == -1 && move[1] == -1) return true;
    if (boardSize == null || boardSize <= 0) return false;
    if (move[0] < 0 ||
        move[1] < 0 ||
        move[0] >= boardSize ||
        move[1] >= boardSize) {
      return false;
    }
    final moveIndex = move[0] * boardSize + move[1];
    if (legalMoves == null || legalMoves.isEmpty) return true;
    return legalMoves.any((entry) {
      return entry is int && entry == moveIndex;
    });
  }
}
