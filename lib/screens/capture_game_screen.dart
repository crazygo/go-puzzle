import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/board_position.dart';
import '../models/game_state.dart';
import '../providers/capture_game_provider.dart';
import '../widgets/go_board_widget.dart';

// ---------------------------------------------------------------------------
// Screen entry-point
// ---------------------------------------------------------------------------

/// Tab screen for the "capture 5 stones" (吃5子) game mode.
class CaptureGameScreen extends StatelessWidget {
  const CaptureGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CaptureGameProvider(),
      child: const _CaptureGameBody(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main body
// ---------------------------------------------------------------------------

class _CaptureGameBody extends StatefulWidget {
  const _CaptureGameBody();

  @override
  State<_CaptureGameBody> createState() => _CaptureGameBodyState();
}

class _CaptureGameBodyState extends State<_CaptureGameBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _resultCtrl;
  late Animation<double> _resultScale;

  @override
  void initState() {
    super.initState();
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _resultScale = CurvedAnimation(
      parent: _resultCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _resultCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CaptureGameProvider>(
      builder: (context, provider, _) {
        if (provider.result != CaptureGameResult.none &&
            _resultCtrl.status == AnimationStatus.dismissed) {
          _resultCtrl.forward();
        } else if (provider.result == CaptureGameResult.none &&
            _resultCtrl.status != AnimationStatus.dismissed) {
          _resultCtrl.reset();
        }

        return CupertinoPageScaffold(
          child: CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              const CupertinoSliverNavigationBar(
                largeTitle: Text('吃5子对弈'),
              ),
              SliverFillRemaining(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _DifficultySelector(provider: provider),
                      _CaptureProgressHeader(provider: provider),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _AnimatedGoBoard(
                                gameState: provider.gameState,
                                enabled: !provider.isAiThinking &&
                                    provider.result ==
                                        CaptureGameResult.none,
                                onTap: (r, c) => provider.placeStone(r, c),
                              ),
                            ),
                            if (provider.result != CaptureGameResult.none)
                              ScaleTransition(
                                scale: _resultScale,
                                child: _ResultOverlay(provider: provider),
                              ),
                          ],
                        ),
                      ),
                      _StatusBar(provider: provider),
                      _ControlBar(provider: provider),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Difficulty segmented selector
// ---------------------------------------------------------------------------

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({required this.provider});
  final CaptureGameProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            'AI难度',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoSlidingSegmentedControl<DifficultyLevel>(
              groupValue: provider.difficulty,
              children: {
                for (final level in DifficultyLevel.values)
                  level: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text(level.displayName),
                  ),
              },
              onValueChanged: (v) {
                if (v != null) provider.setDifficulty(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Capture progress header
// ---------------------------------------------------------------------------

class _CaptureProgressHeader extends StatelessWidget {
  const _CaptureProgressHeader({required this.provider});
  final CaptureGameProvider provider;

  @override
  Widget build(BuildContext context) {
    final capturedByBlack = provider.gameState.capturedByBlack.length;
    final capturedByWhite = provider.gameState.capturedByWhite.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _StoneProgressRow(
                label: '黑',
                stoneColor: CupertinoColors.black,
                captured: capturedByBlack,
                target: CaptureGameProvider.captureTarget,
                isActive: provider.gameState.currentPlayer == StoneColor.black,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'vs',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StoneProgressRow(
                label: '白',
                stoneColor: CupertinoColors.white,
                captured: capturedByWhite,
                target: CaptureGameProvider.captureTarget,
                isActive: provider.gameState.currentPlayer == StoneColor.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoneProgressRow extends StatelessWidget {
  const _StoneProgressRow({
    required this.label,
    required this.stoneColor,
    required this.captured,
    required this.target,
    required this.isActive,
  });

  final String label;
  final Color stoneColor;
  final int captured;
  final int target;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Stone icon
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stoneColor,
                border: Border.all(
                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: CupertinoColors.activeBlue.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label: $captured/$target',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? CupertinoColors.label.resolveFrom(context)
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Progress dots
        Row(
          children: List.generate(
            target,
            (i) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < captured
                      ? (stoneColor == CupertinoColors.black
                          ? const Color(0xFF222222)
                          : const Color(0xFFE8E8E8))
                      : CupertinoColors.systemGrey5.resolveFrom(context),
                  border: Border.all(
                    color: i < captured
                        ? (stoneColor == CupertinoColors.black
                            ? const Color(0xFF444444)
                            : const Color(0xFFAAAAAA))
                        : CupertinoColors.systemGrey4.resolveFrom(context),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Animated Go board with breathing atari glow
// ---------------------------------------------------------------------------

class _AnimatedGoBoard extends StatefulWidget {
  const _AnimatedGoBoard({
    required this.gameState,
    required this.enabled,
    this.onTap,
  });

  final GameState gameState;
  final bool enabled;
  final void Function(int row, int col)? onTap;

  @override
  State<_AnimatedGoBoard> createState() => _AnimatedGoBoardState();
}

class _AnimatedGoBoardState extends State<_AnimatedGoBoard>
    with SingleTickerProviderStateMixin {
  late AnimationController _atariCtrl;
  late Animation<double> _atariAnim;

  @override
  void initState() {
    super.initState();
    _atariCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _atariAnim = CurvedAnimation(
      parent: _atariCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _atariCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            math.min(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: widget.enabled && widget.onTap != null
              ? (d) => _handleTap(d.localPosition, size)
              : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                // Static board layer
                CustomPaint(
                  size: Size(size, size),
                  painter: GoBoardPainter(gameState: widget.gameState),
                ),
                // Animated atari glow overlay
                AnimatedBuilder(
                  animation: _atariAnim,
                  builder: (context, _) => CustomPaint(
                    size: Size(size, size),
                    painter: _AtariGlowPainter(
                      gameState: widget.gameState,
                      glowFactor: _atariAnim.value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset local, double boardSize) {
    const padding = 0.5; // matches _kBoardPadding in GoBoardWidget
    final n = widget.gameState.boardSize;
    final cellSize = boardSize / (n - 1 + 2 * padding);
    final origin = cellSize * padding;
    final col = ((local.dx - origin) / cellSize).round();
    final row = ((local.dy - origin) / cellSize).round();
    if (row >= 0 && row < n && col >= 0 && col < n) {
      widget.onTap!(row, col);
    }
  }
}

/// Draws a pulsing red glow over atari stones.
class _AtariGlowPainter extends CustomPainter {
  const _AtariGlowPainter({
    required this.gameState,
    required this.glowFactor,
  });

  final GameState gameState;
  final double glowFactor; // 0.0 – 1.0

  static const double _kPadding = 0.5;
  static const double _kStoneSizeRatio = 0.48;

  @override
  void paint(Canvas canvas, Size size) {
    if (gameState.atariStones.isEmpty) return;

    final n = gameState.boardSize;
    final cellSize = size.width / (n - 1 + 2 * _kPadding);
    final origin = cellSize * _kPadding;
    final stoneRadius = cellSize * _kStoneSizeRatio;

    final glowPaint = Paint()
      ..color =
          const Color(0xFFFF2222).withOpacity(0.25 + 0.45 * glowFactor)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        3.0 + 5.0 * glowFactor,
      )
      ..style = PaintingStyle.fill;

    for (final pos in gameState.atariStones) {
      if (gameState.board[pos.row][pos.col] == StoneColor.empty) continue;
      final cx = origin + pos.col * cellSize;
      final cy = origin + pos.row * cellSize;
      canvas.drawCircle(
        Offset(cx, cy),
        stoneRadius * (1.0 + 0.25 * glowFactor),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_AtariGlowPainter old) =>
      old.glowFactor != glowFactor || old.gameState != gameState;
}

// ---------------------------------------------------------------------------
// Status bar
// ---------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.provider});
  final CaptureGameProvider provider;

  @override
  Widget build(BuildContext context) {
    final Widget child;

    if (provider.isAiThinking) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(width: 8),
          const Text('AI思考中…'),
        ],
      );
    } else if (provider.result == CaptureGameResult.none) {
      final isBlackTurn =
          provider.gameState.currentPlayer == StoneColor.black;
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBlackTurn
                  ? CupertinoColors.black
                  : CupertinoColors.white,
              border: Border.all(
                color: CupertinoColors.systemGrey3.resolveFrom(context),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(isBlackTurn ? '轮到你落子（黑棋）' : '等待白棋…'),
        ],
      );
    } else {
      child = const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Padding(
        key: ValueKey(provider.isAiThinking ? 'thinking' : provider.result.name),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 14,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Control bar
// ---------------------------------------------------------------------------

class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.provider});
  final CaptureGameProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: CupertinoColors.systemGrey5.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
              onPressed: provider.canUndo ? provider.undoMove : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.arrow_uturn_left, size: 16),
                  const SizedBox(width: 6),
                  const Text('悔棋'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: CupertinoColors.activeBlue,
              borderRadius: BorderRadius.circular(10),
              onPressed: provider.newGame,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.refresh, size: 16),
                  const SizedBox(width: 6),
                  const Text('新局'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result overlay
// ---------------------------------------------------------------------------

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.provider});
  final CaptureGameProvider provider;

  @override
  Widget build(BuildContext context) {
    final isBlackWins = provider.result == CaptureGameResult.blackWins;
    final title = isBlackWins ? '🎉 你赢了！' : '😞 白棋胜';
    final subtitle = isBlackWins
        ? '你成功吃掉了5子！'
        : 'AI吃掉了5子，再接再厉！';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground
            .resolveFrom(context)
            .withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(12),
            onPressed: provider.newGame,
            child: const Text('再来一局'),
          ),
        ],
      ),
    );
  }
}
