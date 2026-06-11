import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:provider/provider.dart';

import '../game/ai_search_entry.dart';
import '../game/capture_ai.dart';
import '../game/capture_ai_tactics.dart';
import '../game/difficulty_level.dart';
import '../game/game_mode.dart';
import '../game/mcts_engine.dart';
import '../game/tactics_advice_runner.dart';
import '../game/tactics_advice_snapshot.dart';
import '../game/illegal_move_reason.dart';
import '../models/board_position.dart';
import '../models/game_state.dart';
import '../providers/settings_provider.dart';
import '../theme/theme_context.dart';
import '../ui/app_toast.dart';
import '../ui/tactics_labels.dart';
import '../widgets/go_board_widget.dart';
import '../widgets/operation_context_menu.dart';
import '../widgets/tactics_move_log_strip.dart';

class TacticsProblemScreen extends StatefulWidget {
  const TacticsProblemScreen({
    super.key,
    required this.problems,
    this.dailyChallengeMode = false,
    this.onProblemPassed,
    this.adviceRunner,
  });

  final List<CaptureAiTacticsProblem> problems;
  final bool dailyChallengeMode;
  final void Function(CaptureAiTacticsProblem problem)? onProblemPassed;
  final TacticsAdviceRunner? adviceRunner;

  @override
  State<TacticsProblemScreen> createState() => _TacticsProblemScreenState();
}

class _TacticsProblemScreenState extends State<TacticsProblemScreen> {
  late List<CaptureAiTacticsProblem> _queue;
  late SimBoard _board;
  late int _humanSimPlayer;

  TacticsAdviceRunner? _adviceRunner;
  TacticsAdviceSnapshot? _advice;
  Object? _adviceError;

  final List<List<int>> _moves = [];
  bool _aiOpponentEnabled = true;
  bool _moveLogVisible = true;
  bool _showMoveNumbers = false;
  BoardPosition? _hintPosition;
  bool _passed = false;
  bool _aiThinking = false;
  bool _loadingAdvice = false;

  CaptureAiTacticsProblem get _problem => _queue.first;

  @override
  void initState() {
    super.initState();
    _queue = List<CaptureAiTacticsProblem>.from(widget.problems);
    _adviceRunner = widget.adviceRunner ?? createTacticsAdviceRunner();
    _resetBoardState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdvice());
  }

  @override
  void dispose() {
    if (widget.adviceRunner == null) {
      _adviceRunner?.dispose();
    }
    super.dispose();
  }

  void _resetBoardState() {
    _board = _problem.toBoard();
    _humanSimPlayer = _problem.currentPlayer;
    _moves.clear();
    _passed = false;
    _aiThinking = false;
    _hintPosition = null;
  }

  Future<void> _loadAdvice() async {
    if (_loadingAdvice) return;
    setState(() => _loadingAdvice = true);
    final result = await _adviceRunner!.buildAdvice(_problem);
    if (!mounted) return;
    setState(() {
      _loadingAdvice = false;
      if (result.hasError || result.advice == null) {
        _adviceError = result.error ?? StateError('Missing tactics advice');
        _advice = null;
      } else {
        _adviceError = null;
        _advice = result.advice;
      }
    });
  }

  StoneColor get _currentStoneColor => _board.currentPlayer == SimBoard.black
      ? StoneColor.black
      : StoneColor.white;

  bool get _canSkip =>
      widget.dailyChallengeMode && !_passed && _queue.length > 1;

  String get _primaryButtonLabel {
    if (_passed) {
      return _queue.length <= 1 ? '全部完成 🎉' : '下一題';
    }
    return '跳過';
  }

  Future<void> _playAiResponse() async {
    if (!_aiOpponentEnabled || _board.winner != 0) return;
    setState(() => _aiThinking = true);
    try {
      final params = <String, dynamic>{
        'boardSize': _board.size,
        'captureTarget': _board.captureTarget,
        'cells': _board.cells.toList(),
        'capturedByBlack': _board.capturedByBlack,
        'capturedByWhite': _board.capturedByWhite,
        'currentPlayer': _board.currentPlayer,
        'aiStyle': CaptureAiStyle.hunter.name,
        'difficulty': DifficultyLevel.advanced.name,
        'gameMode': GameMode.capture.storageKey,
        'consecutivePasses': _board.consecutivePasses,
      };
      final move = await compute(runChooseAiMove, params);
      if (!mounted || move == null) return;
      if (!_board.applyMove(move[0], move[1])) return;
      setState(() {
        _moves.add([move[0], move[1]]);
      });
    } finally {
      if (mounted) setState(() => _aiThinking = false);
    }
  }

  void _checkPassed(int row, int col) {
    final primary = _advice?.primaryMove;
    if (primary == null) return;
    if (primary.row == row && primary.col == col) {
      _passed = true;
      widget.onProblemPassed?.call(_problem);
    }
  }

  Future<void> _onBoardTap(int row, int col) async {
    if (_passed || _aiThinking) return;
    if (_aiOpponentEnabled && _board.currentPlayer != _humanSimPlayer) return;

    final illegalReason = _board.illegalMoveReason(row, col);
    if (illegalReason != null) {
      showAppToast(context, illegalMoveToastMessage(illegalReason));
      return;
    }

    if (!_board.applyMove(row, col)) return;
    setState(() {
      _moves.add([row, col]);
      _hintPosition = null;
      _checkPassed(row, col);
    });

    if (_aiOpponentEnabled && !_passed && _board.winner == 0) {
      await _playAiResponse();
    }
  }

  void _skipCurrentProblem() {
    if (!_canSkip) return;
    setState(() {
      final current = _queue.removeAt(0);
      _queue.add(current);
      _resetBoardState();
    });
    _loadAdvice();
  }

  void _goToNextProblem() {
    if (!_passed) return;
    if (_queue.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _queue.removeAt(0);
      _resetBoardState();
    });
    _loadAdvice();
  }

  void _onPrimaryButtonPressed() {
    if (_passed) {
      _goToNextProblem();
    } else if (_canSkip) {
      _skipCurrentProblem();
    }
  }

  void _resetPosition() {
    setState(_resetBoardState);
  }

  void _undoLastMove() {
    if (_moves.isEmpty || _aiThinking) return;
    setState(() {
      _moves.removeLast();
      _passed = false;
      _hintPosition = null;
      _board = _problem.toBoard();
      for (final move in _moves) {
        _board.applyMove(move[0], move[1]);
      }
    });
  }

  void _showHintOnBoard() {
    final hint = _advice?.primaryMove;
    if (hint == null || _passed) return;
    setState(() => _hintPosition = hint);
  }

  void _showOperationsMenu(BuildContext buttonContext) {
    const menuWidth = 178.0;
    const menuItemHeight = 48.0;
    const menuDividerHeight = 0.6;
    const menuItemCount = 6;
    const menuHeight = menuItemCount * menuItemHeight +
        (menuItemCount - 1) * menuDividerHeight;
    final canUndo = _moves.isNotEmpty && !_aiThinking && !_passed;
    final canReset = _moves.isNotEmpty && !_aiThinking;
    final canHint = !_passed &&
        !_loadingAdvice &&
        !_aiThinking &&
        _advice?.primaryMove != null;

    showAnchoredOperationMenu(
      context: context,
      buttonContext: buttonContext,
      menuWidth: menuWidth,
      menuHeight: menuHeight,
      menu: _TacticsOperationContextMenu(
        moveLogVisible: _moveLogVisible,
        showMoveNumbers: _showMoveNumbers,
        canHint: canHint,
        canUndo: canUndo,
        canReset: canReset,
        onToggleMoveLog: () {
          Navigator.of(context).pop();
          setState(() => _moveLogVisible = !_moveLogVisible);
        },
        onToggleMoveNumbers: () {
          Navigator.of(context).pop();
          setState(() => _showMoveNumbers = !_showMoveNumbers);
        },
        onHint: () {
          Navigator.of(context).pop();
          _showHintOnBoard();
        },
        onUndo: () {
          Navigator.of(context).pop();
          _undoLastMove();
        },
        onReset: () {
          Navigator.of(context).pop();
          _resetPosition();
        },
        onShowAdvice: () {
          Navigator.of(context).pop();
          _showAdviceSheet();
        },
      ),
    );
  }

  void _showAdviceSheet() {
    final coordinateSystem =
        context.read<SettingsProvider?>()?.boardCoordinateSystem ??
            BoardCoordinateSystem.chinese;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoPopupSurface(
        child: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'AI 分析',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingAdvice)
                    const Text('正在計算 AI 建議…')
                  else if (_adviceError != null)
                    Text(
                      'AI 建議計算失敗：$_adviceError',
                      style: const TextStyle(
                        color: CupertinoColors.destructiveRed,
                      ),
                    )
                  else if (_advice != null)
                    _AdvicePanel(
                      advice: _advice!,
                      boardSize: _problem.boardSize,
                      coordinateSystem: coordinateSystem,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final coordinateSystem =
        context.select<SettingsProvider?, BoardCoordinateSystem>(
      (settings) =>
          settings?.boardCoordinateSystem ?? BoardCoordinateSystem.chinese,
    );
    final gameState = _gameStateFromBoard(_board);
    final navTitle =
        _aiThinking ? 'AI 正在思考' : waitingMoveTitle(_currentStoneColor);

    return CupertinoPageScaffold(
      backgroundColor: palette.pageBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.pageBackground,
        border: null,
        middle: Text(
          navTitle,
          style: TextStyle(
            color: palette.setupTitleText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Builder(
          builder: (buttonContext) => CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => _showOperationsMenu(buttonContext),
            child: Text(
              '操作',
              style: TextStyle(
                color: palette.setupActionText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tacticsProblemSubtitle(_problem),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    onPressed: () => setState(
                        () => _aiOpponentEnabled = !_aiOpponentEnabled),
                    child: Text(
                      '自動應手 ${_aiOpponentEnabled ? '開' : '關'}',
                      style: TextStyle(
                        color: palette.setupActionText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_moveLogVisible) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TacticsMoveLogStrip(
                  moves: _moves,
                  boardSize: _problem.boardSize,
                  coordinateSystem: coordinateSystem,
                  currentPlayer: _currentStoneColor,
                  palette: palette,
                  onHide: () => setState(() => _moveLogVisible = false),
                ),
              ),
            ] else
              const SizedBox(height: 45),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize =
                        math.min(constraints.maxWidth, constraints.maxHeight);
                    return Center(
                      child: GoBoardWidget(
                        gameState: gameState,
                        hintPosition: _passed ? null : _hintPosition,
                        showMoveNumbers: _showMoveNumbers,
                        moveNumberMoves: _moves,
                        showCaptureWarning: false,
                        coordinateSystem: coordinateSystem,
                        onTap: _onBoardTap,
                        size: boardSize,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Spacer(),
                  CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    onPressed:
                        (_passed || _canSkip) ? _onPrimaryButtonPressed : null,
                    child: Text(_primaryButtonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TacticsOperationContextMenu extends StatelessWidget {
  const _TacticsOperationContextMenu({
    required this.moveLogVisible,
    required this.showMoveNumbers,
    required this.canHint,
    required this.canUndo,
    required this.canReset,
    required this.onToggleMoveLog,
    required this.onToggleMoveNumbers,
    required this.onHint,
    required this.onUndo,
    required this.onReset,
    required this.onShowAdvice,
  });

  final bool moveLogVisible;
  final bool showMoveNumbers;
  final bool canHint;
  final bool canUndo;
  final bool canReset;
  final VoidCallback onToggleMoveLog;
  final VoidCallback onToggleMoveNumbers;
  final VoidCallback onHint;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onShowAdvice;

  @override
  Widget build(BuildContext context) {
    return OperationContextMenuShell(
      children: [
        OperationMenuItem(
          text: moveLogVisible ? '隱藏棋譜' : '顯示棋譜',
          enabled: true,
          onPressed: onToggleMoveLog,
        ),
        const OperationMenuDivider(),
        OperationMenuItem(
          text: showMoveNumbers ? '隱藏手數' : '顯示手數',
          enabled: true,
          onPressed: onToggleMoveNumbers,
        ),
        const OperationMenuDivider(),
        OperationMenuItem(
          text: '提示一手',
          enabled: canHint,
          onPressed: onHint,
        ),
        const OperationMenuDivider(),
        OperationMenuItem(
          text: '後退一手',
          enabled: canUndo,
          onPressed: onUndo,
        ),
        const OperationMenuDivider(),
        OperationMenuItem(
          text: '復位',
          enabled: canReset,
          onPressed: onReset,
        ),
        const OperationMenuDivider(),
        OperationMenuItem(
          text: 'AI 分析',
          enabled: true,
          onPressed: onShowAdvice,
        ),
      ],
    );
  }
}

class _AdvicePanel extends StatelessWidget {
  const _AdvicePanel({
    required this.advice,
    required this.boardSize,
    required this.coordinateSystem,
  });

  final TacticsAdviceSnapshot advice;
  final int boardSize;
  final BoardCoordinateSystem coordinateSystem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'AI 建議',
          subtitle: 'advanced 檔，各 style 獨立計算',
        ),
        const SizedBox(height: 8),
        for (final suggestion in advice.aiSuggestions)
          _SuggestionRow(
            title: suggestion.style.label,
            detail: suggestion.move == null
                ? '無合法建議'
                : '${formatPosition(suggestion.move!.row, suggestion.move!.col, boardSize, coordinateSystem: coordinateSystem)}  score ${suggestion.score!.toStringAsFixed(1)}',
          ),
        const SizedBox(height: 16),
        _SectionTitle(
          title: 'Oracle 參考',
          subtitle: advice.oracleAuthoritative
              ? 'authoritative'
              : 'non-authoritative',
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < advice.oracleRankedMoves.length; i++)
          _SuggestionRow(
            title: '#${i + 1}',
            detail:
                '${formatPosition(advice.oracleRankedMoves[i].position.row, advice.oracleRankedMoves[i].position.col, boardSize, coordinateSystem: coordinateSystem)}  score ${advice.oracleRankedMoves[i].score.toStringAsFixed(1)}',
          ),
        if (advice.oracleRankedMoves.isEmpty)
          const _SuggestionRow(title: 'Oracle', detail: '無可用排序'),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              detail,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

GameState _gameStateFromBoard(SimBoard board) {
  final stones = List.generate(
    board.size,
    (_) => List.filled(board.size, StoneColor.empty),
  );
  for (var row = 0; row < board.size; row++) {
    for (var col = 0; col < board.size; col++) {
      stones[row][col] = switch (board.colorAt(row, col)) {
        SimBoard.black => StoneColor.black,
        SimBoard.white => StoneColor.white,
        _ => StoneColor.empty,
      };
    }
  }

  return GameState(
    boardSize: board.size,
    board: stones,
    currentPlayer: board.currentPlayer == SimBoard.black
        ? StoneColor.black
        : StoneColor.white,
    capturedByBlack: List.filled(
      board.capturedByBlack,
      const BoardPosition(-1, -1),
    ),
    capturedByWhite: List.filled(
      board.capturedByWhite,
      const BoardPosition(-1, -1),
    ),
    lastMove: null,
  );
}
