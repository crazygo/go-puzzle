// Platform-agnostic interface for running AI training suggestion searches.

import 'training_suggestion_runner_native.dart'
    if (dart.library.html) 'training_suggestion_runner_web.dart';

typedef TrainingSuggestionRequestId = String;

class TrainingSuggestionRequest {
  const TrainingSuggestionRequest({
    required this.id,
    required this.params,
  });

  final TrainingSuggestionRequestId id;
  final Map<String, dynamic> params;
}

class TrainingSuggestionSearchResult {
  const TrainingSuggestionSearchResult({
    required this.requestId,
    this.suggestions,
    this.structuredSuggestions,
    this.error,
  });

  final TrainingSuggestionRequestId requestId;
  final List<List<num>>? suggestions;
  final List<Map<String, dynamic>>? structuredSuggestions;
  final Object? error;

  bool get hasError => error != null;
}

abstract interface class TrainingSuggestionRunner {
  Future<TrainingSuggestionSearchResult> search(
    TrainingSuggestionRequest request,
  );

  void cancel(TrainingSuggestionRequestId requestId);

  void dispose();
}

TrainingSuggestionRunner createTrainingSuggestionRunner() =>
    createPlatformTrainingSuggestionRunner();
