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
  static const _initialModeKey = 'capture_setup.initial_mode';
  static const _captureTarget = 5;

  DifficultyLevel _difficulty = DifficultyLevel.intermediate;
  int _boardSize = 9;
  CaptureInitialMode _initialMode = CaptureInitialMode.twistCross;

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
                                const _SectionLabel(title: '初始'),
                                const SizedBox(height: 8),
                                _PillSegmentControl<CaptureInitialMode>(
                                  selectedValue: _initialMode,
                                  options: const [
                                    _SegmentOption(
                                      value: CaptureInitialMode.twistCross,
                                      label: '扭十字',
                                    ),
                                    _SegmentOption(
                                      value: CaptureInitialMode.empty,
                                      label: '空白',
                                    ),
                                    _SegmentOption(
                                      value: CaptureInitialMode.setup,
                                      label: '摆棋',
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      _updateSelection(initialMode: value),
                                ),
                                const SizedBox(height: 20),
                                const _SectionLabel(title: 'AI 风格'),
                                const SizedBox(height: 8),
                                const _AiStyleTile(),
                                const SizedBox(height: 24),
                                if (_initialMode ==
                                    CaptureInitialMode.setup) ...[
                                  _PrimaryActionButton(
                                    title: _CaptureCopy.startSetupButton,
                                    onPressed: () => _startGame(
                                        humanColor: StoneColor.black),
                                  ),
                                ] else ...[
                                  _PrimaryActionButton(
                                    title: _CaptureCopy.startAsBlackButton,
                                    onPressed: () => _startGame(
                                        humanColor: StoneColor.black),
                                  ),
                                  const SizedBox(height: 10),
                                  _SecondaryActionButton(
                                    title: _CaptureCopy.startAsWhiteButton,
                                    onPressed: () => _startGame(
                                        humanColor: StoneColor.white),
                                  ),
                                ],
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
                            onTap: () =>
                                _startGame(humanColor: StoneColor.black),
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
                            onTap: () =>
                                _startGame(humanColor: StoneColor.black),
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
    final savedInitialMode = prefs.getString(_initialModeKey);

    setState(() {
      _difficulty = DifficultyLevel.values.firstWhere(
        (v) => v.name == savedDifficulty,
        orElse: () => _difficulty,
      );
      _initialMode = CaptureInitialMode.values.firstWhere(
        (v) => v.name == savedInitialMode,
        orElse: () => _initialMode,
      );
      if (savedBoardSize == 9 || savedBoardSize == 13 || savedBoardSize == 19) {
        _boardSize = savedBoardSize!;
      }
    });
  }

  void _updateSelection({
    DifficultyLevel? difficulty,
    int? boardSize,
    CaptureInitialMode? initialMode,
  }) {
    setState(() {
      _difficulty = difficulty ?? _difficulty;
      _boardSize = boardSize ?? _boardSize;
      _initialMode = initialMode ?? _initialMode;
    });
    _saveSelection();
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_difficultyKey, _difficulty.name);
    await prefs.setInt(_boardSizeKey, _boardSize);
    await prefs.setString(_initialModeKey, _initialMode.name);
  }

  void _startGame({required StoneColor humanColor}) {
    _saveSelection();
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CaptureGameProvider(
            boardSize: _boardSize,
            captureTarget: _captureTarget,
            difficulty: _difficulty,
            humanColor: humanColor,
            initialMode: _initialMode,
          ),
          child: CaptureGamePlayScreen(
            difficulty: _difficulty,
            captureTarget: _captureTarget,
            humanColor: humanColor,
            initialMode: _initialMode,
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
  static const startAsBlackButton = '执黑先行';
  static const startAsWhiteButton = '执白后行';
  static const startSetupButton = '开始';
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

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x14A86930),
        onPressed: onPressed,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF915C2F),
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

class CaptureGamePlayScreen extends StatefulWidget {
  const CaptureGamePlayScreen({
    super.key,
    required this.difficulty,
    required this.captureTarget,
    this.humanColor = StoneColor.black,
    this.initialMode = CaptureInitialMode.twistCross,
  });

  final DifficultyLevel difficulty;
  final int captureTarget;
  final StoneColor humanColor;
  final CaptureInitialMode initialMode;

  @override
  State<CaptureGamePlayScreen> createState() => _CaptureGamePlayScreenState();
}

class _CaptureGamePlayScreenState extends State<CaptureGamePlayScreen> {
  List<_HintMark> _hintMarks = const [];
  bool _isLoadingHints = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CaptureGameProvider>(
      builder: (context, provider, _) {
        final rates = provider.winRateEstimate;
        final blackRate = (rates[StoneColor.black]! * 100).toStringAsFixed(0);
        final whiteRate = (rates[StoneColor.white]! * 100).toStringAsFixed(0);
        final blackCaptured = provider.gameState.capturedByBlack.length;
        final whiteCaptured = provider.gameState.capturedByWhite.length;
        final aiThinking = provider.isAiThinking;
        final isFinished = provider.result != CaptureGameResult.none;

        return CupertinoPageScaffold(
          backgroundColor: const Color(0xFFF3F0ED),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: const Color(0xFFF3F0ED),
            border: null,
            previousPageTitle: _CaptureCopy.pageTitle,
            middle: Text(
              '${_modeLabel(widget.initialMode)} · 吃${widget.captureTarget}子 · ${widget.difficulty.displayName}',
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showStylePicker(context, provider),
              child: Text(
                provider.aiStyle.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFC3996E),
                ),
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _PlayerSummaryRow(
                    captureTarget: widget.captureTarget,
                    blackCaptured: blackCaptured,
                    whiteCaptured: whiteCaptured,
                    result: provider.result,
                    currentPlayer: provider.gameState.currentPlayer,
                    isSetupMode: provider.isPlacementMode,
                    humanColor: widget.humanColor,
                    isAiThinking: aiThinking,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0DFC9),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _TapBoard(
                            gameState: provider.gameState,
                            enabled: !aiThinking && !isFinished,
                            hintMarks: _hintMarks,
                            onTap: (row, col) => _handleBoardTap(
                              provider: provider,
                              row: row,
                              col: col,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _BottomInfoCard(
                    infoText: _buildInfoText(provider, widget.humanColor),
                    blackRate: blackRate,
                    whiteRate: whiteRate,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DecoratedActionButton(
                          text: '后退一手',
                          filled: false,
                          onPressed:
                              provider.canUndo ? provider.undoMove : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DecoratedActionButton(
                          text: '提示一手',
                          filled: true,
                          onPressed: _isLoadingHints
                              ? null
                              : () => _showHintsOnBoard(provider),
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

  String _buildInfoText(CaptureGameProvider provider, StoneColor humanColor) {
    if (provider.result == CaptureGameResult.blackWins) return '对局结束：人类胜';
    if (provider.result == CaptureGameResult.whiteWins) return '对局结束：AI 胜';
    if (provider.isPlacementMode) return '摆棋模式：始终由你摆子，系统按黑白轮流切换。';
    if (provider.isAiThinking) return 'AI 正在思考（${provider.aiStyle.label}）';
    final playerName = humanColor == StoneColor.black ? '黑棋' : '白棋';
    final aiName = humanColor == StoneColor.black ? '白棋' : '黑棋';
    if (provider.gameState.currentPlayer != humanColor) {
      return '轮到 AI 落子（$aiName）';
    }
    return '轮到你落子（$playerName）';
  }

  String _modeLabel(CaptureInitialMode mode) {
    return switch (mode) {
      CaptureInitialMode.twistCross => '扭十字',
      CaptureInitialMode.empty => '空白',
      CaptureInitialMode.setup => '摆棋',
    };
  }

  Future<bool> _handleBoardTap({
    required CaptureGameProvider provider,
    required int row,
    required int col,
  }) async {
    final placed = await provider.placeStone(row, col);
    if (placed && mounted) {
      setState(() {
        _hintMarks = const [];
      });
    }
    return placed;
  }

  Future<void> _showHintsOnBoard(CaptureGameProvider provider) async {
    setState(() {
      _isLoadingHints = true;
    });
    try {
      final hints = await provider.suggestMovesAsync(count: 1);
      if (!mounted) return;
      final firstColor = provider.gameState.currentPlayer;
      setState(() {
        _hintMarks = hints
            .map((pos) => _HintMark(position: pos, color: firstColor))
            .toList();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHints = false;
        });
      }
    }
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

class _PlayerSummaryRow extends StatelessWidget {
  const _PlayerSummaryRow({
    required this.captureTarget,
    required this.blackCaptured,
    required this.whiteCaptured,
    required this.result,
    required this.currentPlayer,
    required this.isSetupMode,
    required this.humanColor,
    required this.isAiThinking,
  });

  final int captureTarget;
  final int blackCaptured;
  final int whiteCaptured;
  final CaptureGameResult result;
  final StoneColor currentPlayer;
  final bool isSetupMode;
  final StoneColor humanColor;
  final bool isAiThinking;

  @override
  Widget build(BuildContext context) {
    String? blackTag;
    String? whiteTag;

    if (result == CaptureGameResult.none) {
      if (currentPlayer == StoneColor.black) {
        if (isSetupMode || humanColor == StoneColor.black) {
          blackTag = '请落子';
        } else if (isAiThinking) {
          blackTag = 'AI 在思考';
        }
      } else if (currentPlayer == StoneColor.white) {
        if (isSetupMode || humanColor == StoneColor.white) {
          whiteTag = '请落子';
        } else if (isAiThinking) {
          whiteTag = 'AI 在思考';
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: _PlayerSideCard(
            title: '黑棋',
            isBlack: true,
            tag: blackTag,
            progress: blackCaptured,
            captureTarget: captureTarget,
            alignEnd: false,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _PlayerSideCard(
            title: '白棋',
            isBlack: false,
            tag: whiteTag,
            progress: whiteCaptured,
            captureTarget: captureTarget,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _PlayerSideCard extends StatelessWidget {
  const _PlayerSideCard({
    required this.title,
    required this.isBlack,
    this.tag,
    required this.progress,
    required this.captureTarget,
    required this.alignEnd,
  });

  final String title;
  final bool isBlack;
  final String? tag;
  final int progress;
  final int captureTarget;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final active = progress.clamp(0, captureTarget);
    final alignment =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF2E2620),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEADCCB),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  tag!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E7157),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(captureTarget, (index) {
            final isActive = index < active;
            return Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? (isBlack
                        ? const Color(0xFF1F1F1F)
                        : const Color(0xFFEFF1F3))
                    : const Color(0xFFE8D6C5),
                border: Border.all(color: const Color(0xFFD5BEA6), width: 0.6),
                boxShadow: isActive
                    ? const [
                        BoxShadow(
                          color: Color(0x20000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BottomInfoCard extends StatelessWidget {
  const _BottomInfoCard({
    required this.infoText,
    required this.blackRate,
    required this.whiteRate,
  });

  final String infoText;
  final String blackRate;
  final String whiteRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8C3AE), width: 0.8),
      ),
      child: Text(
        '$infoText  ·  胜率 人类$blackRate% / AI$whiteRate%',
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF6F5743),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DecoratedActionButton extends StatelessWidget {
  const _DecoratedActionButton({
    required this.text,
    required this.filled,
    required this.onPressed,
  });

  final String text;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final background =
        filled ? const Color(0xFFC28A56) : const Color(0xFFF2EBE3);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 15),
      color: disabled ? const Color(0xFFDCD4CC) : background,
      borderRadius: BorderRadius.circular(18),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: filled ? CupertinoColors.white : const Color(0xFF8F7359),
        ),
      ),
    );
  }
}

class _HintMark {
  const _HintMark({
    required this.position,
    required this.color,
  });

  final BoardPosition position;
  final StoneColor color;
}

class _HintOverlayPainter extends CustomPainter {
  const _HintOverlayPainter({
    required this.boardSize,
    required this.hints,
  });

  final int boardSize;
  final List<_HintMark> hints;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 0.5;
    final cell = size.width / (boardSize - 1 + 2 * padding);
    final origin = cell * padding;
    final radius = cell * 0.34;

    for (final hint in hints) {
      final center = Offset(
        origin + hint.position.col * cell,
        origin + hint.position.row * cell,
      );
      final hintColor = hint.color == StoneColor.black
          ? const Color(0xE0000000)
          : const Color(0xE0FFFFFF);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = hintColor;
      _drawDashedCircle(canvas, center, radius, paint);
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const dashCount = 18;
    const gapRatio = 0.45;
    final step = (2 * 3.141592653589793) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      final start = i * step;
      final sweep = step * gapRatio;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HintOverlayPainter oldDelegate) {
    return oldDelegate.boardSize != boardSize || oldDelegate.hints != hints;
  }
}

class _TapBoard extends StatelessWidget {
  const _TapBoard({
    required this.gameState,
    required this.enabled,
    required this.hintMarks,
    required this.onTap,
  });

  final GameState gameState;
  final bool enabled;
  final List<_HintMark> hintMarks;
  final Future<bool> Function(int row, int col) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSizePx = constraints.biggest.shortestSide;
        return GestureDetector(
          onTapUp:
              enabled ? (d) => _handleTap(d.localPosition, boardSizePx) : null,
          child: SizedBox(
            width: boardSizePx,
            height: boardSizePx,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: GoBoardPainter(gameState: gameState),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _HintOverlayPainter(
                      boardSize: gameState.boardSize,
                      hints: hintMarks,
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
