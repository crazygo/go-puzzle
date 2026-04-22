import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';

import '../models/board_position.dart';
import '../models/game_state.dart';
import '../models/puzzle.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/go_board_widget.dart';

/// Full-screen puzzle playing screen.
class PuzzleScreen extends StatefulWidget {
  final Puzzle puzzle;

  const PuzzleScreen({super.key, required this.puzzle});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _resultAnimController;
  late Animation<double> _resultScaleAnim;

  @override
  void initState() {
    super.initState();
    _resultAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _resultScaleAnim = CurvedAnimation(
      parent: _resultAnimController,
      curve: Curves.elasticOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().loadPuzzle(widget.puzzle);
    });
  }

  @override
  void dispose() {
    _resultAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, _) {
        final gameState = gameProvider.gameState;
        final result = gameProvider.result;

        if (result == PuzzleResult.solved &&
            !_resultAnimController.isCompleted) {
          _resultAnimController.forward();
        }

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(widget.puzzle.title),
            trailing: _buildNavActions(context, gameProvider),
            backgroundColor: CupertinoColors.white,
            automaticBackgroundVisibility: false,
            enableBackgroundFilterBlur: false,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, gameState),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildBoardArea(context, gameProvider, gameState),
                      if (result == PuzzleResult.solved)
                        _buildSolvedOverlay(context),
                    ],
                  ),
                ),
                _buildControlBar(context, gameProvider, gameState),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavActions(BuildContext context, GameProvider gameProvider) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showPuzzleInfo(context),
      child: const Icon(CupertinoIcons.info_circle, size: 22),
    );
  }

  Widget _buildHeader(BuildContext context, GameState? gameState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.puzzle.description,
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          if (gameState != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCaptureBadge(
                  '黑棋提子: ${gameState.capturedByBlack.length}',
                  CupertinoColors.systemGrey,
                  context,
                ),
                const SizedBox(width: 8),
                _buildCaptureBadge(
                  '白棋提子: ${gameState.capturedByWhite.length}',
                  CupertinoColors.systemGrey2,
                  context,
                ),
                const Spacer(),
                _buildTurnIndicator(gameState, context),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaptureBadge(String label, Color color, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }

  Widget _buildTurnIndicator(GameState gameState, BuildContext context) {
    final isBlack = gameState.currentPlayer == StoneColor.black;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isBlack ? '黑棋行棋' : '白棋行棋',
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isBlack ? CupertinoColors.black : CupertinoColors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: CupertinoColors.systemGrey3,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoardArea(
    BuildContext context,
    GameProvider gameProvider,
    GameState? gameState,
  ) {
    if (gameState == null) {
      return const CupertinoActivityIndicator();
    }

    final settings = context.watch<SettingsProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GoBoardWidget(
        gameState: gameState,
        hintPosition: gameProvider.showingHint ? gameProvider.hintPosition : null,
        showMoveNumbers: settings.showMoveNumbers,
        onTap: gameProvider.result == PuzzleResult.none
            ? (row, col) => _handleTap(context, gameProvider, row, col)
            : null,
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    GameProvider gameProvider,
    int row,
    int col,
  ) {
    final success = gameProvider.placeStone(row, col);
    if (!success) {
      // Visual feedback for invalid move
      _showInvalidMoveFeedback(context);
    }
  }

  void _showInvalidMoveFeedback(BuildContext context) {
    // Subtle haptic feedback would go here via HapticFeedback
  }

  Widget _buildSolvedOverlay(BuildContext context) {
    return ScaleTransition(
      scale: _resultScaleAnim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGreen.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGreen.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: CupertinoColors.white,
              size: 56,
            ),
            const SizedBox(height: 12),
            const Text(
              '解题成功！',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(14),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '继续',
                style: TextStyle(
                  color: CupertinoColors.systemGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(
    BuildContext context,
    GameProvider gameProvider,
    GameState? gameState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: CupertinoIcons.arrow_counterclockwise,
            label: '悔棋',
            onPressed: gameState?.canUndo == true
                ? () => gameProvider.undoMove()
                : null,
          ),
          _ControlButton(
            icon: CupertinoIcons.lightbulb,
            label: '提示',
            onPressed: widget.puzzle.solutions.isNotEmpty &&
                    gameProvider.result == PuzzleResult.none
                ? () => gameProvider.showHint()
                : null,
            isActive: gameProvider.showingHint,
          ),
          _ControlButton(
            icon: CupertinoIcons.restart,
            label: '重置',
            onPressed: gameProvider.result != PuzzleResult.none ||
                    gameState?.history.isNotEmpty == true
                ? () => _confirmReset(context, gameProvider)
                : null,
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, GameProvider gameProvider) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('重置题目'),
        content: const Text('确定要重新开始这道题吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              gameProvider.resetPuzzle();
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  void _showPuzzleInfo(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(widget.puzzle.title),
        message: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.puzzle.description),
            const SizedBox(height: 8),
            Text(
              '分类: ${widget.puzzle.category.displayName}  难度: ${widget.puzzle.difficulty.displayName}',
              style: const TextStyle(fontSize: 13),
            ),
            if (widget.puzzle.hint != null) ...[
              const SizedBox(height: 8),
              Text('提示: ${widget.puzzle.hint}'),
            ],
          ],
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? CupertinoColors.systemGrey3
        : isActive
            ? CupertinoColors.systemGreen
            : CupertinoColors.systemBlue;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
