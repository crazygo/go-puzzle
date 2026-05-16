import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import '../models/board_position.dart';
import 'board_image_recognizer.dart';
import 'model_board_image_recognizer.dart' as public;

public.ModelBoardImageRecognizer createPlatformModelBoardImageRecognizer() =>
    _WebWorkerModelBoardImageRecognizer();

class _WebWorkerModelBoardImageRecognizer
    implements public.ModelBoardImageRecognizer {
  html.Worker? _worker;
  StreamSubscription<html.MessageEvent>? _messageSub;
  StreamSubscription<html.Event>? _errorSub;
  Completer<void>? _loadCompleter;
  Completer<BoardRecognitionResult>? _recognizeCompleter;
  int _nextRequestId = 0;

  @override
  Future<void> ensureLoaded() {
    final existing = _loadCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _loadCompleter = completer;
    _post({'type': 'load', 'requestId': _newRequestId()});
    return completer.future;
  }

  @override
  Future<void> reload() async {
    await dispose();
    return ensureLoaded();
  }

  @override
  Future<void> dispose() async {
    const error = '模型識別器已釋放';
    final loadCompleter = _loadCompleter;
    if (loadCompleter != null && !loadCompleter.isCompleted) {
      loadCompleter.completeError(StateError(error));
    }
    final recognizeCompleter = _recognizeCompleter;
    if (recognizeCompleter != null && !recognizeCompleter.isCompleted) {
      recognizeCompleter.completeError(StateError(error));
    }
    await _resetWorker();
    _loadCompleter = null;
    _recognizeCompleter = null;
  }

  @override
  Future<BoardRecognitionResult> recognize(Uint8List bytes) async {
    await ensureLoaded();
    if (_recognizeCompleter != null) {
      throw StateError('模型識別正在執行');
    }
    final completer = Completer<BoardRecognitionResult>();
    _recognizeCompleter = completer;
    _post({
      'type': 'recognize',
      'requestId': _newRequestId(),
      'bytes': bytes,
    });
    return completer.future.whenComplete(() {
      if (identical(_recognizeCompleter, completer)) {
        _recognizeCompleter = null;
      }
    });
  }

  String _newRequestId() => 'recognition-${_nextRequestId++}';

  void _post(Map<String, Object?> message) {
    try {
      _getOrCreateWorker().postMessage(message);
    } catch (error) {
      _completeWithError(error, resetWorker: true);
    }
  }

  html.Worker _getOrCreateWorker() {
    final existing = _worker;
    if (existing != null) return existing;

    final worker = html.Worker('model_recognition_worker.js');
    _messageSub = worker.onMessage.listen(_handleMessage);
    _errorSub = worker.onError.listen((_) {
      _completeWithError('Web Worker error', resetWorker: true);
    });
    _worker = worker;
    return worker;
  }

  void _handleMessage(html.MessageEvent event) {
    try {
      final raw = event.data;
      if (raw == null) return;
      final dartified = js_util.dartify(raw);
      if (dartified is! Map) return;
      final data = Map<String, dynamic>.from(dartified);
      final type = data['type'] as String?;
      final error = data['error'];
      if (error != null) {
        _completeWithError(error.toString(), resetWorker: true);
        return;
      }

      if (type == 'loaded') {
        final completer = _loadCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
        return;
      }

      if (type == 'recognized') {
        final completer = _recognizeCompleter;
        if (completer == null || completer.isCompleted) return;
        final boardSize = data['boardSize'] as int;
        final rawBoard = data['board'] as List;
        final board = rawBoard
            .map<List<StoneColor>>(
              (row) => (row as List)
                  .map<StoneColor>((value) => StoneColor.values[value as int])
                  .toList(),
            )
            .toList();
        completer.complete(
          BoardRecognitionResult(
            boardSize: boardSize,
            board: board,
            confidence: (data['confidence'] as num).toDouble(),
          ),
        );
      }
    } catch (error) {
      _completeWithError(error, resetWorker: true);
    }
  }

  void _completeWithError(Object error, {required bool resetWorker}) {
    final loadCompleter = _loadCompleter;
    if (loadCompleter != null && !loadCompleter.isCompleted) {
      loadCompleter.completeError(error);
    }
    final recognizeCompleter = _recognizeCompleter;
    if (recognizeCompleter != null && !recognizeCompleter.isCompleted) {
      recognizeCompleter.completeError(error);
    }
    _loadCompleter = null;
    _recognizeCompleter = null;
    if (resetWorker) {
      unawaited(_resetWorker());
    }
  }

  Future<void> _resetWorker() async {
    await _messageSub?.cancel();
    await _errorSub?.cancel();
    _messageSub = null;
    _errorSub = null;
    _worker?.terminate();
    _worker = null;
  }
}
