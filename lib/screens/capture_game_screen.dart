import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/capture_ai.dart';
import '../models/board_position.dart';
import '../models/game_state.dart';
import '../providers/capture_game_provider.dart';
import '../widgets/go_board_widget.dart';
import '../widgets/page_hero_banner.dart';

class CaptureGameScreen extends StatefulWidget {
  const CaptureGameScreen({super.key});

  @override
  State<CaptureGameScreen> createState() => _CaptureGameScreenState();
}

class _CaptureGameScreenState extends State<CaptureGameScreen> {
  static const _difficultyKey = 'capture_setup.difficulty';
  static const _boardSizeKey = 'capture_setup.board_size';
  static const _captureTarget = 5;

  DifficultyLevel _difficulty = DifficultyLevel.intermediate;
  int _boardSize = 9;

  @override
  void initState() {
    super.initState();
    _restoreSelection();
  }

  @override
  Widget build(BuildContext context) {
    final particlePreviewOnly =
        kIsWeb && Uri.base.queryParameters['particlePreview'] == '1';

    if (particlePreviewOnly) {
      return const CupertinoPageScaffold(
        backgroundColor: kPageBackgroundColor,
        child: _ParticlePreviewCanvas(),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: kPageBackgroundColor,
      child: DecoratedBox(
        decoration: kPageBackgroundDecoration,
        child: Stack(
          children: [
            // Hero as full-bleed background layer
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PageHeroBanner(
                title: _CaptureCopy.pageTitle,
                subtitle: _CaptureCopy.pageSubtitle,
              ),
            ),
            // Scrollable content floats over hero
            SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  // Transparent spacer that reveals the hero behind
                  const SliverToBoxAdapter(
                    child: SizedBox(height: kPageHeroContentOffset),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionLabel(title: '棋盘'),
                                const SizedBox(height: 4),
                                _PillSegmentControl<int>(
                                  selectedValue: _boardSize,
                                  options: const [
                                    _SegmentOption(value: 9, label: '9 路'),
                                    _SegmentOption(value: 13, label: '13 路'),
                                    _SegmentOption(value: 19, label: '19 路'),
                                  ],
                                  onChanged: (value) =>
                                      _updateSelection(boardSize: value),
                                ),
                                const SizedBox(height: 20),
                                const _SectionLabel(title: '难度'),
                                const SizedBox(height: 8),
                                _PillSegmentControl<DifficultyLevel>(
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
                                  onChanged: (value) =>
                                      _updateSelection(difficulty: value),
                                ),
                                const SizedBox(height: 20),
                                const _SectionLabel(title: 'AI 风格'),
                                const SizedBox(height: 8),
                                const _AiStyleTile(),
                                const SizedBox(height: 24),
                                _PrimaryActionButton(
                                  title: _CaptureCopy.startButton,
                                  onPressed: _startGame,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const _HomeSectionTitle(
                            title: '今日练习',
                            trailing: null,
                          ),
                          const SizedBox(height: 8),
                          _PracticeCard(
                            title: '围地上攻防练习',
                            subtitle:
                                '基础练习 · 吃$_captureTarget子 · ${_difficulty.displayName}',
                            onTap: _startGame,
                          ),
                          const SizedBox(height: 10),
                          const _HomeSectionTitle(
                            title: '最近对局',
                            trailing: '查看全部',
                          ),
                          const SizedBox(height: 10),
                          _RecentMatchCard(
                            boardSize: _boardSize,
                            difficulty: _difficulty,
                            captureTarget: _captureTarget,
                            onTap: _startGame,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedDifficulty = prefs.getString(_difficultyKey);
    final savedBoardSize = prefs.getInt(_boardSizeKey);

    setState(() {
      _difficulty = DifficultyLevel.values.firstWhere(
        (v) => v.name == savedDifficulty,
        orElse: () => _difficulty,
      );
      if (savedBoardSize == 9 || savedBoardSize == 13 || savedBoardSize == 19) {
        _boardSize = savedBoardSize!;
      }
    });
  }

  void _updateSelection({
    DifficultyLevel? difficulty,
    int? boardSize,
  }) {
    setState(() {
      _difficulty = difficulty ?? _difficulty;
      _boardSize = boardSize ?? _boardSize;
    });
    _saveSelection();
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_difficultyKey, _difficulty.name);
    await prefs.setInt(_boardSizeKey, _boardSize);
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

class _ParticlePreviewCanvas extends StatelessWidget {
  const _ParticlePreviewCanvas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: const PageHeroBanner(
          title: _CaptureCopy.pageTitle,
          subtitle: _CaptureCopy.pageSubtitle,
        ),
      ),
    );
  }
}

class _CaptureCopy {
  static const pageTitle = '小闲围棋';
  static const pageSubtitle = 'AI 陪你下好每一步';
  static const startButton = '开始对弈';
}

class _SegmentOption<T> {
  const _SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC89257), Color(0xFFA86930)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33A56730),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 14),
          borderRadius: BorderRadius.circular(16),
          onPressed: onPressed,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}





class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFDF9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x26D8C1A4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3A2A1F),
      ),
    );
  }
}

class _PillSegmentControl<T> extends StatelessWidget {
  const _PillSegmentControl({
    required this.selectedValue,
    required this.options,
    required this.onChanged,
  });

  final T selectedValue;
  final List<_SegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        options.indexWhere((option) => option.value == selectedValue);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: selectedIndex * width,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E2C9),
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        onPressed: () => onChanged(option.value),
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selectedValue == option.value
                                ? const Color(0xFF8A5A2B)
                                : const Color(0xFF5A4B3F),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AiStyleTile extends StatelessWidget {
  const _AiStyleTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33D2B28E)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF7EFE3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CustomPaint(painter: _LotusPainter()),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '均衡雅致',
                  style: TextStyle(
                    fontSize: 16.5,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF36271E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '攻守兼备，着法稳健均衡',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8A7A6B),
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '›',
            style: TextStyle(
              fontSize: 18,
              height: 1,
              color: Color(0xFFB68454),
            ),
          ),
        ],
      ),
    );
  }
}

class _LotusPainter extends CustomPainter {
  const _LotusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFFBC8448)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = const Color(0x22BC8448)
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final petal = Path()
      ..moveTo(center.dx, center.dy - 12)
      ..quadraticBezierTo(
          center.dx - 6, center.dy - 4, center.dx, center.dy + 4)
      ..quadraticBezierTo(
          center.dx + 6, center.dy - 4, center.dx, center.dy - 12);
    final left = Path()
      ..moveTo(center.dx - 10, center.dy - 6)
      ..quadraticBezierTo(
          center.dx - 16, center.dy - 1, center.dx - 10, center.dy + 4)
      ..quadraticBezierTo(
          center.dx - 4, center.dy - 1, center.dx - 10, center.dy - 6);
    final right = Path()
      ..moveTo(center.dx + 10, center.dy - 6)
      ..quadraticBezierTo(
          center.dx + 16, center.dy - 1, center.dx + 10, center.dy + 4)
      ..quadraticBezierTo(
          center.dx + 4, center.dy - 1, center.dx + 10, center.dy - 6);
    final lowerLeft = Path()
      ..moveTo(center.dx - 4, center.dy - 2)
      ..quadraticBezierTo(
          center.dx - 11, center.dy + 4, center.dx - 6, center.dy + 10)
      ..quadraticBezierTo(
          center.dx, center.dy + 5, center.dx - 4, center.dy - 2);
    final lowerRight = Path()
      ..moveTo(center.dx + 4, center.dy - 2)
      ..quadraticBezierTo(
          center.dx + 11, center.dy + 4, center.dx + 6, center.dy + 10)
      ..quadraticBezierTo(
          center.dx, center.dy + 5, center.dx + 4, center.dy - 2);
    for (final path in [petal, left, right, lowerLeft, lowerRight]) {
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
    canvas.drawLine(
      Offset(center.dx - 11, center.dy + 11),
      Offset(center.dx + 11, center.dy + 11),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({
    required this.title,
    required this.trailing,
  });

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF36271E),
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFB08965),
            ),
          ),
      ],
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF4E7D6),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.game_controller_solid,
                color: Color(0xFFB57B44),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF36271E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF897564),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Color(0xFFC09468),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentMatchCard extends StatelessWidget {
  const _RecentMatchCard({
    required this.boardSize,
    required this.difficulty,
    required this.captureTarget,
    required this.onTap,
  });

  final int boardSize;
  final DifficultyLevel difficulty;
  final int captureTarget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE8DED0), Color(0xFFC1B19C)],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.person_alt_circle_fill,
                color: CupertinoColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '山泉水长',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF36271E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$boardSize 路 · ${difficulty.displayName} · 吃$captureTarget子',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF897564),
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              '胜 62%',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9F7240),
              ),
            ),
          ],
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
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showStylePicker(context, provider),
              child: Text(
                provider.aiStyle.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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

  void _showStylePicker(BuildContext context, CaptureGameProvider provider) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('切换 AI 风格'),
        message: Text('${provider.aiStyle.label}：${provider.aiStyle.summary}'),
        actions: [
          for (final style in CaptureAiStyle.values)
            CupertinoActionSheetAction(
              onPressed: () {
                provider.setAiStyle(style);
                Navigator.of(context).pop();
              },
              child: Text(
                style == provider.aiStyle
                    ? '${style.label} · 当前'
                    : '${style.label} · ${style.summary}',
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
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
      text = 'AI 白正在思考（${provider.aiStyle.label}）';
    } else {
      text = provider.gameState.currentPlayer == StoneColor.black
          ? '请你黑落子'
          : 'AI 白准备落子（${provider.aiStyle.label}）';
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
