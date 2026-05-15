enum GameMode {
  capture,
  territory,
}

extension GameModeExt on GameMode {
  String get storageKey {
    switch (this) {
      case GameMode.capture:
        return 'capture';
      case GameMode.territory:
        return 'territory';
    }
  }

  String get setupLabel {
    switch (this) {
      case GameMode.capture:
        return '吃子';
      case GameMode.territory:
        return '围空';
    }
  }

  String get historyLabel {
    switch (this) {
      case GameMode.capture:
        return '吃子';
      case GameMode.territory:
        return '围空';
    }
  }

  static GameMode fromStorageKey(String? value) {
    return switch (value) {
      'territory' => GameMode.territory,
      _ => GameMode.capture,
    };
  }
}
