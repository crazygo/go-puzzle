import 'dart:typed_data';

import 'model_board_image_recognizer_native.dart'
    if (dart.library.html) 'model_board_image_recognizer_web.dart';
import 'board_image_recognizer.dart';

abstract interface class ModelBoardImageRecognizer {
  static ModelBoardImageRecognizer get instance =>
      createPlatformModelBoardImageRecognizer();

  Future<void> ensureLoaded();

  Future<void> reload();

  Future<void> dispose();

  Future<BoardRecognitionResult> recognize(Uint8List bytes);
}
