import 'dart:math' as math;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';

import '../models/board_position.dart';
import '../models/game_state.dart';

// Board visual constants – shared between painter and widget
const double _kBoardPadding = 0.5; // padding in cell units

/// CustomPainter that renders a Go board with stones, grid, and highlights.
class GoBoardPainter extends CustomPainter {
  final GameState gameState;
  final BoardPosition? hintPosition;
  final bool showMoveNumbers;
  final bool showCaptureWarning;

  // Stone radius / cell size ratio
  static const double _stoneSizeRatio = 0.48;

  GoBoardPainter({
    required this.gameState,
    this.hintPosition,
    this.showMoveNumbers = false,
    this.showCaptureWarning = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = gameState.boardSize;
    final cellSize = size.width / (n - 1 + 2 * _kBoardPadding);
    final origin = cellSize * _kBoardPadding;
    final boardAreaSize = cellSize * (n - 1);

    _drawBackground(canvas, size);
    _drawGrid(canvas, origin, boardAreaSize, n, cellSize);
    _drawStarPoints(canvas, origin, n, cellSize);
    _drawCoordinateLabels(canvas, size, origin, n, cellSize);
    _drawStones(canvas, origin, n, cellSize);
    _drawLastMoveMark(canvas, origin, cellSize);
    _drawHintMark(canvas, origin, cellSize);
    if (showCaptureWarning) {
      _drawAtariMarks(canvas, origin, cellSize);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final sideRadius = Radius.circular(size.shortestSide * 0.03);
    final sideRRect = RRect.fromRectAndRadius(boardRect, sideRadius);

    // Side wood base (slightly darker than top, but still wood-toned).
    canvas.drawRRect(
      sideRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0B06B), Color(0xFFC98E4F), Color(0xFF9A6530)],
        ).createShader(boardRect),
    );

    final bevel = size.shortestSide * 0.018;
    final topRect = boardRect.deflate(bevel);
    final topRRect = RRect.fromRectAndRadius(
      topRect,
      Radius.circular(size.shortestSide * 0.026),
    );

    // Top wood base.
    canvas.drawRRect(
      topRRect,
      Paint()..color = const Color(0xFFE8C98E),
    );

    // Bevel: light from upper-right, shadow toward lower-left.
    final bevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = bevel * 0.85;
    bevelPaint.color = const Color(0xFFFFEED0).withOpacity(0.45);
    canvas.drawLine(
      Offset(topRect.left, topRect.top),
      Offset(topRect.right, topRect.top),
      bevelPaint,
    );
    canvas.drawLine(
      Offset(topRect.right, topRect.top),
      Offset(topRect.right, topRect.bottom),
      bevelPaint,
    );
    bevelPaint.color = const Color(0xFF8A5B2F).withOpacity(0.35);
    canvas.drawLine(
      Offset(topRect.left, topRect.bottom),
      Offset(topRect.right, topRect.bottom),
      bevelPaint,
    );
    canvas.drawLine(
      Offset(topRect.left, topRect.top),
      Offset(topRect.left, topRect.bottom),
      bevelPaint,
    );
  }

  void _drawGrid(
    Canvas canvas,
    double origin,
    double boardAreaSize,
    int n,
    double cellSize,
  ) {
    // Outer border (engraved frame)
    final borderPaint = Paint()
      ..color = const Color(0xFF7A5C36).withOpacity(0.62)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(origin, origin, boardAreaSize, boardAreaSize),
      borderPaint,
    );

    // Interior engraved grooves.
    for (int i = 1; i < n - 1; i++) {
      final x = origin + i * cellSize;
      final y = origin + i * cellSize;
      _drawGrooveLine(
        canvas,
        Offset(x, origin),
        Offset(x, origin + boardAreaSize),
      );
      _drawGrooveLine(
        canvas,
        Offset(origin, y),
        Offset(origin + boardAreaSize, y),
      );
    }
  }

  void _drawGrooveLine(
    Canvas canvas,
    Offset a,
    Offset b,
  ) {
    final core = Paint()
      ..color = const Color(0xFF7A5C36).withOpacity(0.56)
      ..strokeWidth = 0.72
      ..style = PaintingStyle.stroke;
    canvas.drawLine(a, b, core);
  }

  void _drawStarPoints(Canvas canvas, double origin, int n, double cellSize) {
    final starPositions = _getStarPoints(n);
    final paint = Paint()
      ..color = const Color(0xFF6B4E10)
      ..style = PaintingStyle.fill;

    for (final pos in starPositions) {
      final cx = origin + pos.col * cellSize;
      final cy = origin + pos.row * cellSize;
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.1, paint);
    }
  }

  List<BoardPosition> _getStarPoints(int n) {
    if (n == 9) {
      return [
        const BoardPosition(2, 2),
        const BoardPosition(2, 6),
        const BoardPosition(4, 4),
        const BoardPosition(6, 2),
        const BoardPosition(6, 6),
      ];
    } else if (n == 13) {
      return [
        const BoardPosition(3, 3),
        const BoardPosition(3, 9),
        const BoardPosition(6, 6),
        const BoardPosition(9, 3),
        const BoardPosition(9, 9),
      ];
    } else if (n == 19) {
      return [
        const BoardPosition(3, 3),
        const BoardPosition(3, 9),
        const BoardPosition(3, 15),
        const BoardPosition(9, 3),
        const BoardPosition(9, 9),
        const BoardPosition(9, 15),
        const BoardPosition(15, 3),
        const BoardPosition(15, 9),
        const BoardPosition(15, 15),
      ];
    }
    return [];
  }

  void _drawCoordinateLabels(
    Canvas canvas,
    Size size,
    double origin,
    int n,
    double cellSize,
  ) {
    const fontSize = 9.0;
    const columns = 'ABCDEFGHJKLMNOPQRST'; // skip I
    for (int i = 0; i < n; i++) {
      final x = origin + i * cellSize;
      final y = origin + i * cellSize;

      // Column labels (top)
      _drawText(
        canvas,
        columns[i],
        Offset(x, origin - cellSize * 0.35),
        fontSize,
      );
      // Row labels (left) – numbers from bottom (Go convention)
      _drawText(
        canvas,
        '${n - i}',
        Offset(origin - cellSize * 0.35, y),
        fontSize,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF5C3A0A),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      center - Offset(tp.width / 2, tp.height / 2),
    );
  }

  void _drawStones(Canvas canvas, double origin, int n, double cellSize) {
    final stoneRadius = cellSize * _stoneSizeRatio;

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final color = gameState.board[r][c];
        if (color == StoneColor.empty) continue;

        final cx = origin + c * cellSize;
        final cy = origin + r * cellSize;
        _drawStone(canvas, Offset(cx, cy), stoneRadius, color);
      }
    }
  }

  void _drawStone(
    Canvas canvas,
    Offset center,
    double radius,
    StoneColor color,
  ) {
    final isBlack = color == StoneColor.black;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + const Offset(1.5, 1.5), radius, shadowPaint);

    // Stone base
    final basePaint = Paint()..style = PaintingStyle.fill;
    if (isBlack) {
      basePaint.shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        radius: 0.8,
        colors: [const Color(0xFF555555), const Color(0xFF111111)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      basePaint.shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        radius: 0.8,
        colors: [Colors.white, const Color(0xFFD8D8D8)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }
    canvas.drawCircle(center, radius, basePaint);

    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      center + Offset(-radius * 0.25, -radius * 0.25),
      radius * 0.4,
      highlightPaint,
    );
  }

  void _drawLastMoveMark(Canvas canvas, double origin, double cellSize) {
    final lastMove = gameState.lastMove;
    if (lastMove == null) return;

    final cx = origin + lastMove.col * cellSize;
    final cy = origin + lastMove.row * cellSize;
    final color = gameState.board[lastMove.row][lastMove.col];

    final markPaint = Paint()
      ..color = color == StoneColor.black
          ? Colors.white.withOpacity(0.8)
          : Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), cellSize * 0.12, markPaint);
  }

  void _drawHintMark(Canvas canvas, double origin, double cellSize) {
    if (hintPosition == null) return;

    final cx = origin + hintPosition!.col * cellSize;
    final cy = origin + hintPosition!.row * cellSize;

    final paint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), cellSize * 0.3, paint);

    // Pulsing ring
    final ringPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), cellSize * 0.35, ringPaint);
  }

  void _drawAtariMarks(Canvas canvas, double origin, double cellSize) {
    for (final pos in gameState.atariStones) {
      final stoneColor = gameState.board[pos.row][pos.col];
      if (stoneColor == StoneColor.empty) continue;

      final cx = origin + pos.col * cellSize;
      final cy = origin + pos.row * cellSize;

      final ringPaint = Paint()
        ..color = Colors.red.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(
          Offset(cx, cy), cellSize * _stoneSizeRatio + 1, ringPaint);
    }
  }

  @override
  bool shouldRepaint(GoBoardPainter oldDelegate) {
    return oldDelegate.gameState != gameState ||
        oldDelegate.hintPosition != hintPosition ||
        oldDelegate.showMoveNumbers != showMoveNumbers ||
        oldDelegate.showCaptureWarning != showCaptureWarning;
  }
}

/// Interactive Go board widget.
class GoBoardWidget extends StatelessWidget {
  final GameState gameState;
  final void Function(int row, int col)? onTap;
  final BoardPosition? hintPosition;
  final bool showMoveNumbers;
  final bool showCaptureWarning;
  final double? size;

  const GoBoardWidget({
    super.key,
    required this.gameState,
    this.onTap,
    this.hintPosition,
    this.showMoveNumbers = false,
    this.showCaptureWarning = true,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize =
            size ?? math.min(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: onTap == null
              ? null
              : (details) => _handleTap(details.localPosition, boardSize),
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: CustomPaint(
              painter: GoBoardPainter(
                gameState: gameState,
                hintPosition: hintPosition,
                showMoveNumbers: showMoveNumbers,
                showCaptureWarning: showCaptureWarning,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset localPosition, double boardSize) {
    final n = gameState.boardSize;
    const padding = _kBoardPadding;
    final cellSize = boardSize / (n - 1 + 2 * padding);
    final origin = cellSize * padding;

    // Find nearest intersection
    final col = ((localPosition.dx - origin) / cellSize).round();
    final row = ((localPosition.dy - origin) / cellSize).round();

    if (row >= 0 && row < n && col >= 0 && col < n) {
      onTap!(row, col);
    }
  }
}
