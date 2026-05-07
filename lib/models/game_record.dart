import 'dart:convert';

import '../game/difficulty_level.dart';
import '../models/board_position.dart';

/// Outcome of a recorded game from the human player's perspective.
enum GameOutcome {
  /// The game was abandoned before either side won.
  abandoned,

  /// The human player won.
  humanWins,

  /// The AI (or opponent) won.
  aiWins,
}

extension GameOutcomeExt on GameOutcome {
  String get displayName {
    switch (this) {
      case GameOutcome.abandoned:
        return '未完成';
      case GameOutcome.humanWins:
        return '人类胜';
      case GameOutcome.aiWins:
        return 'AI 胜';
    }
  }
}

/// A persisted record of one completed (or abandoned) capture game.
class GameRecord {
  const GameRecord({
    required this.id,
    required this.playedAt,
    required this.boardSize,
    required this.captureTarget,
    required this.difficulty,
    required this.humanColorIndex,
    required this.initialMode,
    required this.moves,
    this.markedMoveNumbers = const [],
    required this.outcome,
    this.initialBoardCells,
    this.finalBoard,
    this.aiRank,
    this.aiStyleName,
  });

  /// ISO-8601 string used as a unique key, e.g. "2024-01-15T10:30:00.000000".
  final String id;

  /// When the game was started.
  final DateTime playedAt;

  final int boardSize;
  final int captureTarget;

  /// DifficultyLevel.name, e.g. "beginner".
  final String difficulty;

  /// StoneColor.index for the human player (1 = black, 2 = white).
  final int humanColorIndex;

  /// Stable persisted key for the opening mode, e.g. "twistCross".
  final String initialMode;

  /// Serialised initial board for setup-mode games; null otherwise.
  /// Each inner list is a row of StoneColor.index values.
  final List<List<int>>? initialBoardCells;

  /// All moves in order: each element is [row, col].
  final List<List<int>> moves;

  /// Marked move numbers (1-based) for later review.
  final List<int> markedMoveNumbers;

  /// Who won the game.
  final GameOutcome outcome;

  /// The final board state (optional), stored for quick display.
  /// Each inner list is a row of StoneColor.index values.
  final List<List<int>>? finalBoard;

  /// The AI rank (1–28) used in this game, or null for records created before
  /// the rank system was introduced.
  final int? aiRank;

  /// The [CaptureAiStyle.name] string for the AI used in this game, or null
  /// for older records.
  final String? aiStyleName;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Convenience getter: true when the human player won.
  bool get playerWon => outcome == GameOutcome.humanWins;

  DifficultyLevel get difficultyLevel =>
      DifficultyLevel.values.firstWhere((v) => v.name == difficulty,
          orElse: () => DifficultyLevel.intermediate);

  StoneColor get humanColor => humanColorIndex < StoneColor.values.length
      ? StoneColor.values[humanColorIndex]
      : StoneColor.black;

  int get totalMoves => moves.length;

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'playedAt': playedAt.toIso8601String(),
        'boardSize': boardSize,
        'captureTarget': captureTarget,
        'difficulty': difficulty,
        'humanColorIndex': humanColorIndex,
        'initialMode': initialMode,
        'initialBoardCells': initialBoardCells,
        'moves': moves,
        if (markedMoveNumbers.isNotEmpty)
          'markedMoveNumbers': markedMoveNumbers,
        'outcome': outcome.name,
        'finalBoard': finalBoard,
        if (aiRank != null) 'aiRank': aiRank,
        if (aiStyleName != null) 'aiStyleName': aiStyleName,
      };

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    List<List<int>>? parseBoard(dynamic raw) {
      if (raw == null) return null;
      return (raw as List)
          .map<List<int>>((row) =>
              (row as List).map<int>((v) => (v as num).toInt()).toList())
          .toList();
    }

    final moves = parseBoard(json['moves']) ?? const <List<int>>[];
    final markedMoveNumbers = ((json['markedMoveNumbers'] as List<dynamic>?) ??
            const <dynamic>[])
        .whereType<num>()
        .map((v) => v.toInt())
        .where((v) => v > 0 && v <= moves.length)
        .toSet()
        .toList()
      ..sort();

    return GameRecord(
      id: json['id'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      boardSize: (json['boardSize'] as num).toInt(),
      captureTarget: (json['captureTarget'] as num).toInt(),
      difficulty: json['difficulty'] as String,
      humanColorIndex: (json['humanColorIndex'] as num).toInt(),
      initialMode: json['initialMode'] as String,
      initialBoardCells: parseBoard(json['initialBoardCells']),
      moves: moves,
      markedMoveNumbers: markedMoveNumbers,
      outcome: GameOutcome.values.firstWhere(
        (v) => v.name == json['outcome'],
        orElse: () => GameOutcome.abandoned,
      ),
      finalBoard: parseBoard(json['finalBoard']),
      aiRank: (json['aiRank'] as num?)?.toInt(),
      aiStyleName: json['aiStyleName'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory GameRecord.fromJsonString(String source) =>
      GameRecord.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
