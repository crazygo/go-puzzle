// Platform-agnostic interface for running AI searches.
//
// The concrete implementation is selected at compile time via a conditional
// import:
//   • dart:io  environments (iOS / Android / desktop / native tests) → IsolateAiSearchRunner
//   • dart:html environments (Flutter Web)                           → WebWorkerAiSearchRunner

import 'ai_search_runner_native.dart'
    if (dart.library.html) 'ai_search_runner_web.dart';

/// Opaque identifier for a single AI search request.
typedef AiSearchRequestId = String;

/// Serialised board state and search parameters sent to the runner.
class AiSearchRequest {
  const AiSearchRequest({
    required this.id,
    required this.params,
  });

  /// Unique identifier for this request.  Used to correlate results and
  /// support best-effort cancellation.
  final AiSearchRequestId id;

  /// Serialised board + search parameters understood by [runChooseAiMove].
  final Map<String, dynamic> params;
}

/// Result returned by [AiSearchRunner.search].
class AiSearchResult {
  const AiSearchResult({
    required this.requestId,
    this.move,
    this.error,
  });

  /// Echoes the [AiSearchRequest.id] that produced this result.
  final AiSearchRequestId requestId;

  /// The chosen move as `[row, col]`, or `null` when no legal move exists.
  final List<int>? move;

  /// Non-`null` when the search ended with an error.
  final Object? error;

  bool get hasError => error != null;
}

/// Platform-agnostic interface for running AI move searches.
///
/// Callers (e.g. [CaptureGameProvider]) use this interface without knowing
/// whether the search runs in a Dart isolate or a browser Web Worker.
abstract interface class AiSearchRunner {
  /// Schedules an AI search for [request] and returns a [Future] that
  /// completes with the search result.
  ///
  /// The [Future] always completes (never throws); errors are surfaced via
  /// [AiSearchResult.error].
  Future<AiSearchResult> search(AiSearchRequest request);

  /// Best-effort cancellation of the in-flight request identified by
  /// [requestId].
  ///
  /// If the search has already completed this is a no-op.  The [Future]
  /// returned by [search] may still complete after [cancel] is called, but
  /// the caller should discard the result.
  void cancel(AiSearchRequestId requestId);

  /// Release resources held by this runner.  Must be called when the runner
  /// is no longer needed.
  void dispose();
}

/// Creates the platform-appropriate [AiSearchRunner].
///
/// On native platforms (iOS / Android / desktop) this returns an isolate-
/// backed runner; on Flutter Web it returns a Web Worker-backed runner.
AiSearchRunner createAiSearchRunner() => createPlatformAiSearchRunner();
