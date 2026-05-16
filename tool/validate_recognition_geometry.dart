import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

Future<void> main() async {
  final dir = Directory('test/assets/recognition_samples');
  final txtFiles = dir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final failures = <String>[];
  var totalStones = 0;

  for (final txtFile in txtFiles) {
    final sampleId = txtFile.uri.pathSegments.last.replaceAll('.txt', '');
    final sampleFailures = <String>[];
    final txtTruth = await _loadTxtTruth(txtFile);
    final jsonFile = File('${dir.path}/$sampleId.json');
    final imageFile = _findImageFile(dir, sampleId);

    if (!await jsonFile.exists()) {
      failures.add('$sampleId: missing json');
      continue;
    }
    if (imageFile == null) {
      failures.add('$sampleId: missing image');
      continue;
    }

    final decoded = img.decodeImage(Uint8List.fromList(
      await imageFile.readAsBytes(),
    ));
    if (decoded == null) {
      failures.add('$sampleId: image decode failed');
      continue;
    }

    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
    } catch (error) {
      failures.add('$sampleId: json parse failed: $error');
      continue;
    }

    final boardSize = json['boardSize'];
    if (boardSize != txtTruth.boardSize) {
      sampleFailures.add(
        'boardSize json=$boardSize txt=${txtTruth.boardSize}',
      );
    }

    final image = json['image'];
    if (image is! Map) {
      sampleFailures.add('missing image object');
    } else {
      if (image['width'] != decoded.width ||
          image['height'] != decoded.height) {
        sampleFailures.add(
          'image size json=${image['width']}x${image['height']} '
          'actual=${decoded.width}x${decoded.height}',
        );
      }
      final fileName = image['fileName'];
      if (fileName is String && fileName.isNotEmpty) {
        if (fileName.toLowerCase() !=
            imageFile.uri.pathSegments.last.toLowerCase()) {
          sampleFailures.add(
            'image fileName json=$fileName actual=${imageFile.uri.pathSegments.last}',
          );
        }
      }
    }

    final corners = json['corners'];
    if (corners is! Map) {
      sampleFailures.add('missing corners object');
    } else {
      final parsedCorners = <String, _Point>{};
      for (final name in [
        'topLeft',
        'topRight',
        'bottomRight',
        'bottomLeft',
      ]) {
        final point = _parsePoint(corners[name]);
        if (point == null) {
          sampleFailures.add('missing/invalid corner $name');
          continue;
        }
        parsedCorners[name] = point;
        if (point.x < 0 ||
            point.x > decoded.width ||
            point.y < 0 ||
            point.y > decoded.height) {
          sampleFailures.add(
            'corner $name out of bounds (${point.x}, ${point.y})',
          );
        }
      }
      if (parsedCorners.length == 4) {
        final topWidth =
            parsedCorners['topLeft']!.distanceTo(parsedCorners['topRight']!);
        final bottomWidth = parsedCorners['bottomLeft']!
            .distanceTo(parsedCorners['bottomRight']!);
        final leftHeight =
            parsedCorners['topLeft']!.distanceTo(parsedCorners['bottomLeft']!);
        final rightHeight = parsedCorners['topRight']!
            .distanceTo(parsedCorners['bottomRight']!);
        final minSide = [topWidth, bottomWidth, leftHeight, rightHeight]
            .reduce((a, b) => a < b ? a : b);
        if (minSide < 80) {
          sampleFailures.add('corners form a very small board');
        }
      }
    }

    final jsonStones = _parseJsonStones(json['stones'], sampleFailures);
    if (!_sameStoneSet(jsonStones, txtTruth.stones)) {
      final missing =
          txtTruth.stones.difference(jsonStones).take(12).join(', ');
      final extra = jsonStones.difference(txtTruth.stones).take(12).join(', ');
      sampleFailures.add(
        'stones mismatch missing=[$missing] extra=[$extra]',
      );
    }

    totalStones += txtTruth.stones.length;
    if (sampleFailures.isEmpty) {
      print(
        '$sampleId: ok size=${txtTruth.boardSize} stones=${txtTruth.stones.length}',
      );
    } else {
      failures.addAll(sampleFailures.map((failure) => '$sampleId: $failure'));
      print('$sampleId: failed');
      for (final failure in sampleFailures) {
        print('  $failure');
      }
    }
  }

  print('');
  print('validated samples: ${txtFiles.length}');
  print('validated stones: $totalStones');
  print('failures: ${failures.length}');
  if (failures.isNotEmpty) {
    print('');
    for (final failure in failures) {
      print(failure);
    }
    exitCode = 1;
  }
}

File? _findImageFile(Directory dir, String sampleId) {
  for (final extension in ['png', 'PNG', 'jpg', 'JPG', 'jpeg', 'JPEG']) {
    final file = File('${dir.path}/$sampleId.$extension');
    if (file.existsSync()) return file;
  }
  return null;
}

Future<_TxtTruth> _loadTxtTruth(File file) async {
  final lines = await file.readAsLines();
  final boardSize = int.parse(lines.first.split(RegExp(r'\s+')).last);
  final stones = <String>{};
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final parts = line.split(',');
    if (parts.length != 2) continue;
    stones.add('${parts[0]},${parts[1]}');
  }
  return _TxtTruth(boardSize: boardSize, stones: stones);
}

Set<String> _parseJsonStones(Object? value, List<String> failures) {
  if (value is! List) {
    failures.add('missing stones list');
    return const {};
  }
  final stones = <String>{};
  for (var i = 0; i < value.length; i++) {
    final raw = value[i];
    if (raw is! Map) {
      failures.add('stone[$i] is not an object');
      continue;
    }
    final color = raw['color'];
    final coord = raw['coord'];
    if (color != 'B' && color != 'W') {
      failures.add('stone[$i] invalid color=$color');
      continue;
    }
    if (coord is! String || coord.isEmpty) {
      failures.add('stone[$i] invalid coord=$coord');
      continue;
    }
    stones.add('$color,$coord');
  }
  return stones;
}

bool _sameStoneSet(Set<String> a, Set<String> b) {
  return a.length == b.length && a.containsAll(b);
}

_Point? _parsePoint(Object? value) {
  if (value is! Map) return null;
  final x = value['x'];
  final y = value['y'];
  if (x is! num || y is! num) return null;
  return _Point(x.toDouble(), y.toDouble());
}

class _TxtTruth {
  const _TxtTruth({required this.boardSize, required this.stones});
  final int boardSize;
  final Set<String> stones;
}

class _Point {
  const _Point(this.x, this.y);
  final double x;
  final double y;

  double distanceTo(_Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
