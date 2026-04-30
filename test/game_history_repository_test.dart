import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/models/game_record.dart';
import 'package:go_puzzle/services/game_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Creates a minimal [GameRecord] with the given [id] and [outcome].
GameRecord _makeRecord({
  required String id,
  DateTime? playedAt,
  GameOutcome outcome = GameOutcome.humanWins,
  List<List<int>> moves = const [
    [0, 0]
  ],
}) {
  final at = playedAt ?? DateTime(2024, 1, 1, 12, 0, 0);
  return GameRecord(
    id: id,
    playedAt: at,
    boardSize: 9,
    captureTarget: 5,
    difficulty: 'beginner',
    humanColorIndex: 1,
    initialMode: 'twistCross',
    moves: moves,
    outcome: outcome,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameHistoryRepository', () {
    test('loadAll returns empty list when no data stored', () async {
      final repo = GameHistoryRepository();
      final records = await repo.loadAll();
      expect(records, isEmpty);
    });

    test('save then loadAll returns the saved record', () async {
      final repo = GameHistoryRepository();
      final record = _makeRecord(id: 'r1');

      await repo.save(record);

      final loaded = await repo.loadAll();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'r1');
      expect(loaded.first.outcome, GameOutcome.humanWins);
    });

    test('loadAll returns records newest-first', () async {
      final repo = GameHistoryRepository();

      await repo.save(_makeRecord(
          id: 'old', playedAt: DateTime(2024, 1, 1)));
      await repo.save(_makeRecord(
          id: 'new', playedAt: DateTime(2024, 6, 1)));

      final loaded = await repo.loadAll();
      expect(loaded.map((r) => r.id).toList(), ['new', 'old']);
    });

    test('save replaces existing record with same id', () async {
      final repo = GameHistoryRepository();

      await repo.save(_makeRecord(id: 'dup', outcome: GameOutcome.aiWins));
      await repo.save(_makeRecord(id: 'dup', outcome: GameOutcome.humanWins));

      final loaded = await repo.loadAll();
      expect(loaded.length, 1);
      expect(loaded.first.outcome, GameOutcome.humanWins);
    });

    test('trims to maxRecords when more records are saved', () async {
      final repo = GameHistoryRepository();

      for (var i = 0; i < GameHistoryRepository.maxRecords + 5; i++) {
        await repo.save(_makeRecord(
          id: 'r$i',
          playedAt: DateTime(2024, 1, 1).add(Duration(hours: i)),
        ));
      }

      final loaded = await repo.loadAll();
      expect(loaded.length, GameHistoryRepository.maxRecords);
    });

    test('delete removes the record with the given id', () async {
      final repo = GameHistoryRepository();

      await repo.save(_makeRecord(id: 'keep'));
      await repo.save(_makeRecord(id: 'remove'));

      await repo.delete('remove');

      final loaded = await repo.loadAll();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'keep');
    });

    test('clearAll removes all records', () async {
      final repo = GameHistoryRepository();

      await repo.save(_makeRecord(id: 'a'));
      await repo.save(_makeRecord(id: 'b'));

      await repo.clearAll();

      final loaded = await repo.loadAll();
      expect(loaded, isEmpty);
    });

    test('fromJson handles double values for integer fields', () {
      // Simulates JSON decoded with num types instead of int.
      final json = {
        'id': '2024-01-01T00:00:00.000',
        'playedAt': '2024-01-01T00:00:00.000',
        'boardSize': 9.0,
        'captureTarget': 5.0,
        'difficulty': 'beginner',
        'humanColorIndex': 1.0,
        'initialMode': 'twistCross',
        'moves': [
          [0.0, 1.0]
        ],
        'outcome': 'humanWins',
        'finalBoard': null,
        'initialBoardCells': null,
      };

      expect(() => GameRecord.fromJson(json), returnsNormally);
      final record = GameRecord.fromJson(json);
      expect(record.boardSize, 9);
      expect(record.captureTarget, 5);
      expect(record.humanColorIndex, 1);
      expect(record.moves, [
        [0, 1]
      ]);
    });
  });
}
