// Web Worker-backed implementation of AiSearchRunner for Flutter Web.
//
// Spawns a single persistent DedicatedWorker loaded from the pre-compiled
// ai_search_worker.dart.js asset and routes search requests through
// postMessage / onMessage.  Cancelling a pending request terminates the
// worker immediately so the browser thread is freed without waiting for the
// current search to finish; a fresh worker is spun up on the next request.

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'dart:async';

import 'ai_search_runner.dart';

/// Creates the Web Worker-backed [AiSearchRunner].
AiSearchRunner createPlatformAiSearchRunner() => _WebWorkerAiSearchRunner();

class _WebWorkerAiSearchRunner implements AiSearchRunner {
  html.Worker? _worker;
  StreamSubscription<html.MessageEvent>? _messageSub;
  StreamSubscription<html.Event>? _errorSub;

  final Map<AiSearchRequestId, Completer<AiSearchResult>> _pending = {};

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Worker lifecycle helpers
  // ---------------------------------------------------------------------------

  html.Worker _getOrCreateWorker() {
    if (_worker != null) return _worker!;

    final worker = html.Worker('ai_search_worker.dart.js');
    _messageSub = worker.onMessage.listen(_handleMessage);
    _errorSub = worker.onError.listen(_handleWorkerError);
    _worker = worker;
    return worker;
  }

  void _tearDownWorker() {
    _messageSub?.cancel();
    _messageSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _worker?.terminate();
    _worker = null;
  }

  // ---------------------------------------------------------------------------
  // Message / error handlers
  // ---------------------------------------------------------------------------

  void _handleMessage(html.MessageEvent event) {
    final raw = event.data;
    if (raw == null) return;

    // The worker sends back a plain JS object; dart:html exposes it as a
    // JsObject / Map-like object.  Convert to a typed map via jsify/dartify.
    final data = Map<String, dynamic>.from(raw as dynamic);

    final requestId = data['requestId'] as String?;
    if (requestId == null) return;

    final completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) return;

    final error = data['error'];
    if (error != null) {
      completer.complete(
        AiSearchResult(requestId: requestId, error: error.toString()),
      );
    } else {
      final moveRaw = data['move'];
      final move =
          moveRaw == null ? null : List<int>.from(moveRaw as Iterable);
      completer.complete(AiSearchResult(requestId: requestId, move: move));
    }
  }

  void _handleWorkerError(html.Event _) {
    // Complete all pending requests with an error and recreate the worker on
    // the next search call.
    final entries = Map<AiSearchRequestId, Completer<AiSearchResult>>.from(
      _pending,
    );
    _pending.clear();
    _tearDownWorker();

    for (final entry in entries.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(
          AiSearchResult(
            requestId: entry.key,
            error: 'Web Worker error',
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // AiSearchRunner interface
  // ---------------------------------------------------------------------------

  @override
  Future<AiSearchResult> search(AiSearchRequest request) {
    if (_disposed) {
      return Future.value(
        AiSearchResult(
          requestId: request.id,
          error: 'Runner has been disposed',
        ),
      );
    }

    final completer = Completer<AiSearchResult>();
    _pending[request.id] = completer;

    _getOrCreateWorker().postMessage({
      'requestId': request.id,
      'params': request.params,
    });

    return completer.future;
  }

  @override
  void cancel(AiSearchRequestId requestId) {
    final completer = _pending.remove(requestId);
    if (completer == null) return;

    // Terminate the worker immediately so the browser thread is freed.
    // A new worker will be spun up on the next search() call.
    _tearDownWorker();

    if (!completer.isCompleted) {
      completer.complete(AiSearchResult(requestId: requestId));
    }

    // Any other pending requests (there should only be one at a time, but be
    // safe) are also completed as cancelled.
    for (final entry in Map.of(_pending).entries) {
      _pending.remove(entry.key);
      if (!entry.value.isCompleted) {
        entry.value.complete(AiSearchResult(requestId: entry.key));
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;

    for (final entry in Map.of(_pending).entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(
          AiSearchResult(
            requestId: entry.key,
            error: 'Runner has been disposed',
          ),
        );
      }
    }
    _pending.clear();
    _tearDownWorker();
  }
}
