// Web Worker-backed implementation of [TacticsAdviceRunner].

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist
import 'dart:js_util' as js_util;

import 'dart:async';

import 'capture_ai_tactics.dart';
import 'tactics_advice_runner.dart';

const _workerScript = 'tactics_advice_worker.dart.js';

TacticsAdviceRunner createPlatformTacticsAdviceRunner() =>
    _WebWorkerTacticsAdviceRunner();

class _WebWorkerTacticsAdviceRunner implements TacticsAdviceRunner {
  html.Worker? _worker;
  StreamSubscription<html.MessageEvent>? _messageSub;
  StreamSubscription<html.Event>? _errorSub;

  final Map<TacticsAdviceRequestId, Completer<TacticsAdviceSearchResult>>
      _pending = {};
  bool _disposed = false;

  html.Worker _getOrCreateWorker() {
    final existing = _worker;
    if (existing != null) return existing;

    final worker = html.Worker(_workerScript);
    _worker = worker;
    _messageSub = worker.onMessage.listen(_handleMessage);
    _errorSub = worker.onError.listen((_) => _handleWorkerError());
    return worker;
  }

  void _tearDownWorker() {
    _messageSub?.cancel();
    _errorSub?.cancel();
    _messageSub = null;
    _errorSub = null;
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
          TacticsAdviceSearchResult(
            requestId: requestId,
            error: error.toString(),
          ),
        );
        return;
      }

      final rawAdvice = data['advice'];
      if (rawAdvice is! Map) {
        completer.complete(
          TacticsAdviceSearchResult(
            requestId: requestId,
            error: 'Missing advice payload',
          ),
        );
        return;
      }

      completer.complete(
        TacticsAdviceSearchResult(
          requestId: requestId,
          advice: decodeTacticsAdvice(Map<String, dynamic>.from(rawAdvice)),
        ),
      );
    } catch (e) {
      for (final entry in Map.of(_pending).entries) {
        _pending.remove(entry.key);
        if (!entry.value.isCompleted) {
          entry.value.complete(
            TacticsAdviceSearchResult(
              requestId: entry.key,
              error: 'Failed to decode worker message: $e',
            ),
          );
        }
      }
    }
  }

  void _handleWorkerError() {
    final entries = Map.of(_pending);
    _pending.clear();
    _tearDownWorker();

    for (final entry in entries.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(
          TacticsAdviceSearchResult(
            requestId: entry.key,
            error: 'Web Worker error',
          ),
        );
      }
    }
  }

  @override
  Future<TacticsAdviceSearchResult> buildAdvice(
    CaptureAiTacticsProblem problem,
  ) {
    return search(
      TacticsAdviceRequest(
        id: 'tactics-advice-${problem.id}-${DateTime.now().microsecondsSinceEpoch}',
        params: tacticsAdviceParamsFor(problem),
      ),
    );
  }

  Future<TacticsAdviceSearchResult> search(TacticsAdviceRequest request) {
    if (_disposed) {
      return Future.value(
        TacticsAdviceSearchResult(
          requestId: request.id,
          error: 'Runner has been disposed',
        ),
      );
    }

    final completer = Completer<TacticsAdviceSearchResult>();
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
          TacticsAdviceSearchResult(requestId: request.id, error: e),
        );
      }
    }

    return completer.future;
  }

  @override
  void cancel(TacticsAdviceRequestId requestId) {
    final completer = _pending.remove(requestId);
    if (completer == null) return;

    _tearDownWorker();

    if (!completer.isCompleted) {
      completer.complete(TacticsAdviceSearchResult(requestId: requestId));
    }

    for (final entry in Map.of(_pending).entries) {
      _pending.remove(entry.key);
      if (!entry.value.isCompleted) {
        entry.value.complete(
          TacticsAdviceSearchResult(requestId: entry.key),
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
          TacticsAdviceSearchResult(
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
