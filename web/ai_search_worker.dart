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
// dart:js_util is a web-only library (only available when dart.library.html is
// true).  The analyzer running in a non-web context does not resolve it, hence
// the uri_does_not_exist suppression.  At web compile time (dart compile js or
// flutter build web) the import resolves correctly.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist
import 'dart:js_util' as js_util;

import 'package:go_puzzle/game/ai_search_entry.dart';

void main() {
  final scope = DedicatedWorkerGlobalScope.instance;

  scope.onMessage.listen((MessageEvent event) {
    // All message decoding is wrapped so that any error sends a structured
    // {requestId, error} reply rather than silently hanging the main thread.
    String? requestId;
    try {
      final raw = event.data;
      if (raw == null) return;

      // event.data arrives as a JS object; use dart:js_util.dartify() to
      // convert it recursively to Dart Maps/Lists.
      final dartified = js_util.dartify(raw);
      if (dartified is! Map) {
        return; // malformed message; no requestId to reply to
      }
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

      final move = runChooseAiMove(params);
      scope.postMessage({'requestId': requestId, 'move': move});
    } catch (e) {
      // Send the error back so the main-thread Future completes rather than
      // hanging indefinitely.
      if (requestId != null) {
        scope.postMessage({'requestId': requestId, 'error': e.toString()});
      }
    }
  });
}
