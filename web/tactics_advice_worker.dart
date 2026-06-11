// Tactics advice Web Worker entry point.
//
// Compiled to a standalone JavaScript bundle for browser DedicatedWorkers.

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist
import 'dart:js_util' as js_util;

import 'package:go_puzzle/game/tactics_advice_entry.dart';

void main() {
  final scope = DedicatedWorkerGlobalScope.instance;

  scope.onMessage.listen((MessageEvent event) {
    String? requestId;
    try {
      final raw = event.data;
      if (raw == null) return;

      final dartified = js_util.dartify(raw);
      if (dartified is! Map) return;

      final data = Map<String, dynamic>.from(dartified);
      requestId = data['requestId'] as String?;
      if (requestId == null) return;

      final rawParams = data['params'];
      if (rawParams == null) {
        scope.postMessage({'requestId': requestId, 'error': 'Missing params'});
        return;
      }

      final dartifiedParams = js_util.dartify(rawParams as Object);
      if (dartifiedParams is! Map) {
        scope.postMessage({
          'requestId': requestId,
          'error': 'params must be a map',
        });
        return;
      }

      final params = Map<String, dynamic>.from(dartifiedParams);
      final advice = runTacticsAdvice(params);
      scope.postMessage({
        'requestId': requestId,
        'advice': advice,
      });
    } catch (e) {
      if (requestId != null) {
        scope.postMessage({'requestId': requestId, 'error': e.toString()});
      }
    }
  });
}
