import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/arena_opening_matrix_report.dart '
      '<arena.json> <report.md>',
    );
    exitCode = 64;
    return;
  }

  final inputFile = File(args[0]);
  final outputFile = File(args[1]);
  final root = jsonDecode(inputFile.readAsStringSync()) as Map<String, Object?>;
  final metadata = root['metadata'] as Map<String, Object?>;
  final validation = root['validation'] as Map<String, Object?>;
  final configIds = (metadata['configs'] as List<Object?>).cast<String>();
  final openings = (metadata['openings'] as List<Object?>).cast<String>();
  final snapshots = (metadata['configSnapshots'] as List<Object?>)
      .cast<Map<String, Object?>>();
  final displayNames = {
    for (final snapshot in snapshots)
      snapshot['id'] as String: snapshot['displayName'] as String,
  };

  final stats = <String, Map<String, Map<String, _Score>>>{};
  for (final opening in openings) {
    stats[opening] = {
      for (final row in configIds)
        row: {for (final column in configIds) column: _Score()},
    };
  }

  final cells =
      (root['matrixCells'] as List<Object?>).cast<Map<String, Object?>>();
  for (final cell in cells) {
    final opening = cell['opening'] as String;
    final first = cell['firstConfigId'] as String;
    final second = cell['secondConfigId'] as String;
    final firstWins = cell['firstWins'] as int;
    final secondWins = cell['secondWins'] as int;
    final draws = cell['draws'] as int;

    stats[opening]![first]![second]!.add(
      wins: firstWins,
      losses: secondWins,
      draws: draws,
    );
    stats[opening]![second]![first]!.add(
      wins: secondWins,
      losses: firstWins,
      draws: draws,
    );
  }

  final buffer = StringBuffer()
    ..writeln('# Capture5 Phase G Ladder Arena Results')
    ..writeln()
    ..writeln('- Source JSON: `${args[0]}`')
    ..writeln('- Board: ${metadata['boardSizes']} capture-five')
    ..writeln('- Openings: ${openings.join(', ')}')
    ..writeln('- Repeat per direction: ${metadata['repeatCount']}')
    ..writeln(
        '- Cells: ${validation['cells']} / ${validation['expectedCells']}')
    ..writeln(
        '- Games: ${validation['games']} / ${validation['expectedGames']}')
    ..writeln(
        '- Scheduling: ${metadata['scheduling']} with ${metadata['workers']} workers')
    ..writeln()
    ..writeln(
      'Each matrix cell is the row config perspective as `W-L-D` over six games '
      'for that opening: both first-player directions, three repeats each.',
    )
    ..writeln()
    ..writeln('## Config IDs')
    ..writeln();

  for (final configId in configIds) {
    buffer.writeln('- ${displayNames[configId]}: `$configId`');
  }

  for (final opening in openings) {
    buffer
      ..writeln()
      ..writeln('## ${_openingTitle(opening)}')
      ..writeln()
      ..write('| Row config |');
    for (final configId in configIds) {
      buffer.write(' ${displayNames[configId]} |');
    }
    buffer
      ..writeln()
      ..write('| --- |');
    for (var i = 0; i < configIds.length; i += 1) {
      buffer.write(' ---: |');
    }
    buffer.writeln();

    for (final row in configIds) {
      buffer.write('| ${displayNames[row]} |');
      for (final column in configIds) {
        if (row == column) {
          buffer.write(' - |');
        } else {
          buffer.write(' ${stats[opening]![row]![column]} |');
        }
      }
      buffer.writeln();
    }
  }

  buffer
    ..writeln()
    ..writeln('## Validation')
    ..writeln()
    ..writeln('- Random games: ${validation['randomGames']}')
    ..writeln('- Illegal moves: ${validation['illegalMoves']}')
    ..writeln('- Timeouts: ${validation['timeouts']}')
    ..writeln('- Fallback games: ${validation['fallbackGames']}')
    ..writeln('- Failure reasons: ${validation['failureReasons']}')
    ..writeln('- Bad repeat cells: ${validation['badRepeatCells']}')
    ..writeln('- Bad dimension cells: ${validation['badDimensionCells']}');

  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(buffer.toString());
}

String _openingTitle(String opening) {
  switch (opening) {
    case 'empty':
      return 'Empty Opening';
    case 'cross':
      return 'Cross Opening';
    case 'twistCross':
      return 'Twist Cross Opening';
  }
  return opening;
}

final class _Score {
  int wins = 0;
  int losses = 0;
  int draws = 0;

  void add({required int wins, required int losses, required int draws}) {
    this.wins += wins;
    this.losses += losses;
    this.draws += draws;
  }

  @override
  String toString() => '$wins-$losses-$draws';
}
