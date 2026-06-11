import '../models/board_position.dart';
import 'capture_ai.dart';

/// UI-facing tactics advice payload decoded from [runTacticsAdvice].
class TacticsAdviceSnapshot {
  const TacticsAdviceSnapshot({
    required this.aiSuggestions,
    required this.oracleAuthoritative,
    required this.oracleRankedMoves,
  });

  final List<TacticsAiSuggestionSnapshot> aiSuggestions;
  final bool oracleAuthoritative;
  final List<TacticsOracleMoveSnapshot> oracleRankedMoves;

  BoardPosition? get primaryMove {
    for (final suggestion in aiSuggestions) {
      if (suggestion.style == CaptureAiStyle.hunter &&
          suggestion.move != null) {
        return suggestion.move;
      }
    }
    return aiSuggestions.isEmpty ? null : aiSuggestions.first.move;
  }

  factory TacticsAdviceSnapshot.fromMap(Map<String, dynamic> map) {
    final rawSuggestions = map['aiSuggestions'] as List<dynamic>? ?? const [];
    final rawOracleMoves =
        map['oracleRankedMoves'] as List<dynamic>? ?? const [];
    return TacticsAdviceSnapshot(
      aiSuggestions: [
        for (final entry in rawSuggestions)
          TacticsAiSuggestionSnapshot.fromMap(
            Map<String, dynamic>.from(entry as Map),
          ),
      ],
      oracleAuthoritative: map['oracleAuthoritative'] as bool? ?? false,
      oracleRankedMoves: [
        for (final entry in rawOracleMoves)
          TacticsOracleMoveSnapshot.fromMap(
            Map<String, dynamic>.from(entry as Map),
          ),
      ],
    );
  }
}

class TacticsAiSuggestionSnapshot {
  const TacticsAiSuggestionSnapshot({
    required this.style,
    required this.move,
    required this.score,
  });

  final CaptureAiStyle style;
  final BoardPosition? move;
  final double? score;

  factory TacticsAiSuggestionSnapshot.fromMap(Map<String, dynamic> map) {
    final row = map['row'];
    final col = map['col'];
    return TacticsAiSuggestionSnapshot(
      style: CaptureAiStyle.values.byName(map['style'] as String),
      move: row is int && col is int ? BoardPosition(row, col) : null,
      score: (map['score'] as num?)?.toDouble(),
    );
  }
}

class TacticsOracleMoveSnapshot {
  const TacticsOracleMoveSnapshot({
    required this.position,
    required this.score,
  });

  final BoardPosition position;
  final double score;

  factory TacticsOracleMoveSnapshot.fromMap(Map<String, dynamic> map) {
    return TacticsOracleMoveSnapshot(
      position: BoardPosition(map['row'] as int, map['col'] as int),
      score: (map['score'] as num).toDouble(),
    );
  }
}
