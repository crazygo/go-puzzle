import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../game/board_image_recognizer.dart';
import '../game/model_board_image_recognizer.dart';
import '../models/board_position.dart';
import '../models/game_state.dart';
import '../providers/settings_provider.dart';
import '../services/app_log_store.dart';
import '../theme/theme_context.dart';
import '../ui/board_coordinates.dart';
import '../widgets/go_board_widget.dart';
import '../widgets/page_section_card.dart';

// Top-level isolate function — must be a static/top-level for compute().
Map<String, dynamic> _recognizeBoardInIsolate(Uint8List bytes) {
  final result = BoardImageRecognizer.recognize(bytes);
  return {
    'boardSize': result.boardSize,
    'confidence': result.confidence,
    'board': result.board
        .map((row) => row.map((stone) => stone.index).toList())
        .toList(),
  };
}

enum _ModelLoadDecision { ready, useRules }

class _ImportBoardDraft {
  const _ImportBoardDraft({required this.boardSize, required this.board});
  final int boardSize;
  final List<List<StoneColor>> board;
}

// ─── Public card widget ───────────────────────────────────────────────────────

/// A tap-to-import card that runs the full screenshot recognition flow and
/// returns the confirmed board to [onBoardReady].
///
/// Handles model-loading, gallery picking, recognition, and the preview/edit
/// screen internally. The caller is responsible only for navigation after a
/// board is ready (e.g. pushing to a game screen).
class ImportScreenshotCard extends StatefulWidget {
  const ImportScreenshotCard({
    super.key,
    required this.onBoardReady,
  });

  /// Called with the confirmed board size and stone layout after the user
  /// finishes editing in the preview screen.
  final void Function(int boardSize, List<List<StoneColor>> board) onBoardReady;

  @override
  State<ImportScreenshotCard> createState() => _ImportScreenshotCardState();
}

class _ImportScreenshotCardState extends State<ImportScreenshotCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final iconContainerColor = isClassic
        ? palette.setupPanelBackground
        : palette.primary.withValues(alpha: 0.16);
    final iconColor = isClassic ? palette.setupActionText : palette.primary;
    final iconBorderColor =
        isClassic ? palette.setupActionText : CupertinoColors.transparent;
    final titleColor = isClassic
        ? CupertinoColors.label.resolveFrom(context)
        : const Color(0xFF36271E);
    final subtitleColor = isClassic
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : const Color(0xFF897564);
    final chevronColor = isClassic
        ? CupertinoColors.tertiaryLabel.resolveFrom(context)
        : const Color(0xFFC09468);

    return PageSectionCard(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _isLoading ? null : _import,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconContainerColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconBorderColor),
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const CupertinoActivityIndicator(radius: 10)
                  : Icon(CupertinoIcons.photo_on_rectangle, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLoading ? '辨識中...' : '匯入截圖擺棋',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '自動辨識棋盤和棋子，預覽後微調進入擺棋',
                    style: TextStyle(fontSize: 11.5, color: subtitleColor),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: chevronColor, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _import() async {
    var algorithm =
        context.read<SettingsProvider?>()?.screenshotRecognitionAlgorithm ??
            ScreenshotRecognitionAlgorithm.rules;
    if (algorithm == ScreenshotRecognitionAlgorithm.model) {
      final decision = await _showModelLoadingDialog();
      if (!mounted || decision == null) return;
      if (decision == _ModelLoadDecision.useRules) {
        algorithm = ScreenshotRecognitionAlgorithm.rules;
      }
    }

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      AppLogStore.instance.add(
        category: AppLogCategory.screenshotRecognition,
        level: AppLogLevel.info,
        message: '開始截圖識別',
        details: 'algorithm: ${algorithm.storageValue}\n'
            'file: ${file.name}\n'
            'bytes: ${bytes.length}',
      );

      setState(() => _isLoading = true);
      final result = await _recognizeBoard(bytes, algorithm: algorithm);
      if (!mounted) return;

      AppLogStore.instance.add(
        category: AppLogCategory.screenshotRecognition,
        level: AppLogLevel.info,
        message: '截圖識別完成',
        details: 'algorithm: ${algorithm.storageValue}\n'
            'boardSize: ${result.boardSize}\n'
            'confidence: ${result.confidence.toStringAsFixed(4)}',
      );

      final draft = await Navigator.of(context).push<_ImportBoardDraft>(
        CupertinoPageRoute(
          builder: (_) => _ImportPreviewScreen(
            initialBoardSize: result.boardSize,
            initialBoard: result.board,
            confidence: result.confidence,
          ),
        ),
      );
      if (draft == null || !mounted) return;

      widget.onBoardReady(draft.boardSize, draft.board);
    } catch (error, stackTrace) {
      AppLogStore.instance.add(
        category: AppLogCategory.screenshotRecognition,
        level: AppLogLevel.error,
        message: '截圖匯入失敗',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('匯入失敗'),
          content: const Text('未能從截圖中辨識棋盤，請確認圖片清晰且包含完整棋盤。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<_ModelLoadDecision?> _showModelLoadingDialog() {
    return showCupertinoDialog<_ModelLoadDecision>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ModelRecognitionLoadingDialog(
        loadModel: ModelBoardImageRecognizer.instance.ensureLoaded,
        reloadModel: ModelBoardImageRecognizer.instance.reload,
      ),
    );
  }

  Future<BoardRecognitionResult> _recognizeBoard(
    Uint8List bytes, {
    required ScreenshotRecognitionAlgorithm algorithm,
  }) async {
    if (algorithm == ScreenshotRecognitionAlgorithm.model) {
      return ModelBoardImageRecognizer.instance.recognize(bytes);
    }
    final raw = await compute(_recognizeBoardInIsolate, bytes);
    final board = (raw['board'] as List)
        .map<List<StoneColor>>(
          (row) => (row as List)
              .map<StoneColor>((index) => StoneColor.values[index as int])
              .toList(),
        )
        .toList();
    return BoardRecognitionResult(
      boardSize: raw['boardSize'] as int,
      board: board,
      confidence: (raw['confidence'] as num).toDouble(),
    );
  }
}

// ─── Model-loading dialog ─────────────────────────────────────────────────────

class _ModelRecognitionLoadingDialog extends StatefulWidget {
  const _ModelRecognitionLoadingDialog({
    required this.loadModel,
    required this.reloadModel,
  });

  final Future<void> Function() loadModel;
  final Future<void> Function() reloadModel;

  @override
  State<_ModelRecognitionLoadingDialog> createState() =>
      _ModelRecognitionLoadingDialogState();
}

class _ModelRecognitionLoadingDialogState
    extends State<_ModelRecognitionLoadingDialog> {
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(firstAttempt: true);
  }

  Future<void> _load({required bool firstAttempt}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (firstAttempt) {
        await widget.loadModel();
      } else {
        await widget.reloadModel();
      }
      AppLogStore.instance.add(
        category: AppLogCategory.screenshotRecognition,
        level: AppLogLevel.info,
        message: '模型載入完成',
      );
      if (!mounted) return;
      Navigator.of(context).pop(_ModelLoadDecision.ready);
    } catch (error, stackTrace) {
      AppLogStore.instance.add(
        category: AppLogCategory.screenshotRecognition,
        level: AppLogLevel.error,
        message: '模型載入失敗',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final subtitleColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Center(
      child: CupertinoPopupSurface(
        isSurfacePainted: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    minimumSize: const Size.square(28),
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color:
                          CupertinoColors.tertiaryLabel.resolveFrom(context),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Center(
                  child: _isLoading
                      ? const CupertinoActivityIndicator(radius: 13)
                      : Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: palette.primary,
                          size: 28,
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isLoading ? '正在載入模型' : '模型載入失敗',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoading
                      ? (kIsWeb
                          ? '正在從 GitHub Release 下載識別模型，速度取決於網路。'
                          : '正在從 App 內置資源載入識別模型。')
                      : '可以重試載入模型，或先使用原本的算法方式匯入。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          CupertinoColors.tertiaryLabel.resolveFrom(context),
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
                if (!_isLoading) ...[
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: () => _load(firstAttempt: false),
                    child: const Text('重試'),
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    onPressed: () =>
                        Navigator.of(context).pop(_ModelLoadDecision.useRules),
                    child: const Text('使用算法方式'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Preview / edit screen ────────────────────────────────────────────────────

class _ImportPreviewScreen extends StatefulWidget {
  const _ImportPreviewScreen({
    required this.initialBoardSize,
    required this.initialBoard,
    required this.confidence,
  });

  final int initialBoardSize;
  final List<List<StoneColor>> initialBoard;
  final double confidence;

  @override
  State<_ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<_ImportPreviewScreen> {
  late int _boardSize;
  late List<List<StoneColor>> _board;

  @override
  void initState() {
    super.initState();
    _boardSize = widget.initialBoardSize;
    _board = _cloneBoard(widget.initialBoard);
  }

  @override
  Widget build(BuildContext context) {
    final coordinateSystem =
        context.select<SettingsProvider, BoardCoordinateSystem>(
            (s) => s.boardCoordinateSystem);
    final gameState = GameState(
      boardSize: _boardSize,
      board: _board,
      currentPlayer: StoneColor.black,
    );
    final confidencePct = (widget.confidence * 100).toStringAsFixed(0);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('截圖辨識預覽'),
        previousPageTitle: '歷史',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _confirm,
          child: const Text('開始擺棋'),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: PageSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '辨識可信度 $confidencePct%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A63C8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '點擊棋盤交叉點可循環切換：空 -> 黑 -> 白。確認後進入擺棋模式。',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B5C50)),
                    ),
                    const SizedBox(height: 12),
                    _BoardSizeSegment(
                      selected: _boardSize,
                      onChanged: _changeBoardSize,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0DFC9),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: GoBoardWidget(
                      gameState: gameState,
                      coordinateSystem: coordinateSystem,
                      onTap: (row, col) => _toggleStone(row, col),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _confirm,
                  child: const Text('進入擺棋模式'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeBoardSize(int newSize) {
    if (newSize == _boardSize) return;
    setState(() {
      _boardSize = newSize;
      _board = List.generate(
        _boardSize,
        (_) => List<StoneColor>.filled(_boardSize, StoneColor.empty),
      );
    });
  }

  void _toggleStone(int row, int col) {
    setState(() {
      final current = _board[row][col];
      _board[row][col] = switch (current) {
        StoneColor.empty => StoneColor.black,
        StoneColor.black => StoneColor.white,
        StoneColor.white => StoneColor.empty,
      };
    });
  }

  void _confirm() {
    Navigator.of(context).pop(
      _ImportBoardDraft(boardSize: _boardSize, board: _cloneBoard(_board)),
    );
  }

  List<List<StoneColor>> _cloneBoard(List<List<StoneColor>> source) {
    return source.map((row) => List<StoneColor>.from(row)).toList();
  }
}

// ─── Board size segment control (local copy) ─────────────────────────────────

class _BoardSizeSegment extends StatelessWidget {
  const _BoardSizeSegment({
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  static const _sizes = [9, 13, 19];
  static const _labels = ['9 路', '13 路', '19 路'];

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final selectedIndex = _sizes.indexOf(selected);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.segmentTrack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / _sizes.length;
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
                    color: palette.segmentSelected,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _sizes.length; i++)
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        onPressed: () => onChanged(_sizes[i]),
                        child: Text(
                          _labels[i],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selected == _sizes[i]
                                ? palette.segmentSelectedText
                                : palette.segmentText,
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
