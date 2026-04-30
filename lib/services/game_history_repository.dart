import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_record.dart';

/// Persists and retrieves the list of finished [GameRecord]s using
/// [SharedPreferences].
///
/// At most [maxRecords] recent records are kept; older ones are discarded when
/// a new record is added that would exceed the limit.
class GameHistoryRepository {
  static const String _key = 'game_history_v1';
  static const int maxRecords = 50;

  /// Returns all stored records in chronological order (oldest first).
  Future<List<GameRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => GameRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Appends [record] to the history, trimming the oldest entries when the
  /// list would exceed [maxRecords].
  Future<void> add(GameRecord record) async {
    final records = await loadAll();
    records.add(record);
    final trimmed = records.length > maxRecords
        ? records.sublist(records.length - maxRecords)
        : records;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }
}
