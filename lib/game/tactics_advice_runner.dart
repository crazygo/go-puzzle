// Platform-agnostic interface for tactics advice searches.

import 'capture_ai_tactics.dart';
import 'tactics_advice_runner_native.dart'
    if (dart.library.html) 'tactics_advice_runner_web.dart';
import 'tactics_advice_snapshot.dart';

typedef TacticsAdviceRequestId = String;

class TacticsAdviceRequest {
  const TacticsAdviceRequest({
    required this.id,
    required this.params,
  });

  final TacticsAdviceRequestId id;
  final Map<String, dynamic> params;
}

class TacticsAdviceSearchResult {
  const TacticsAdviceSearchResult({
    required this.requestId,
    this.advice,
    this.error,
  });

  final TacticsAdviceRequestId requestId;
  final TacticsAdviceSnapshot? advice;
  final Object? error;

  bool get hasError => error != null;
}

abstract interface class TacticsAdviceRunner {
  Future<TacticsAdviceSearchResult> buildAdvice(
      CaptureAiTacticsProblem problem);

  void cancel(TacticsAdviceRequestId requestId);

  void dispose();
}

TacticsAdviceRunner createTacticsAdviceRunner() =>
    createPlatformTacticsAdviceRunner();

Map<String, dynamic> tacticsAdviceParamsFor(CaptureAiTacticsProblem problem) {
  return {'problem': problem.toJson()};
}

TacticsAdviceSnapshot decodeTacticsAdvice(Map<String, dynamic> map) {
  return TacticsAdviceSnapshot.fromMap(map);
}
