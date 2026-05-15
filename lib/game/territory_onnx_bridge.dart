import 'package:flutter/services.dart';

class NativeTerritoryMoveResult {
  const NativeTerritoryMoveResult({
    required this.usedNative,
    this.move,
    this.backend,
    this.error,
  });

  final bool usedNative;
  final List<int>? move;
  final String? backend;
  final Object? error;

  bool get hasMove => move != null;
}

class TerritoryOnnxBridge {
  static const MethodChannel _channel =
      MethodChannel('go_puzzle/territory_onnx');

  Future<NativeTerritoryMoveResult?> pickMove(
    Map<String, dynamic> params,
  ) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('pickMove', params);
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      final rawMove = map['move'];
      return NativeTerritoryMoveResult(
        usedNative: (map['usedNative'] as bool?) ?? false,
        backend: map['backend'] as String?,
        error: map['error'],
        move: rawMove is List ? rawMove.cast<int>() : null,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      return NativeTerritoryMoveResult(
        usedNative: false,
        error: error.message ?? error.code,
      );
    }
  }
}
