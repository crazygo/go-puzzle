// Native isolate-backed implementation of TrainingSuggestionRunner.

import 'package:flutter/foundation.dart' show compute;

import 'training_suggestion_entry.dart' show runTrainingSuggestions;
import 'training_suggestion_runner.dart';

TrainingSuggestionRunner createPlatformTrainingSuggestionRunner() =>
    _IsolateTrainingSuggestionRunner();

class _IsolateTrainingSuggestionRunner implements TrainingSuggestionRunner {
  final Set<TrainingSuggestionRequestId> _cancelled = {};
  bool _disposed = false;

  @override
  Future<TrainingSuggestionSearchResult> search(
    TrainingSuggestionRequest request,
  ) async {
    if (_disposed) {
      return TrainingSuggestionSearchResult(
        requestId: request.id,
        error: 'Runner has been disposed',
      );
    }
    try {
      final suggestions = await compute(runTrainingSuggestions, request.params);
      if (_cancelled.remove(request.id)) {
        return TrainingSuggestionSearchResult(requestId: request.id);
      }
      return TrainingSuggestionSearchResult(
        requestId: request.id,
        suggestions: suggestions,
      );
    } catch (e) {
      _cancelled.remove(request.id);
      return TrainingSuggestionSearchResult(requestId: request.id, error: e);
    }
  }

  @override
  void cancel(TrainingSuggestionRequestId requestId) {
    _cancelled.add(requestId);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled.clear();
  }
}
