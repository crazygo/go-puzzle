import 'dart:convert' show JsonEncoder, jsonDecode;
import 'dart:io';

import 'package:go_puzzle/game/ai_arena_ladder.dart';
import 'package:go_puzzle/game/ai_arena_scheduler.dart';

class AiArenaArtifactWriter {
  AiArenaArtifactWriter({
    required this.ladderPath,
    required this.manifestPath,
    this.logPath,
  });

  final String ladderPath;
  final String manifestPath;
  final String? logPath;

  bool get writesMatchLog => logPath != null;

  File get ladderFile => File(ladderPath);
  File get manifestFile => File(manifestPath);
  File? get logFile => logPath == null ? null : File(logPath!);

  void prepare() {
    _ensureParent(ladderFile);
    _ensureParent(manifestFile);
    final file = logFile;
    if (file != null) {
      _ensureParent(file);
    }
  }

  bool get canResume =>
      writesMatchLog && manifestFile.existsSync() && logFile!.existsSync();

  AiArenaRunManifest readManifest() {
    final json =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    return AiArenaRunManifest.fromJson(json);
  }

  String readMatchLog() => logFile?.readAsStringSync() ?? '';

  void writeManifest(AiArenaRunManifest manifest) {
    manifestFile.writeAsStringSync(_prettyJson(manifest.toJson()));
  }

  void writeLatestLadder(
    AiLadderSnapshot ladder, {
    AiArenaRunManifest? manifest,
    int? completedMatches,
  }) {
    final json = <String, dynamic>{
      'schemaVersion': 1,
      if (manifest != null) ...{
        'configHash': manifest.configHash,
        'boardSize': manifest.boardSize,
        'captureTarget': manifest.captureTarget,
        'rounds': manifest.rounds,
        'promotionThreshold': manifest.promotionThreshold,
        'maxMoves': manifest.maxMoves,
        'candidateCount': manifest.candidateIds.length,
      },
      if (completedMatches != null) 'completedMatches': completedMatches,
      ...ladder.toJson(),
    };
    ladderFile.writeAsStringSync(_prettyJson(json));
  }

  void writeMatchLogLine(AiLadderEvent event, {required bool append}) {
    final file = logFile;
    if (file == null) return;

    file.writeAsStringSync(
      '${event.toJsonLine()}\n',
      mode: append ? FileMode.append : FileMode.write,
    );
  }

  void writeMatchLogLines(
    List<AiLadderEvent> events, {
    required bool append,
  }) {
    if (events.isEmpty) return;

    final file = logFile;
    if (file == null) return;

    final buffer = StringBuffer();
    for (final event in events) {
      buffer.writeln(event.toJsonLine());
    }

    file.writeAsStringSync(
      buffer.toString(),
      mode: append ? FileMode.append : FileMode.write,
    );
  }

  void clearMatchLog() {
    logFile?.writeAsStringSync('');
  }

  static void _ensureParent(File file) {
    final dir = file.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  static String _prettyJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
