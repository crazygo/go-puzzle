/// A record of a single finished capture-go game.
class GameRecord {
  const GameRecord({
    required this.timestamp,
    required this.boardSize,
    required this.captureTarget,
    required this.playerWon,
    this.aiRank,
    this.aiStyleName,
  });

  /// When the game ended.
  final DateTime timestamp;

  /// Board size used in this game (9, 13, or 19).
  final int boardSize;

  /// How many stones needed to capture to win.
  final int captureTarget;

  /// Whether the human player won.
  final bool playerWon;

  /// The AI rank (1–28) used in this game, or null for records created before
  /// the rank system was introduced.
  final int? aiRank;

  /// The [CaptureAiStyle.name] string for the AI used in this game, or null
  /// for older records.
  final String? aiStyleName;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.millisecondsSinceEpoch,
        'boardSize': boardSize,
        'captureTarget': captureTarget,
        'playerWon': playerWon,
        if (aiRank != null) 'aiRank': aiRank,
        if (aiStyleName != null) 'aiStyleName': aiStyleName,
      };

  factory GameRecord.fromJson(Map<String, dynamic> json) => GameRecord(
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] as int,
        ),
        boardSize: json['boardSize'] as int,
        captureTarget: json['captureTarget'] as int,
        playerWon: json['playerWon'] as bool,
        aiRank: json['aiRank'] as int?,
        aiStyleName: json['aiStyleName'] as String?,
      );
}
