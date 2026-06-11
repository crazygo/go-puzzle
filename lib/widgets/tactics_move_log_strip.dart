import 'package:flutter/cupertino.dart';

import '../models/board_position.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../ui/board_coordinates.dart';

class TacticsMoveLogStrip extends StatefulWidget {
  const TacticsMoveLogStrip({
    super.key,
    required this.moves,
    required this.boardSize,
    required this.coordinateSystem,
    required this.currentPlayer,
    required this.palette,
    required this.onHide,
  });

  final List<List<int>> moves;
  final int boardSize;
  final BoardCoordinateSystem coordinateSystem;
  final StoneColor currentPlayer;
  final AppThemePalette palette;
  final VoidCallback onHide;

  @override
  State<TacticsMoveLogStrip> createState() => _TacticsMoveLogStripState();
}

class _TacticsMoveLogStripState extends State<TacticsMoveLogStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant TacticsMoveLogStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moves.length > oldWidget.moves.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholderStyle = TextStyle(
      fontSize: 12,
      color:
          Color.lerp(widget.palette.heroSubtitle, CupertinoColors.black, 0.08),
      fontWeight: FontWeight.w600,
    );
    final placeholder =
        widget.currentPlayer == StoneColor.black ? '等待黑棋落子' : '等待白棋落子';

    return Container(
      width: double.infinity,
      height: 45,
      padding: const EdgeInsets.only(left: 4, right: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.palette.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: widget.onHide,
            child: const SizedBox(
              width: 28,
              height: 36,
              child: Icon(
                CupertinoIcons.eye_slash,
                size: 17,
                color: Color(0xFF9A7B5F),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.moves.isEmpty)
                    Text(placeholder, style: placeholderStyle)
                  else
                    for (var index = 0; index < widget.moves.length; index++)
                      _TacticsMoveLogChip(
                        moveNumber: index + 1,
                        coordinate: formatBoardCoordinate(
                          row: widget.moves[index][0],
                          col: widget.moves[index][1],
                          boardSize: widget.boardSize,
                          coordinateSystem: widget.coordinateSystem,
                        ),
                        stoneColor:
                            index.isEven ? StoneColor.black : StoneColor.white,
                        palette: widget.palette,
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TacticsMoveLogChip extends StatelessWidget {
  const _TacticsMoveLogChip({
    required this.moveNumber,
    required this.coordinate,
    required this.stoneColor,
    required this.palette,
  });

  final int moveNumber;
  final String coordinate;
  final StoneColor stoneColor;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final isBlack = stoneColor == StoneColor.black;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBlack
            ? CupertinoColors.black.withValues(alpha: 0.84)
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isBlack
              ? CupertinoColors.black.withValues(alpha: 0.2)
              : palette.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        '$moveNumber.$coordinate',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isBlack ? CupertinoColors.white : CupertinoColors.black,
        ),
      ),
    );
  }
}
