import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:go_puzzle/screens/capture_game_screen.dart';

void main() {
  group('shared game link', () {
    test('buildSharedGameUri uses public domain for app share', () {
      final uri = buildSharedGameUri(
        '(;FF[4]GM[1]SZ[9];B[aa])',
        isWebOverride: false,
      );

      expect(uri.toString().startsWith('https://go-puzzle.vercel.app/'), isTrue);
      expect(uri.queryParameters['utm_source'], 'google_firebase');
      expect(uri.queryParameters['utm_medium'], 'app_share');
      expect(uri.queryParameters['shared_via'], 'app');
    });

    test('buildSharedGameUri uses current web domain/path for web share', () {
      final uri = buildSharedGameUri(
        '(;FF[4]GM[1]SZ[9];B[aa])',
        isWebOverride: true,
        webBaseUri: Uri.parse('https://dev.go-puzzle.local/playground?foo=bar'),
      );

      expect('${uri.scheme}://${uri.host}${uri.path}', 'https://dev.go-puzzle.local/playground');
      expect(uri.queryParameters['utm_source'], 'google_firebase');
      expect(uri.queryParameters['utm_medium'], 'web_share');
      expect(uri.queryParameters['shared_via'], 'web');
    });

    test('buildSharedGameRecordFromSgf parses setup and moves', () {
      final record = buildSharedGameRecordFromSgf(
        '(;FF[4]GM[1]SZ[9]AB[ed][ef]AW[de][fe]PL[W];W[ee];B[fd])',
        playedAt: DateTime.parse('2026-05-22T00:00:00.000Z'),
      );

      expect(record, isNotNull);
      expect(record!.boardSize, 9);
      expect(record.initialFirstPlayerIndex, StoneColor.white.index);
      expect(record.moves, const [
        [4, 4],
        [3, 5],
      ]);
      expect(record.initialBoardCells, isNotNull);
      expect(record.finalBoard, isNotNull);
      expect(record.id, '2026-05-22T00:00:00.000Z');
    });
  });
}
