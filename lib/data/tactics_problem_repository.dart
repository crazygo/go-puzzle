import 'package:flutter/services.dart' show rootBundle;

import '../game/capture_ai_tactics.dart';

class TacticsProblemRepository {
  const TacticsProblemRepository();

  static const String assetPath = 'docs/ai_eval/tactics/problems.json';

  Future<List<CaptureAiTacticsProblem>> loadProblems() async {
    final source = await rootBundle.loadString(assetPath);
    return CaptureAiTacticsProblemSet.fromJsonString(source).problems;
  }
}
