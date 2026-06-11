// Native isolate-backed implementation of [TacticsAdviceRunner].

import 'package:flutter/foundation.dart' show compute;

import 'capture_ai_tactics.dart';
import 'tactics_advice_entry.dart' show runTacticsAdvice;
import 'tactics_advice_runner.dart';

TacticsAdviceRunner createPlatformTacticsAdviceRunner() =>
    _IsolateTacticsAdviceRunner();

class _IsolateTacticsAdviceRunner implements TacticsAdviceRunner {
  final Set<TacticsAdviceRequestId> _cancelled = {};
  bool _disposed = false;

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

  Future<TacticsAdviceSearchResult> search(TacticsAdviceRequest request) async {
    if (_disposed) {
      return TacticsAdviceSearchResult(
        requestId: request.id,
        error: 'Runner has been disposed',
      );
    }
    try {
      final raw = await compute(runTacticsAdvice, request.params);
      if (_cancelled.remove(request.id)) {
        return TacticsAdviceSearchResult(requestId: request.id);
      }
      return TacticsAdviceSearchResult(
        requestId: request.id,
        advice: decodeTacticsAdvice(Map<String, dynamic>.from(raw)),
      );
    } catch (e) {
      _cancelled.remove(request.id);
      return TacticsAdviceSearchResult(requestId: request.id, error: e);
    }
  }

  @override
  void cancel(TacticsAdviceRequestId requestId) {
    _cancelled.add(requestId);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled.clear();
  }
}
