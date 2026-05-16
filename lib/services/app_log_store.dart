import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLogCategory {
  screenshotRecognition('screenshot_recognition', '截圖識別'),
  system('system', '系統');

  const AppLogCategory(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AppLogCategory fromStorageValue(String value) {
    return AppLogCategory.values.firstWhere(
      (category) => category.storageValue == value,
      orElse: () => AppLogCategory.system,
    );
  }
}

enum AppLogLevel {
  info('info', '資訊'),
  warning('warning', '警告'),
  error('error', '錯誤');

  const AppLogLevel(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AppLogLevel fromStorageValue(String value) {
    return AppLogLevel.values.firstWhere(
      (level) => level.storageValue == value,
      orElse: () => AppLogLevel.info,
    );
  }
}

class AppLogEntry {
  const AppLogEntry({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.level,
    required this.message,
    this.details,
  });

  final String id;
  final DateTime timestamp;
  final AppLogCategory category;
  final AppLogLevel level;
  final String message;
  final String? details;

  Map<String, Object?> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'category': category.storageValue,
        'level': level.storageValue,
        'message': message,
        'details': details,
      };

  static AppLogEntry? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final id = raw['id'];
    final timestamp = DateTime.tryParse(raw['timestamp']?.toString() ?? '');
    final category = raw['category'];
    final level = raw['level'];
    final message = raw['message'];
    if (id is! String ||
        timestamp == null ||
        category is! String ||
        level is! String ||
        message is! String) {
      return null;
    }
    return AppLogEntry(
      id: id,
      timestamp: timestamp,
      category: AppLogCategory.fromStorageValue(category),
      level: AppLogLevel.fromStorageValue(level),
      message: message,
      details: raw['details']?.toString(),
    );
  }
}

class AppLogStore extends ChangeNotifier {
  AppLogStore._();

  static final AppLogStore instance = AppLogStore._();
  static const _storageKey = 'app.logs.recent';
  static const _maxEntries = 200;

  final List<AppLogEntry> _entries = [];
  bool _restoreStarted = false;

  List<AppLogEntry> get entries => List.unmodifiable(_entries);
  AppLogEntry? get latest => _entries.isEmpty ? null : _entries.first;

  Future<void> restore() async {
    if (_restoreStarted) return;
    _restoreStarted = true;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;
    _entries
      ..clear()
      ..addAll(decoded.map(AppLogEntry.fromJson).whereType<AppLogEntry>());
    notifyListeners();
  }

  void add({
    required AppLogCategory category,
    required AppLogLevel level,
    required String message,
    String? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final detailParts = <String>[
      if (details != null && details.trim().isNotEmpty) details.trim(),
      if (error != null) 'error: $error',
      if (stackTrace != null) 'stack:\n$stackTrace',
    ];

    final now = DateTime.now();
    _entries.insert(
      0,
      AppLogEntry(
        id: now.microsecondsSinceEpoch.toString(),
        timestamp: now,
        category: category,
        level: level,
        message: message,
        details: detailParts.isEmpty ? null : detailParts.join('\n\n'),
      ),
    );
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }
}
