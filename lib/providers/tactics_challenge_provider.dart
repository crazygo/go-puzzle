import 'package:flutter/foundation.dart';
import '../data/tactics_problem_repository.dart';
import '../game/capture_ai_tactics.dart';

enum TacticsTypeFilter {
  all,
  capture,
  lifeDeath,
  tesuji,
  race;

  String get label => switch (this) {
        all => '全部',
        capture => '吃子',
        lifeDeath => '死活',
        tesuji => '手筋',
        race => '對殺',
      };

  String get screenTitle => switch (this) {
        all => '全部題目',
        capture => '吃子題',
        lifeDeath => '死活題',
        tesuji => '手筋題',
        race => '對殺題',
      };

  List<CaptureAiTacticsProblem> filter(
    List<CaptureAiTacticsProblem> problems,
  ) {
    return switch (this) {
      all => problems,
      capture => problems
          .where((p) =>
              ['trap', 'exchange', 'multi_threat'].contains(p.category))
          .toList(),
      lifeDeath =>
        problems.where((p) => p.category == 'group_fate').toList(),
      tesuji => problems.where((p) {
          final tactic = p.metadata['tactic']?.toString() ?? '';
          return const [
            'throw_in',
            'snapback',
            'shortage_of_liberties',
            'net_geta',
            'ladder',
          ].contains(tactic);
        }).toList(),
      race =>
        problems.where((p) => p.category == 'capture_race').toList(),
    };
  }
}

class TacticsChallengeProvider extends ChangeNotifier {
  late final Future<List<CaptureAiTacticsProblem>> problemsFuture;
  List<CaptureAiTacticsProblem>? _allProblems;
  List<CaptureAiTacticsProblem>? _todayProblems;
  Object? _loadError;
  int _kLevel = 15;
  TacticsTypeFilter _typeFilter = TacticsTypeFilter.all;
  bool _isAdjusting = false;
  final Map<DateTime, List<CaptureAiTacticsProblem>> _solvedByDay = {};

  TacticsChallengeProvider({Future<List<CaptureAiTacticsProblem>>? problemsFutureOverride}) {
    problemsFuture = problemsFutureOverride ?? const TacticsProblemRepository().loadProblems();
    problemsFuture.then((value) {
      _allProblems = value;
      _selectTodayProblems();
      notifyListeners();
    }).catchError((error) {
      _loadError = error;
      notifyListeners();
    });
  }

  List<CaptureAiTacticsProblem>? get allProblems => _allProblems;
  Object? get loadError => _loadError;
  List<CaptureAiTacticsProblem>? get todayProblems => _todayProblems;
  int get kLevel => _kLevel;
  TacticsTypeFilter get typeFilter => _typeFilter;
  bool get isAdjusting => _isAdjusting;
  Map<DateTime, List<CaptureAiTacticsProblem>> get solvedByDay => _solvedByDay;

  void setKLevel(int k) {
    if (_kLevel == k) return;
    _kLevel = k;
    _todayProblems = null;
    _selectTodayProblems();
    notifyListeners();
  }

  void setTypeFilter(TacticsTypeFilter t) {
    if (_typeFilter == t) return;
    _typeFilter = t;
    _todayProblems = null;
    _selectTodayProblems();
    notifyListeners();
  }

  void toggleAdjust() {
    _isAdjusting = !_isAdjusting;
    notifyListeners();
  }

  void recordSolved(CaptureAiTacticsProblem problem) {
    final day = DateTime.now();
    final dateKey = DateTime(day.year, day.month, day.day);
    final list = _solvedByDay.putIfAbsent(dateKey, () => []);
    if (!list.any((p) => p.id == problem.id)) {
      list.add(problem);
      notifyListeners();
    }
  }

  void _selectTodayProblems() {
    final pool = _allProblems;
    if (pool == null) return;
    final filtered = _typeFilter.filter(pool);
    _todayProblems = filtered.take(5).toList();
  }
}
