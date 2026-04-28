import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_record.dart';

/// Persists and retrieves [GameRecord] objects via [SharedPreferences].
///
/// Records are stored as a JSON-encoded list of individual serialised records
/// under the key [_key].  Only the most-recent [maxRecords] entries are kept.
class GameHistoryRepository {
  static const String _key = 'game_history_v1';
  static const int maxRecords = 50;

  /// Returns all stored records sorted newest-first.
  Future<List<GameRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final records = <GameRecord>[];
    for (final s in raw) {
      try {
        records.add(GameRecord.fromJsonString(s));
      } catch (_) {
        // Skip corrupt entries silently.
      }
    }
    // Newest first.
    records.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return records;
  }

  /// Persists [record], replacing an existing entry with the same [GameRecord.id]
  /// if present.  Trims the list to [maxRecords].
  Future<void> save(GameRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];

    final decoded = <GameRecord>[];
    for (final s in raw) {
      try {
        decoded.add(GameRecord.fromJsonString(s));
      } catch (_) {}
    }

    // Replace or append.
    final idx = decoded.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      decoded[idx] = record;
    } else {
      decoded.insert(0, record);
    }

    // Newest-first, trim to cap.
    decoded.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    final trimmed = decoded.take(maxRecords).toList();

    await prefs.setStringList(
      _key,
      trimmed.map((r) => r.toJsonString()).toList(),
    );
  }

  /// Removes the record with the given [id].
  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final kept = raw.where((s) {
      try {
        return GameRecord.fromJsonString(s).id != id;
      } catch (_) {
        return false;
      }
    }).toList();
    await prefs.setStringList(_key, kept);
  }

  /// Removes all stored records.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
