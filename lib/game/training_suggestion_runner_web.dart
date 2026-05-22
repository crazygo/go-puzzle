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
  html.Worker? _worker;
  StreamSubscription<html.MessageEvent>? _messageSub;
  StreamSubscription<html.Event>? _errorSub;

  final Map<TrainingSuggestionRequestId,
      Completer<TrainingSuggestionSearchResult>> _pending = {};

  bool _disposed = false;

  html.Worker _getOrCreateWorker() {
    if (_worker != null) return _worker!;

    final worker = html.Worker('training_suggestion_worker.dart.js');
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
        final suggestions = rawSuggestions == null
            ? const <List<num>>[]
            : (rawSuggestions as Iterable)
                .map((entry) => List<num>.from(entry as Iterable))
                .toList(growable: false);
        completer.complete(
          TrainingSuggestionSearchResult(
            requestId: requestId,
            suggestions: suggestions,
          ),
        );
      }
    } catch (e) {
      for (final entry in Map.of(_pending).entries) {
        _pending.remove(entry.key);
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

  void _handleWorkerError(html.Event _) {
    final entries = Map<TrainingSuggestionRequestId,
        Completer<TrainingSuggestionSearchResult>>.from(_pending);
    _pending.clear();
    _tearDownWorker();

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

    try {
      _getOrCreateWorker().postMessage({
        'requestId': request.id,
        'params': request.params,
      });
    } catch (e) {
      _pending.remove(request.id);
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
    if (completer == null) return;

    _tearDownWorker();

    if (!completer.isCompleted) {
      completer.complete(TrainingSuggestionSearchResult(requestId: requestId));
    }

    for (final entry in Map.of(_pending).entries) {
      _pending.remove(entry.key);
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
    _tearDownWorker();
  }
}
