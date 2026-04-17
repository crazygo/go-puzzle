import 'package:flutter/foundation.dart';

enum BoardSizeOption {
  nine(9, '9路吃子'),
  thirteen(13, '13路吃子'),
  nineteen(19, '19路围空');

  final int size;
  final String label;
  const BoardSizeOption(this.size, this.label);
}

class SettingsProvider extends ChangeNotifier {
  BoardSizeOption _boardSize = BoardSizeOption.nine;
  bool _showHints = true;
  bool _showMoveNumbers = false;
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

  BoardSizeOption get boardSize => _boardSize;
  bool get showHints => _showHints;
  bool get showMoveNumbers => _showMoveNumbers;
  bool get soundEnabled => _soundEnabled;
  bool get hapticEnabled => _hapticEnabled;

  void setBoardSize(BoardSizeOption size) {
    _boardSize = size;
    notifyListeners();
  }

  void setShowHints(bool value) {
    _showHints = value;
    notifyListeners();
  }

  void setShowMoveNumbers(bool value) {
    _showMoveNumbers = value;
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
    notifyListeners();
  }

  void setHapticEnabled(bool value) {
    _hapticEnabled = value;
    notifyListeners();
  }
}
