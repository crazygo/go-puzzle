// AI search Web Worker entry point.
//
// This file is compiled to a standalone JavaScript bundle that runs inside a
// browser DedicatedWorker.  It must NOT import any Flutter framework packages
// (dart:ui, package:flutter/…); only pure-Dart packages are allowed.
//
// Build command (run from project root before `flutter build web`):
//   dart compile js web/ai_search_worker.dart \
//       -o web/ai_search_worker.dart.js \
//       --no-source-maps
//
// The compiled ai_search_worker.dart.js is loaded by WebWorkerAiSearchRunner
// via  new Worker('ai_search_worker.dart.js').

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html';

import 'package:go_puzzle/game/ai_search_entry.dart';

void main() {
  final scope = DedicatedWorkerGlobalScope.instance;

  scope.onMessage.listen((MessageEvent event) {
    final raw = event.data;
    if (raw == null) return;

    // The main thread sends a plain JS object; convert to a typed Dart map.
    final data = Map<String, dynamic>.from(raw as dynamic);
    final requestId = data['requestId'] as String?;
    if (requestId == null) return;

    final rawParams = data['params'];
    if (rawParams == null) {
      scope.postMessage({
        'requestId': requestId,
        'error': 'Missing params',
      });
      return;
    }
    final params = Map<String, dynamic>.from(rawParams as dynamic);

    try {
      final move = runChooseAiMove(params);
      scope.postMessage({'requestId': requestId, 'move': move});
    } catch (e) {
      scope.postMessage({'requestId': requestId, 'error': e.toString()});
    }
  });
}
