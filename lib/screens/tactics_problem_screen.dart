import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../game/capture_ai.dart';
import '../game/capture_ai_tactics.dart';
import '../game/difficulty_level.dart';
import '../game/mcts_engine.dart';
import '../models/board_position.dart';
import '../models/game_state.dart';
import '../ui/tactics_labels.dart';
import '../widgets/go_board_widget.dart';

class TacticsProblemScreen extends StatefulWidget {
  const TacticsProblemScreen({
    super.key,
    required this.problem,
  });

  final CaptureAiTacticsProblem problem;

  @override
  State<TacticsProblemScreen> createState() => _TacticsProblemScreenState();
}

class _TacticsProblemScreenState extends State<TacticsProblemScreen> {
  late final Future<_TacticsAdvice> _adviceFuture;
  BoardPosition? _selectedMove;
  BoardPosition? _aiHint;

  @override
  void initState() {
    super.initState();
    _adviceFuture = Future.microtask(() => _buildAdvice(widget.problem));
    _adviceFuture.then((advice) {
      if (!mounted) return;
      setState(() => _aiHint = advice.primaryMove);
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayState =
        _gameStateFor(widget.problem, selectedMove: _selectedMove);
    final selectedAnalysis = _selectedMove == null
        ? null
        : widget.problem.toBoard().analyzeMove(
              _selectedMove!.row,
              _selectedMove!.col,
            );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.problem.id),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _ProblemHeader(problem: widget.problem),
            const SizedBox(height: 14),
            _BoardPanel(
              gameState: displayState,
              hintPosition: _selectedMove ?? _aiHint,
              onTap: (row, col) {
                final analysis = widget.problem.toBoard().analyzeMove(row, col);
                setState(() {
                  _selectedMove =
                      analysis.isLegal ? BoardPosition(row, col) : null;
                });
              },
            ),
            const SizedBox(height: 12),
            _SelectedMovePanel(
              selectedMove: _selectedMove,
              analysis: selectedAnalysis,
              boardSize: widget.problem.boardSize,
              onReset: _selectedMove == null
                  ? null
                  : () => setState(() => _selectedMove = null),
            ),
            const SizedBox(height: 14),
            FutureBuilder<_TacticsAdvice>(
              future: _adviceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CupertinoActivityIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'AI 建议计算失败：${snapshot.error}',
                    style: TextStyle(
                      color:
                          CupertinoColors.destructiveRed.resolveFrom(context),
                    ),
                  );
                }
                return _AdvicePanel(
                  advice: snapshot.data!,
                  boardSize: widget.problem.boardSize,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemHeader extends StatelessWidget {
  const _ProblemHeader({required this.problem});

  final CaptureAiTacticsProblem problem;

  @override
  Widget build(BuildContext context) {
    final tactic = problem.metadata['tactic']?.toString();
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _Badge(label: categoryName(problem.category)),
            if (tactic != null && tactic.isNotEmpty)
              _Badge(label: tacticName(tactic)),
            _Badge(label: '${problem.boardSize}路'),
            _Badge(label: '目标 ${problem.captureTarget} 子'),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '先手：${playerName(problem.currentPlayer)}   提子：黑 ${problem.capturedByBlack} / 白 ${problem.capturedByWhite}',
          style: TextStyle(fontSize: 14, color: secondary),
        ),
        if (problem.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            problem.notes,
            style: TextStyle(fontSize: 14, height: 1.4, color: secondary),
          ),
        ],
      ],
    );
  }
}

class _BoardPanel extends StatelessWidget {
  const _BoardPanel({
    required this.gameState,
    required this.hintPosition,
    required this.onTap,
  });

  final GameState gameState;
  final BoardPosition? hintPosition;
  final void Function(int row, int col) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = math.min(constraints.maxWidth, 430.0);
        return Center(
          child: GoBoardWidget(
            gameState: gameState,
            hintPosition: hintPosition,
            showCaptureWarning: false,
            onTap: onTap,
            size: boardSize,
          ),
        );
      },
    );
  }
}

class _SelectedMovePanel extends StatelessWidget {
  const _SelectedMovePanel({
    required this.selectedMove,
    required this.analysis,
    required this.boardSize,
    required this.onReset,
  });

  final BoardPosition? selectedMove;
  final SimMoveAnalysis? analysis;
  final int boardSize;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final move = selectedMove;
    final currentAnalysis = analysis;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              move == null || currentAnalysis == null
                  ? '点棋盘上的空点，可以临时试下一手。绿色标记默认显示 AI 首选。'
                  : '试下 ${formatPosition(move.row, move.col, boardSize)}：${currentAnalysis.isLegal ? '合法' : '非法'}，'
                      '黑提 +${currentAnalysis.blackCaptureDelta}，'
                      '白提 +${currentAnalysis.whiteCaptureDelta}，'
                      '己方被打吃 ${currentAnalysis.ownAtariStones} 子。',
              style: TextStyle(fontSize: 13, height: 1.35, color: secondary),
            ),
          ),
          if (onReset != null) ...[
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 28),
              onPressed: onReset,
              child: const Text('重置'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdvicePanel extends StatelessWidget {
  const _AdvicePanel({required this.advice, required this.boardSize});

  final _TacticsAdvice advice;
  final int boardSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'AI 建议',
          subtitle: 'advanced 档，各 style 独立计算',
        ),
        const SizedBox(height: 8),
        for (final suggestion in advice.aiSuggestions)
          _SuggestionRow(
            title: suggestion.style.label,
            detail: suggestion.move == null
                ? '无合法建议'
                : '${formatPosition(suggestion.move!.row, suggestion.move!.col, boardSize)}  score ${suggestion.score!.toStringAsFixed(1)}',
          ),
        const SizedBox(height: 16),
        _SectionTitle(
          title: 'Oracle 参考',
          subtitle: advice.oracle.authoritative
              ? 'authoritative'
              : 'non-authoritative',
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < math.min(3, advice.oracle.rankedMoves.length); i++)
          _SuggestionRow(
            title: '#${i + 1}',
            detail:
                '${formatPosition(advice.oracle.rankedMoves[i].position.row, advice.oracle.rankedMoves[i].position.col, boardSize)}  score ${advice.oracle.rankedMoves[i].score.toStringAsFixed(1)}',
          ),
        if (advice.oracle.rankedMoves.isEmpty)
          const _SuggestionRow(title: 'Oracle', detail: '无可用排序'),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _TacticsAdvice {
  const _TacticsAdvice({
    required this.aiSuggestions,
    required this.oracle,
  });

  final List<_AiSuggestion> aiSuggestions;
  final CaptureAiOracleResult oracle;

  BoardPosition? get primaryMove {
    for (final suggestion in aiSuggestions) {
      if (suggestion.style == CaptureAiStyle.hunter &&
          suggestion.move != null) {
        return suggestion.move;
      }
    }
    return aiSuggestions.isEmpty ? null : aiSuggestions.first.move;
  }
}

class _AiSuggestion {
  const _AiSuggestion({
    required this.style,
    required this.move,
    required this.score,
  });

  final CaptureAiStyle style;
  final BoardPosition? move;
  final double? score;
}

_TacticsAdvice _buildAdvice(CaptureAiTacticsProblem problem) {
  final baseBoard = problem.toBoard();
  final aiSuggestions = <_AiSuggestion>[];
  for (final style in CaptureAiStyle.values) {
    final agent = CaptureAiRegistry.create(
      style: style,
      difficulty: DifficultyLevel.advanced,
    );
    final move = agent.chooseMove(SimBoard.copy(baseBoard));
    aiSuggestions.add(
      _AiSuggestion(
        style: style,
        move: move?.position,
        score: move?.score,
      ),
    );
  }

  final oracle = const CaptureAiTacticalOracle(
    config: CaptureAiTacticalOracleConfig(
      depth: 2,
      candidateHorizon: 6,
      maxNodes: 3000,
      acceptScoreDelta: 80,
      topNAccepted: 3,
      maxAcceptedMoveRatio: 0.25,
      minConfidenceGap: 80,
    ),
  ).rankMoves(problem);

  return _TacticsAdvice(aiSuggestions: aiSuggestions, oracle: oracle);
}

GameState _gameStateFor(
  CaptureAiTacticsProblem problem, {
  BoardPosition? selectedMove,
}) {
  final board = problem.toBoard();
  BoardPosition? lastMove;
  if (selectedMove != null &&
      board.applyMove(selectedMove.row, selectedMove.col)) {
    lastMove = selectedMove;
  }

  return _gameStateFromBoard(board, lastMove: lastMove);
}

GameState _gameStateFromBoard(SimBoard board, {BoardPosition? lastMove}) {
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
    lastMove: lastMove,
  );
}
