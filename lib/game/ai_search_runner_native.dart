// Native (isolate-backed) implementation of AiSearchRunner.
//
// Uses Flutter's compute() to run the AI search in a background Dart isolate,
// keeping the UI thread free on iOS, Android, and desktop platforms.

import 'package:flutter/foundation.dart' show compute;

import 'ai_search_entry.dart' show runChooseAiMove;
import 'ai_search_runner.dart';

/// Creates the native isolate-backed [AiSearchRunner].
AiSearchRunner createPlatformAiSearchRunner() => _IsolateAiSearchRunner();

class _IsolateAiSearchRunner implements AiSearchRunner {
  final Set<AiSearchRequestId> _cancelled = {};
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
}
