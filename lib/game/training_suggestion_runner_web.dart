// Web Worker-backed implementation of TrainingSuggestionRunner.

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist
import 'dart:js_util' as js_util;

import 'dart:async';

import 'training_suggestion_runner.dart';

TrainingSuggestionRunner createPlatformTrainingSuggestionRunner() =>
    _WebWorkerTrainingSuggestionRunner();

class _WebWorkerTrainingSuggestionRunner implements TrainingSuggestionRunner {
  final Map<String, _TrainingSuggestionWorkerHandle> _workers = {};

  final Map<TrainingSuggestionRequestId,
      Completer<TrainingSuggestionSearchResult>> _pending = {};
  final Map<TrainingSuggestionRequestId, String> _requestScripts = {};

  bool _disposed = false;

  _TrainingSuggestionWorkerHandle _getOrCreateWorker(String scriptUrl) {
    final existing = _workers[scriptUrl];
    if (existing != null) return existing;

    final worker = html.Worker(scriptUrl);
    final handle = _TrainingSuggestionWorkerHandle(
      worker: worker,
      messageSub: worker.onMessage.listen(_handleMessage),
      errorSub: worker.onError.listen((_) => _handleWorkerError(scriptUrl)),
    );
    _workers[scriptUrl] = handle;
    return handle;
  }

  void _tearDownWorker(String scriptUrl) {
    _workers.remove(scriptUrl)?.dispose();
  }

  void _tearDownWorkers() {
    for (final worker in _workers.values) {
      worker.dispose();
    }
    _workers.clear();
  }

  void _handleMessage(html.MessageEvent event) {
    final raw = event.data;
    if (raw == null) return;

    try {
      final dartified = js_util.dartify(raw);
      if (dartified is! Map) return;
      final data = Map<String, dynamic>.from(dartified);

      final requestId = data['requestId'] as String?;
      if (requestId == null) return;

      final completer = _pending.remove(requestId);
      _requestScripts.remove(requestId);
      if (completer == null || completer.isCompleted) return;

      final error = data['error'];
      if (error != null) {
        completer.complete(
          TrainingSuggestionSearchResult(
            requestId: requestId,
            error: error.toString(),
          ),
        );
      } else {
        final rawSuggestions = data['suggestions'];
        final rawStructuredSuggestions = data['structuredSuggestions'];
        final suggestions = rawSuggestions == null
            ? const <List<num>>[]
            : (rawSuggestions as Iterable)
                .map((entry) => List<num>.from(entry as Iterable))
                .toList(growable: false);
        final structuredSuggestions = rawStructuredSuggestions == null
            ? null
            : (rawStructuredSuggestions as Iterable)
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(growable: false);
        completer.complete(
          TrainingSuggestionSearchResult(
            requestId: requestId,
            suggestions: suggestions,
            structuredSuggestions: structuredSuggestions,
          ),
        );
      }
    } catch (e) {
      for (final entry in Map.of(_pending).entries) {
        _pending.remove(entry.key);
        _requestScripts.remove(entry.key);
        if (!entry.value.isCompleted) {
          entry.value.complete(
            TrainingSuggestionSearchResult(
              requestId: entry.key,
              error: 'Failed to decode worker message: $e',
            ),
          );
        }
      }
    }
  }

  void _handleWorkerError(String scriptUrl) {
    final entries = <TrainingSuggestionRequestId,
        Completer<TrainingSuggestionSearchResult>>{};
    for (final entry in Map.of(_requestScripts).entries) {
      if (entry.value != scriptUrl) continue;
      final completer = _pending.remove(entry.key);
      _requestScripts.remove(entry.key);
      if (completer != null) entries[entry.key] = completer;
    }
    _tearDownWorker(scriptUrl);

    for (final entry in entries.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(
          TrainingSuggestionSearchResult(
            requestId: entry.key,
            error: 'Web Worker error',
          ),
        );
      }
    }
  }

  @override
  Future<TrainingSuggestionSearchResult> search(
    TrainingSuggestionRequest request,
  ) {
    if (_disposed) {
      return Future.value(
        TrainingSuggestionSearchResult(
          requestId: request.id,
          error: 'Runner has been disposed',
        ),
      );
    }

    final completer = Completer<TrainingSuggestionSearchResult>();
    _pending[request.id] = completer;
    final scriptUrl = _workerScriptFor(request);
    _requestScripts[request.id] = scriptUrl;

    try {
      _getOrCreateWorker(scriptUrl).worker.postMessage({
        'requestId': request.id,
        'params': request.params,
      });
    } catch (e) {
      _pending.remove(request.id);
      _requestScripts.remove(request.id);
      if (!completer.isCompleted) {
        completer.complete(
          TrainingSuggestionSearchResult(requestId: request.id, error: e),
        );
      }
    }

    return completer.future;
  }

  @override
  void cancel(TrainingSuggestionRequestId requestId) {
    final completer = _pending.remove(requestId);
    _requestScripts.remove(requestId);
    if (completer == null) return;

    _tearDownWorkers();

    if (!completer.isCompleted) {
      completer.complete(TrainingSuggestionSearchResult(requestId: requestId));
    }

    for (final entry in Map.of(_pending).entries) {
      _pending.remove(entry.key);
      _requestScripts.remove(entry.key);
      if (!entry.value.isCompleted) {
        entry.value.complete(
          TrainingSuggestionSearchResult(requestId: entry.key),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;

    for (final entry in Map.of(_pending).entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(
          TrainingSuggestionSearchResult(
            requestId: entry.key,
            error: 'Runner has been disposed',
          ),
        );
      }
    }
    _pending.clear();
    _requestScripts.clear();
    _tearDownWorkers();
  }

  String _workerScriptFor(TrainingSuggestionRequest request) {
    // Spec: docs/specs_map/technical_contracts.yaml#ai_background_execution
    return request.params['coachBackend'] == 'katago_onnx'
        ? 'katago_training_suggestion_worker.js'
        : 'training_suggestion_worker.dart.js';
  }
}

class _TrainingSuggestionWorkerHandle {
  const _TrainingSuggestionWorkerHandle({
    required this.worker,
    required this.messageSub,
    required this.errorSub,
  });

  final html.Worker worker;
  final StreamSubscription<html.MessageEvent> messageSub;
  final StreamSubscription<html.Event> errorSub;

  void dispose() {
    messageSub.cancel();
    errorSub.cancel();
    worker.terminate();
  }
}
