import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _difficultyKey = 'capture_setup.difficulty';
  static const _boardSizeKey = 'capture_setup.board_size';
  static const _captureTargetKey = 'capture_setup.capture_target';

  DifficultyLevel _difficulty = DifficultyLevel.intermediate;
  int _boardSize = 9;
  int _captureTarget = 5;

  @override
  void initState() {
    super.initState();
    _restoreSelection();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text(_CaptureCopy.pageTitle),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _CaptureCopy.pageSubtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GroupCard(
                    icon: CupertinoIcons.scope,
                    title: _CaptureCopy.setupTitle,
                    subtitle: _CaptureCopy.setupSubtitle,
                    child: Column(
                      children: [
                        _SegmentSettingRow<int>(
                          label: _CaptureCopy.targetLabel,
                          selectedValue: _captureTarget,
                          options: const [
                            _SegmentOption(value: 5, label: '吃5子'),
                            _SegmentOption(value: 10, label: '吃10子'),
                            _SegmentOption(value: 20, label: '吃20子'),
                          ],
                          onChanged: (v) => _updateSelection(
                            captureTarget: v,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SegmentSettingRow<int>(
                          label: _CaptureCopy.boardLabel,
                          selectedValue: _boardSize,
                          options: const [
                            _SegmentOption(value: 9, label: '9路'),
                            _SegmentOption(value: 13, label: '13路'),
                            _SegmentOption(value: 19, label: '19路'),
                          ],
                          onChanged: (v) => _updateSelection(boardSize: v),
                        ),
                        const SizedBox(height: 12),
                        _SegmentSettingRow<DifficultyLevel>(
                          label: _CaptureCopy.difficultyTitle,
                          selectedValue: _difficulty,
                          options: const [
                            _SegmentOption(
                              value: DifficultyLevel.beginner,
                              label: '初级',
                            ),
                            _SegmentOption(
                              value: DifficultyLevel.intermediate,
                              label: '中级',
                            ),
                            _SegmentOption(
                              value: DifficultyLevel.advanced,
                              label: '高级',
                            ),
                          ],
                          onChanged: (v) => _updateSelection(difficulty: v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SelectionSummaryBar(
                    text:
                        '${_difficulty.displayName} · $_boardSize路 · 吃$_captureTarget子',
                  ),
                  const SizedBox(height: 16),
                  _PrimaryActionButton(
                    title: _CaptureCopy.startButton,
                    onPressed: _startGame,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedDifficulty = prefs.getString(_difficultyKey);
    final savedBoardSize = prefs.getInt(_boardSizeKey);
    final savedCaptureTarget = prefs.getInt(_captureTargetKey);

    setState(() {
      _difficulty = DifficultyLevel.values.firstWhere(
        (v) => v.name == savedDifficulty,
        orElse: () => _difficulty,
      );
      if (savedBoardSize == 9 || savedBoardSize == 13 || savedBoardSize == 19) {
        _boardSize = savedBoardSize!;
      }
      if (savedCaptureTarget == 5 ||
          savedCaptureTarget == 10 ||
          savedCaptureTarget == 20) {
        _captureTarget = savedCaptureTarget!;
      }
    });
  }

  void _updateSelection({
    DifficultyLevel? difficulty,
    int? boardSize,
    int? captureTarget,
  }) {
    setState(() {
      _difficulty = difficulty ?? _difficulty;
      _boardSize = boardSize ?? _boardSize;
      _captureTarget = captureTarget ?? _captureTarget;
    });
    _saveSelection();
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_difficultyKey, _difficulty.name);
    await prefs.setInt(_boardSizeKey, _boardSize);
    await prefs.setInt(_captureTargetKey, _captureTarget);
  }

  void _startGame() {
    _saveSelection();
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

class _CaptureCopy {
  static const pageTitle = '吃子练习';
  static const pageSubtitle = '选择本局设置与难度，快速开始练习';
  static const setupTitle = '练习设置';
  static const setupSubtitle = '设置目标、棋盘尺寸与题目难度';
  static const targetLabel = '目标';
  static const boardLabel = '棋盘';
  static const difficultyTitle = '难度';
  static const startButton = '开始练习';
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30, color: CupertinoColors.activeBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0E1833),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF7A8192),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SegmentSettingRow<T> extends StatelessWidget {
  const _SegmentSettingRow({
    required this.label,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T selectedValue;
  final List<_SegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E1833),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SegmentControl<T>(
            selectedValue: selectedValue,
            options: options,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _SegmentControl<T> extends StatelessWidget {
  const _SegmentControl({
    required this.selectedValue,
    required this.options,
    required this.onChanged,
  });

  final T selectedValue;
  final List<_SegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E6EC)),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => onChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedValue == option.value
                        ? CupertinoColors.white
                        : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selectedValue == option.value
                          ? const Color(0xFFBBD2FF)
                          : const Color(0x00000000),
                      width: 1.5,
                    ),
                    boxShadow: selectedValue == option.value
                        ? const [
                            BoxShadow(
                              color: Color(0x120D4BD9),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: selectedValue == option.value
                          ? CupertinoColors.activeBlue
                          : const Color(0xFF5D6473),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentOption<T> {
  const _SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _SelectionSummaryBar extends StatelessWidget {
  const _SelectionSummaryBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBDAFD)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: CupertinoColors.activeBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.check_mark,
              color: CupertinoColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF232738),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2F8EFF), Color(0xFF1E6FEA)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33286DE0),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 18),
        borderRadius: BorderRadius.circular(20),
        onPressed: onPressed,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
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
            previousPageTitle: _CaptureCopy.pageTitle,
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
                        enabled: !provider.isAiThinking &&
                            provider.result == CaptureGameResult.none,
                        onTap: provider.placeStone,
                      ),
                    ),
                  ),
                ),
                _InfoRow(provider: provider),
                _MetricRow(
                  title: '吃子信息',
                  value:
                      '黑 ${provider.gameState.capturedByBlack.length}，白 ${provider.gameState.capturedByWhite.length}',
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
                          onPressed:
                              provider.canUndo ? provider.undoMove : null,
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
                    .map((e) =>
                        '${e.key + 1}. (${e.value.row + 1}, ${e.value.col + 1})')
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
          onTapUp:
              enabled ? (d) => _handleTap(d.localPosition, boardSizePx) : null,
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
      text = provider.gameState.currentPlayer == StoneColor.black
          ? '请你黑落子'
          : '请你白落子';
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
