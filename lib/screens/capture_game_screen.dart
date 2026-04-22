import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/board_position.dart';
import '../models/game_state.dart';
import '../providers/capture_game_provider.dart';
import '../widgets/go_board_widget.dart';

class CaptureGameScreen extends StatefulWidget {
  const CaptureGameScreen({super.key});

  @override
  State<CaptureGameScreen> createState() => _CaptureGameScreenState();
}

class _CaptureGameScreenState extends State<CaptureGameScreen> {
  DifficultyLevel _difficulty = DifficultyLevel.beginner;
  int _boardSize = 9;
  int _captureTarget = 5;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('吃5子'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SectionCard(
              title: '难度选择',
              child: CupertinoSlidingSegmentedControl<DifficultyLevel>(
                groupValue: _difficulty,
                children: {
                  for (final d in DifficultyLevel.values)
                    d: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(d.displayName),
                    ),
                },
                onValueChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
              ),
            ),
            _SectionCard(
              title: '路数',
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _boardSize,
                children: const {
                  9: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('9路'),
                  ),
                  13: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('13路'),
                  ),
                  19: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('19路'),
                  ),
                },
                onValueChanged: (v) => setState(() => _boardSize = v ?? _boardSize),
              ),
            ),
            _SectionCard(
              title: '胜利条件',
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _captureTarget,
                children: const {
                  5: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('吃5子'),
                  ),
                  10: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('吃10子'),
                  ),
                  20: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('吃20子'),
                  ),
                },
                onValueChanged: (v) => setState(() => _captureTarget = v ?? _captureTarget),
              ),
            ),
            const SizedBox(height: 18),
            CupertinoButton.filled(
              child: const Text('开始'),
              onPressed: _startGame,
            ),
          ],
        ),
      ),
    );
  }

  void _startGame() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CaptureGameProvider(
            boardSize: _boardSize,
            captureTarget: _captureTarget,
            difficulty: _difficulty,
          ),
          child: CaptureGamePlayScreen(
            difficulty: _difficulty,
            captureTarget: _captureTarget,
          ),
        ),
      ),
    );
  }
}

class CaptureGamePlayScreen extends StatelessWidget {
  const CaptureGamePlayScreen({
    super.key,
    required this.difficulty,
    required this.captureTarget,
  });

  final DifficultyLevel difficulty;
  final int captureTarget;

  @override
  Widget build(BuildContext context) {
    return Consumer<CaptureGameProvider>(
      builder: (context, provider, _) {
        final rates = provider.winRateEstimate;
        final blackRate = (rates[StoneColor.black]! * 100).toStringAsFixed(0);
        final whiteRate = (rates[StoneColor.white]! * 100).toStringAsFixed(0);

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(CupertinoIcons.back),
            ),
            middle: Text('吃$captureTarget子、${difficulty.displayName}'),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _TapBoard(
                        gameState: provider.gameState,
                        enabled: !provider.isAiThinking && provider.result == CaptureGameResult.none,
                        onTap: provider.placeStone,
                      ),
                    ),
                  ),
                ),
                _InfoRow(provider: provider),
                _MetricRow(
                  title: '吃子信息',
                  value: '黑 ${provider.gameState.capturedByBlack.length}，白 ${provider.gameState.capturedByWhite.length}',
                ),
                _MetricRow(
                  title: '胜率对比',
                  value: '黑 $blackRate%，白 $whiteRate%',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: CupertinoColors.systemGrey4,
                          onPressed: provider.canUndo ? provider.undoMove : null,
                          child: const Text('后退一手'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton.filled(
                          onPressed: () => _showHint(context, provider),
                          child: const Text('提示3手'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHint(BuildContext context, CaptureGameProvider provider) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => _HintDialog(provider: provider),
    );
  }
}

class _HintDialog extends StatefulWidget {
  const _HintDialog({required this.provider});

  final CaptureGameProvider provider;

  @override
  State<_HintDialog> createState() => _HintDialogState();
}

class _HintDialogState extends State<_HintDialog> {
  late final Future<List<BoardPosition>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.provider.suggestMovesAsync();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('提示 3 手'),
      content: FutureBuilder<List<BoardPosition>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('计算提示时出错，请重试。'),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.only(top: 12),
              child: CupertinoActivityIndicator(),
            );
          }
          final hints = snapshot.data ?? [];
          return Text(
            hints.isEmpty
                ? '暂无可用提示'
                : hints
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. (${e.value.row + 1}, ${e.value.col + 1})')
                    .join('\n'),
          );
        },
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}

class _TapBoard extends StatelessWidget {
  const _TapBoard({
    required this.gameState,
    required this.enabled,
    required this.onTap,
  });

  final GameState gameState;
  final bool enabled;
  final Future<bool> Function(int row, int col) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSizePx = constraints.biggest.shortestSide;
        return GestureDetector(
          onTapUp: enabled ? (d) => _handleTap(d.localPosition, boardSizePx) : null,
          child: CustomPaint(
            size: Size.square(boardSizePx),
            painter: GoBoardPainter(gameState: gameState),
          ),
        );
      },
    );
  }

  void _handleTap(Offset localPosition, double size) {
    const padding = 0.5;
    final n = gameState.boardSize;
    final cell = size / (n - 1 + 2 * padding);
    final origin = cell * padding;
    final col = ((localPosition.dx - origin) / cell).round();
    final row = ((localPosition.dy - origin) / cell).round();
    if (row >= 0 && row < n && col >= 0 && col < n) {
      onTap(row, col);
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.provider});

  final CaptureGameProvider provider;

  @override
  Widget build(BuildContext context) {
    String text;
    if (provider.result == CaptureGameResult.blackWins) {
      text = '对局结束：黑方胜';
    } else if (provider.result == CaptureGameResult.whiteWins) {
      text = '对局结束：白方胜';
    } else if (provider.isAiThinking) {
      text = 'AI 白正在思考';
    } else {
      text = provider.gameState.currentPlayer == StoneColor.black ? '请你黑落子' : '请你白落子';
    }

    return _MetricRow(title: '信息提示', value: text);
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$title：$value'),
      ),
    );
  }
}
