import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/board_image_recognizer.dart';
import '../game/capture_ai.dart';
import '../models/board_position.dart';
import '../models/game_record.dart';
import '../models/game_state.dart';
import '../providers/capture_game_provider.dart';
import '../providers/settings_provider.dart';
import '../services/game_history_repository.dart';
import '../widgets/go_board_widget.dart';
import '../widgets/go_three_board_background.dart';
import '../widgets/page_hero_banner.dart';

class CaptureGameScreen extends StatefulWidget {
  const CaptureGameScreen({super.key});

  @override
  State<CaptureGameScreen> createState() => _CaptureGameScreenState();
}

class ThreeBoardDebugScreen extends StatefulWidget {
  const ThreeBoardDebugScreen({super.key});

  @override
  State<ThreeBoardDebugScreen> createState() => _ThreeBoardDebugScreenState();
}

class _ThreeBoardDebugScreenState extends State<ThreeBoardDebugScreen> {
  bool _panelVisible = false;
  double _leafShadowOpacity = _CaptureGameScreenState._defaultLeafShadowOpacity;
  bool _stoneExtraOverlayEnabled =
      _CaptureGameScreenState._defaultStoneExtraOverlayEnabled;
  bool _floatingParticlesEnabled =
      _CaptureGameScreenState._defaultFloatingParticlesEnabled;
  bool _cornerLabelsEnabled =
      _CaptureGameScreenState._defaultCornerLabelsEnabled;
  double _boardTopBrightness =
      _CaptureGameScreenState._defaultBoardTopBrightness;
  double _toneMappingExposure =
      _CaptureGameScreenState._defaultToneMappingExposure;
  Offset3 _keyLightPosition = _CaptureGameScreenState._defaultKeyLightPosition;
  Offset3 _fillLightPosition =
      _CaptureGameScreenState._defaultFillLightPosition;
  double _keyLightIntensity = _CaptureGameScreenState._defaultKeyLightIntensity;
  double _fillLightIntensity =
      _CaptureGameScreenState._defaultFillLightIntensity;
  double _ambientLightIntensity =
      _CaptureGameScreenState._defaultAmbientLightIntensity;
  double _sheenLightIntensity =
      _CaptureGameScreenState._defaultSheenLightIntensity;
  int _keyLightColor = _CaptureGameScreenState._defaultKeyLightColor;
  int _fillLightColor = _CaptureGameScreenState._defaultFillLightColor;
  int _ambientLightColor = _CaptureGameScreenState._defaultAmbientLightColor;
  int _sheenLightColor = _CaptureGameScreenState._defaultSheenLightColor;
  double _boardTopFactor = 0.03;
  double _boardHeightFactor = 0.66;
  double _boardCanvasYOffset =
      _CaptureGameScreenState._defaultHomeBoardCanvasYOffset;
  double _boardSceneScale = _CaptureGameScreenState._defaultHomeBoardSceneScale;
  double _boardCameraLift = _CaptureGameScreenState._defaultHomeBoardCameraLift;
  double _boardCameraDepth =
      _CaptureGameScreenState._defaultHomeBoardCameraDepth;
  double _boardTargetZOffset =
      _CaptureGameScreenState._defaultHomeBoardTargetZOffset;
  double _boardCinematicFov =
      _CaptureGameScreenState._defaultHomeBoardCinematicFov;
  double _boardRotationY = _CaptureGameScreenState._defaultHomeBoardRotationY;
  // Window irradiance controls
  double _windowCenterU = _CaptureGameScreenState._defaultWindowCenterU;
  double _windowCenterV = _CaptureGameScreenState._defaultWindowCenterV;
  double _windowSpreadU = _CaptureGameScreenState._defaultWindowSpreadU;
  double _windowSpreadV = _CaptureGameScreenState._defaultWindowSpreadV;
  // Grid dissolution controls
  double _gridBaseOpacity = _CaptureGameScreenState._defaultGridBaseOpacity;
  double _gridFadeMult = _CaptureGameScreenState._defaultGridFadeMult;
  double _gridFadePower = _CaptureGameScreenState._defaultGridFadePower;
  double _gridFadeMin = _CaptureGameScreenState._defaultGridFadeMin;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kPageBackgroundColor,
      child: DecoratedBox(
        decoration: kPageBackgroundDecoration,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                _HomeThreeBoardPreview(
                  constraints: constraints,
                  topFactor: _boardTopFactor,
                  heightFactor: _boardHeightFactor,
                  canvasYOffset: _boardCanvasYOffset,
                  sceneScale: _boardSceneScale,
                  cameraLift: _boardCameraLift,
                  cameraDepth: _boardCameraDepth,
                  targetZOffset: _boardTargetZOffset,
                  cinematicFov: _boardCinematicFov,
                  boardRotationY: _boardRotationY,
                  leafShadowOpacity: _leafShadowOpacity,
                  stoneExtraOverlayEnabled: _stoneExtraOverlayEnabled,
                  floatingParticlesEnabled: _floatingParticlesEnabled,
                  cornerLabelsEnabled: _cornerLabelsEnabled,
                  boardTopBrightness: _boardTopBrightness,
                  toneMappingExposure: _toneMappingExposure,
                  keyLightPosition: _keyLightPosition,
                  fillLightPosition: _fillLightPosition,
                  keyLightIntensity: _keyLightIntensity,
                  fillLightIntensity: _fillLightIntensity,
                  ambientLightIntensity: _ambientLightIntensity,
                  sheenLightIntensity: _sheenLightIntensity,
                  keyLightColor: _keyLightColor,
                  fillLightColor: _fillLightColor,
                  ambientLightColor: _ambientLightColor,
                  sheenLightColor: _sheenLightColor,
                  showDebugGuides: false,
                  windowCenterU: _windowCenterU,
                  windowCenterV: _windowCenterV,
                  windowSpreadU: _windowSpreadU,
                  windowSpreadV: _windowSpreadV,
                  gridBaseOpacity: _gridBaseOpacity,
                  gridFadeMult: _gridFadeMult,
                  gridFadePower: _gridFadePower,
                  gridFadeMin: _gridFadeMin,
                ),
                if (_panelVisible)
                  _HomeBoardTuningSheet(
                    shadowOpacity: _leafShadowOpacity,
                    stoneExtraOverlayEnabled: _stoneExtraOverlayEnabled,
                    floatingParticlesEnabled: _floatingParticlesEnabled,
                    cornerLabelsEnabled: _cornerLabelsEnabled,
                    boardTopBrightness: _boardTopBrightness,
                    toneMappingExposure: _toneMappingExposure,
                    keyLightPosition: _keyLightPosition,
                    fillLightPosition: _fillLightPosition,
                    keyLightIntensity: _keyLightIntensity,
                    fillLightIntensity: _fillLightIntensity,
                    ambientLightIntensity: _ambientLightIntensity,
                    sheenLightIntensity: _sheenLightIntensity,
                    keyLightColor: _keyLightColor,
                    fillLightColor: _fillLightColor,
                    ambientLightColor: _ambientLightColor,
                    sheenLightColor: _sheenLightColor,
                    boardTopFactor: _boardTopFactor,
                    boardHeightFactor: _boardHeightFactor,
                    boardCanvasYOffset: _boardCanvasYOffset,
                    boardSceneScale: _boardSceneScale,
                    boardCameraLift: _boardCameraLift,
                    boardCameraDepth: _boardCameraDepth,
                    boardTargetZOffset: _boardTargetZOffset,
                    boardCinematicFov: _boardCinematicFov,
                    boardRotationY: _boardRotationY,
                    onShadowOpacityChanged: (value) =>
                        setState(() => _leafShadowOpacity = value),
                    onStoneExtraOverlayChanged: (value) =>
                        setState(() => _stoneExtraOverlayEnabled = value),
                    onFloatingParticlesChanged: (value) =>
                        setState(() => _floatingParticlesEnabled = value),
                    onCornerLabelsChanged: (value) =>
                        setState(() => _cornerLabelsEnabled = value),
                    onBoardTopBrightnessChanged: (value) =>
                        setState(() => _boardTopBrightness = value),
                    onToneMappingExposureChanged: (value) =>
                        setState(() => _toneMappingExposure = value),
                    onKeyLightPositionChanged: (value) =>
                        setState(() => _keyLightPosition = value),
                    onFillLightPositionChanged: (value) =>
                        setState(() => _fillLightPosition = value),
                    onKeyLightIntensityChanged: (value) =>
                        setState(() => _keyLightIntensity = value),
                    onFillLightIntensityChanged: (value) =>
                        setState(() => _fillLightIntensity = value),
                    onAmbientLightIntensityChanged: (value) =>
                        setState(() => _ambientLightIntensity = value),
                    onSheenLightIntensityChanged: (value) =>
                        setState(() => _sheenLightIntensity = value),
                    onKeyLightColorChanged: (value) =>
                        setState(() => _keyLightColor = value),
                    onFillLightColorChanged: (value) =>
                        setState(() => _fillLightColor = value),
                    onAmbientLightColorChanged: (value) =>
                        setState(() => _ambientLightColor = value),
                    onSheenLightColorChanged: (value) =>
                        setState(() => _sheenLightColor = value),
                    onBoardTopFactorChanged: (value) =>
                        setState(() => _boardTopFactor = value),
                    onBoardHeightFactorChanged: (value) =>
                        setState(() => _boardHeightFactor = value),
                    onBoardCanvasYOffsetChanged: (value) =>
                        setState(() => _boardCanvasYOffset = value),
                    onBoardSceneScaleChanged: (value) =>
                        setState(() => _boardSceneScale = value),
                    onBoardCameraLiftChanged: (value) =>
                        setState(() => _boardCameraLift = value),
                    onBoardCameraDepthChanged: (value) =>
                        setState(() => _boardCameraDepth = value),
                    onBoardTargetZOffsetChanged: (value) =>
                        setState(() => _boardTargetZOffset = value),
                    onBoardCinematicFovChanged: (value) =>
                        setState(() => _boardCinematicFov = value),
                    onBoardRotationYChanged: (value) =>
                        setState(() => _boardRotationY = value),
                    windowCenterU: _windowCenterU,
                    windowCenterV: _windowCenterV,
                    windowSpreadU: _windowSpreadU,
                    windowSpreadV: _windowSpreadV,
                    gridBaseOpacity: _gridBaseOpacity,
                    gridFadeMult: _gridFadeMult,
                    gridFadePower: _gridFadePower,
                    gridFadeMin: _gridFadeMin,
                    onWindowCenterUChanged: (v) =>
                        setState(() => _windowCenterU = v),
                    onWindowCenterVChanged: (v) =>
                        setState(() => _windowCenterV = v),
                    onWindowSpreadUChanged: (v) =>
                        setState(() => _windowSpreadU = v),
                    onWindowSpreadVChanged: (v) =>
                        setState(() => _windowSpreadV = v),
                    onGridBaseOpacityChanged: (v) =>
                        setState(() => _gridBaseOpacity = v),
                    onGridFadeMultChanged: (v) =>
                        setState(() => _gridFadeMult = v),
                    onGridFadePowerChanged: (v) =>
                        setState(() => _gridFadePower = v),
                    onGridFadeMinChanged: (v) =>
                        setState(() => _gridFadeMin = v),
                    onClose: () => setState(() => _panelVisible = false),
                    onReset: _resetTuning,
                  )
                else
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: _HomeBoardTuningLauncher(
                        onTap: () => setState(() => _panelVisible = true),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _resetTuning() {
    setState(() {
      _leafShadowOpacity = _CaptureGameScreenState._defaultLeafShadowOpacity;
      _stoneExtraOverlayEnabled =
          _CaptureGameScreenState._defaultStoneExtraOverlayEnabled;
      _floatingParticlesEnabled =
          _CaptureGameScreenState._defaultFloatingParticlesEnabled;
      _cornerLabelsEnabled =
          _CaptureGameScreenState._defaultCornerLabelsEnabled;
      _boardTopBrightness = _CaptureGameScreenState._defaultBoardTopBrightness;
      _toneMappingExposure =
          _CaptureGameScreenState._defaultToneMappingExposure;
      _keyLightPosition = _CaptureGameScreenState._defaultKeyLightPosition;
      _fillLightPosition = _CaptureGameScreenState._defaultFillLightPosition;
      _keyLightIntensity = _CaptureGameScreenState._defaultKeyLightIntensity;
      _fillLightIntensity = _CaptureGameScreenState._defaultFillLightIntensity;
      _ambientLightIntensity =
          _CaptureGameScreenState._defaultAmbientLightIntensity;
      _sheenLightIntensity =
          _CaptureGameScreenState._defaultSheenLightIntensity;
      _keyLightColor = _CaptureGameScreenState._defaultKeyLightColor;
      _fillLightColor = _CaptureGameScreenState._defaultFillLightColor;
      _ambientLightColor = _CaptureGameScreenState._defaultAmbientLightColor;
      _sheenLightColor = _CaptureGameScreenState._defaultSheenLightColor;
      _boardTopFactor = 0.03;
      _boardHeightFactor = 0.66;
      _boardCanvasYOffset =
          _CaptureGameScreenState._defaultHomeBoardCanvasYOffset;
      _boardSceneScale = _CaptureGameScreenState._defaultHomeBoardSceneScale;
      _boardCameraLift = _CaptureGameScreenState._defaultHomeBoardCameraLift;
      _boardCameraDepth = _CaptureGameScreenState._defaultHomeBoardCameraDepth;
      _boardTargetZOffset =
          _CaptureGameScreenState._defaultHomeBoardTargetZOffset;
      _boardCinematicFov =
          _CaptureGameScreenState._defaultHomeBoardCinematicFov;
      _boardRotationY = _CaptureGameScreenState._defaultHomeBoardRotationY;
      _windowCenterU = _CaptureGameScreenState._defaultWindowCenterU;
      _windowCenterV = _CaptureGameScreenState._defaultWindowCenterV;
      _windowSpreadU = _CaptureGameScreenState._defaultWindowSpreadU;
      _windowSpreadV = _CaptureGameScreenState._defaultWindowSpreadV;
      _gridBaseOpacity = _CaptureGameScreenState._defaultGridBaseOpacity;
      _gridFadeMult = _CaptureGameScreenState._defaultGridFadeMult;
      _gridFadePower = _CaptureGameScreenState._defaultGridFadePower;
      _gridFadeMin = _CaptureGameScreenState._defaultGridFadeMin;
    });
  }
}

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

class _CaptureGameScreenState extends State<CaptureGameScreen> {
  static const double _defaultHomeBoardTopFactor = 0.06;
  static const double _defaultHomeBoardHeightFactor = 0.62;
  static const double _defaultHomeBoardCanvasYOffset = -34.0;
  static const double _defaultHomeBoardSceneScale = 0.88;
  static const double _defaultHomeBoardCameraLift = 0.01;
  static const double _defaultHomeBoardCameraDepth = 17.2;
  static const double _defaultHomeBoardTargetZOffset = 0.0;
  static const double _defaultHomeBoardCinematicFov = 28.0;
  static const double _defaultHomeBoardRotationY = -0.36;
  static const double _defaultHomeCardTopFactor = 0.44;
  static const double _defaultLeafShadowOpacity = 0.16;
  static const bool _defaultStoneExtraOverlayEnabled = true;
  static const bool _defaultFloatingParticlesEnabled = false;
  static const bool _defaultCornerLabelsEnabled = true;
  static const double _defaultBoardTopBrightness = 1.0;
  static const double _defaultToneMappingExposure = 0.44;
  static const Offset3 _defaultKeyLightPosition = Offset3(6.4, 6.2, 5.8);
  static const Offset3 _defaultFillLightPosition = Offset3(-4.8, 2.2, 3.2);
  static const double _defaultKeyLightIntensity = 0.88;
  static const double _defaultFillLightIntensity = 0.09;
  static const double _defaultAmbientLightIntensity = 0.15;
  static const double _defaultSheenLightIntensity = 0.14;
  static const int _defaultKeyLightColor = 0xfff0d2;
  static const int _defaultFillLightColor = 0xf4e8d8;
  static const int _defaultAmbientLightColor = 0xffeddc;
  static const int _defaultSheenLightColor = 0xfffaed;
  // Window irradiance defaults
  static const double _defaultWindowCenterU = 0.88;
  static const double _defaultWindowCenterV = 0.05;
  static const double _defaultWindowSpreadU = 1.80;
  static const double _defaultWindowSpreadV = 1.60;
  // Grid dissolution defaults
  static const double _defaultGridBaseOpacity = 0.62;
  static const double _defaultGridFadeMult = 0.78;
  static const double _defaultGridFadePower = 0.66;
  static const double _defaultGridFadeMin = 0.16;

  static const _difficultyKey = 'capture_setup.difficulty';
  static const _boardSizeKey = 'capture_setup.board_size';
  static const _initialModeKey = 'capture_setup.initial_mode';
  static const _captureTarget = 5;

  DifficultyLevel _difficulty = DifficultyLevel.intermediate;
  int _boardSize = 9;
  CaptureInitialMode _initialMode = CaptureInitialMode.twistCross;
  bool _isAdjusting = false;
  bool _isRecognizingScreenshot = false;
  bool _homeTuningSheetVisible = false;

  final _historyRepo = GameHistoryRepository();
  List<GameRecord> _history = const [];
  double _homeBoardTopFactor = _defaultHomeBoardTopFactor;
  double _homeBoardHeightFactor = _defaultHomeBoardHeightFactor;
  double _homeBoardCanvasYOffset = _defaultHomeBoardCanvasYOffset;
  double _homeBoardSceneScale = _defaultHomeBoardSceneScale;
  double _homeBoardCameraLift = _defaultHomeBoardCameraLift;
  double _homeBoardCameraDepth = _defaultHomeBoardCameraDepth;
  double _homeBoardTargetZOffset = _defaultHomeBoardTargetZOffset;
  double _homeBoardCinematicFov = _defaultHomeBoardCinematicFov;
  double _homeBoardRotationY = _defaultHomeBoardRotationY;
  double _homeCardTopFactor = _defaultHomeCardTopFactor;
  double _leafShadowOpacity = _defaultLeafShadowOpacity;
  bool _stoneExtraOverlayEnabled = _defaultStoneExtraOverlayEnabled;
  bool _floatingParticlesEnabled = _defaultFloatingParticlesEnabled;
  bool _cornerLabelsEnabled = _defaultCornerLabelsEnabled;
  double _boardTopBrightness = _defaultBoardTopBrightness;
  double _toneMappingExposure = _defaultToneMappingExposure;
  Offset3 _keyLightPosition = _defaultKeyLightPosition;
  Offset3 _fillLightPosition = _defaultFillLightPosition;
  double _keyLightIntensity = _defaultKeyLightIntensity;
  double _fillLightIntensity = _defaultFillLightIntensity;
  double _ambientLightIntensity = _defaultAmbientLightIntensity;
  double _sheenLightIntensity = _defaultSheenLightIntensity;
  int _keyLightColor = _defaultKeyLightColor;
  int _fillLightColor = _defaultFillLightColor;
  int _ambientLightColor = _defaultAmbientLightColor;
  int _sheenLightColor = _defaultSheenLightColor;
  double _windowCenterU = _defaultWindowCenterU;
  double _windowCenterV = _defaultWindowCenterV;
  double _windowSpreadU = _defaultWindowSpreadU;
  double _windowSpreadV = _defaultWindowSpreadV;
  double _gridBaseOpacity = _defaultGridBaseOpacity;
  double _gridFadeMult = _defaultGridFadeMult;
  double _gridFadePower = _defaultGridFadePower;
  double _gridFadeMin = _defaultGridFadeMin;

  @override
  void initState() {
    super.initState();
    _restoreSelection();
    _loadHistory();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topPadding = MediaQuery.of(context).padding.top;
            final cardTop = max(
              0.0,
              constraints.maxHeight * _homeCardTopFactor - topPadding,
            );

            return Stack(
              children: [
                _HomeThreeBoardPreview(
                  constraints: constraints,
                  topFactor: _homeBoardTopFactor,
                  heightFactor: _homeBoardHeightFactor,
                  canvasYOffset: _homeBoardCanvasYOffset,
                  sceneScale: _homeBoardSceneScale,
                  cameraLift: _homeBoardCameraLift,
                  cameraDepth: _homeBoardCameraDepth,
                  targetZOffset: _homeBoardTargetZOffset,
                  cinematicFov: _homeBoardCinematicFov,
                  boardRotationY: _homeBoardRotationY,
                  leafShadowOpacity: _leafShadowOpacity,
                  stoneExtraOverlayEnabled: _stoneExtraOverlayEnabled,
                  floatingParticlesEnabled: _floatingParticlesEnabled,
                  cornerLabelsEnabled: _cornerLabelsEnabled,
                  boardTopBrightness: _boardTopBrightness,
                  toneMappingExposure: _toneMappingExposure,
                  keyLightPosition: _keyLightPosition,
                  fillLightPosition: _fillLightPosition,
                  keyLightIntensity: _keyLightIntensity,
                  fillLightIntensity: _fillLightIntensity,
                  ambientLightIntensity: _ambientLightIntensity,
                  sheenLightIntensity: _sheenLightIntensity,
                  keyLightColor: _keyLightColor,
                  fillLightColor: _fillLightColor,
                  ambientLightColor: _ambientLightColor,
                  sheenLightColor: _sheenLightColor,
                  showDebugGuides: true,
                  windowCenterU: _windowCenterU,
                  windowCenterV: _windowCenterV,
                  windowSpreadU: _windowSpreadU,
                  windowSpreadV: _windowSpreadV,
                  gridBaseOpacity: _gridBaseOpacity,
                  gridFadeMult: _gridFadeMult,
                  gridFadePower: _gridFadePower,
                  gridFadeMin: _gridFadeMin,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: PageHeroBanner(
                    title: _CaptureCopy.pageTitle,
                    subtitle: _CaptureCopy.pageSubtitle,
                    showOrbitalArt: false,
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(height: cardTop),
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
                                    _PracticeHeader(
                                      title: '下一盘',
                                      subtitle: '先吃$_captureTarget子为胜',
                                      isAdjusting: _isAdjusting,
                                      onAdjustTap: () => setState(
                                        () => _isAdjusting = !_isAdjusting,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    if (_isAdjusting) ...[
                                      const _SectionLabel(title: '棋盘'),
                                      const SizedBox(height: 4),
                                      _PillSegmentControl<int>(
                                        selectedValue: _boardSize,
                                        options: const [
                                          _SegmentOption(
                                              value: 9, label: '9 路'),
                                          _SegmentOption(
                                              value: 13, label: '13 路'),
                                          _SegmentOption(
                                              value: 19, label: '19 路'),
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
                                            value:
                                                CaptureInitialMode.twistCross,
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
                                        onChanged: (value) => _updateSelection(
                                            initialMode: value),
                                      ),
                                      const SizedBox(height: 20),
                                      const _SectionLabel(title: 'AI 风格'),
                                      const SizedBox(height: 8),
                                      const _AiStyleTile(),
                                      const SizedBox(height: 24),
                                    ] else ...[
                                      _ConfigPreview(
                                        boardSize: _boardSize,
                                        difficulty: _difficulty,
                                        initialMode: _initialMode,
                                      ),
                                      const SizedBox(height: 24),
                                    ],
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
                              const SizedBox(height: 10),
                              _ImportScreenshotCard(
                                isLoading: _isRecognizingScreenshot,
                                onTap: _isRecognizingScreenshot
                                    ? null
                                    : _importBoardFromScreenshot,
                              ),
                              const SizedBox(height: 14),
                              if (_history.isNotEmpty) ...[
                                _HistorySectionCard(
                                  history: _history,
                                  onReplay: _startGameFromRecord,
                                ),
                                const SizedBox(height: 14),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (kIsWeb)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: _HomeBoardTuningLauncher(
                        onTap: () =>
                            setState(() => _homeTuningSheetVisible = true),
                      ),
                    ),
                  ),
                if (kIsWeb && _homeTuningSheetVisible)
                  _HomeBoardTuningSheet(
                    shadowOpacity: _leafShadowOpacity,
                    stoneExtraOverlayEnabled: _stoneExtraOverlayEnabled,
                    floatingParticlesEnabled: _floatingParticlesEnabled,
                    cornerLabelsEnabled: _cornerLabelsEnabled,
                    boardTopBrightness: _boardTopBrightness,
                    toneMappingExposure: _toneMappingExposure,
                    keyLightPosition: _keyLightPosition,
                    fillLightPosition: _fillLightPosition,
                    keyLightIntensity: _keyLightIntensity,
                    fillLightIntensity: _fillLightIntensity,
                    ambientLightIntensity: _ambientLightIntensity,
                    sheenLightIntensity: _sheenLightIntensity,
                    keyLightColor: _keyLightColor,
                    fillLightColor: _fillLightColor,
                    ambientLightColor: _ambientLightColor,
                    sheenLightColor: _sheenLightColor,
                    boardTopFactor: _homeBoardTopFactor,
                    boardHeightFactor: _homeBoardHeightFactor,
                    boardCanvasYOffset: _homeBoardCanvasYOffset,
                    boardSceneScale: _homeBoardSceneScale,
                    boardCameraLift: _homeBoardCameraLift,
                    boardCameraDepth: _homeBoardCameraDepth,
                    boardTargetZOffset: _homeBoardTargetZOffset,
                    boardCinematicFov: _homeBoardCinematicFov,
                    boardRotationY: _homeBoardRotationY,
                    onShadowOpacityChanged: (value) =>
                        setState(() => _leafShadowOpacity = value),
                    onStoneExtraOverlayChanged: (value) =>
                        setState(() => _stoneExtraOverlayEnabled = value),
                    onFloatingParticlesChanged: (value) =>
                        setState(() => _floatingParticlesEnabled = value),
                    onCornerLabelsChanged: (value) =>
                        setState(() => _cornerLabelsEnabled = value),
                    onBoardTopBrightnessChanged: (value) =>
                        setState(() => _boardTopBrightness = value),
                    onToneMappingExposureChanged: (value) =>
                        setState(() => _toneMappingExposure = value),
                    onKeyLightPositionChanged: (value) =>
                        setState(() => _keyLightPosition = value),
                    onFillLightPositionChanged: (value) =>
                        setState(() => _fillLightPosition = value),
                    onKeyLightIntensityChanged: (value) =>
                        setState(() => _keyLightIntensity = value),
                    onFillLightIntensityChanged: (value) =>
                        setState(() => _fillLightIntensity = value),
                    onAmbientLightIntensityChanged: (value) =>
                        setState(() => _ambientLightIntensity = value),
                    onSheenLightIntensityChanged: (value) =>
                        setState(() => _sheenLightIntensity = value),
                    onKeyLightColorChanged: (value) =>
                        setState(() => _keyLightColor = value),
                    onFillLightColorChanged: (value) =>
                        setState(() => _fillLightColor = value),
                    onAmbientLightColorChanged: (value) =>
                        setState(() => _ambientLightColor = value),
                    onSheenLightColorChanged: (value) =>
                        setState(() => _sheenLightColor = value),
                    onBoardTopFactorChanged: (value) =>
                        setState(() => _homeBoardTopFactor = value),
                    onBoardHeightFactorChanged: (value) =>
                        setState(() => _homeBoardHeightFactor = value),
                    onBoardCanvasYOffsetChanged: (value) =>
                        setState(() => _homeBoardCanvasYOffset = value),
                    onBoardSceneScaleChanged: (value) =>
                        setState(() => _homeBoardSceneScale = value),
                    onBoardCameraLiftChanged: (value) =>
                        setState(() => _homeBoardCameraLift = value),
                    onBoardCameraDepthChanged: (value) =>
                        setState(() => _homeBoardCameraDepth = value),
                    onBoardTargetZOffsetChanged: (value) =>
                        setState(() => _homeBoardTargetZOffset = value),
                    onBoardCinematicFovChanged: (value) =>
                        setState(() => _homeBoardCinematicFov = value),
                    onBoardRotationYChanged: (value) =>
                        setState(() => _homeBoardRotationY = value),
                    windowCenterU: _windowCenterU,
                    windowCenterV: _windowCenterV,
                    windowSpreadU: _windowSpreadU,
                    windowSpreadV: _windowSpreadV,
                    gridBaseOpacity: _gridBaseOpacity,
                    gridFadeMult: _gridFadeMult,
                    gridFadePower: _gridFadePower,
                    gridFadeMin: _gridFadeMin,
                    onWindowCenterUChanged: (v) =>
                        setState(() => _windowCenterU = v),
                    onWindowCenterVChanged: (v) =>
                        setState(() => _windowCenterV = v),
                    onWindowSpreadUChanged: (v) =>
                        setState(() => _windowSpreadU = v),
                    onWindowSpreadVChanged: (v) =>
                        setState(() => _windowSpreadV = v),
                    onGridBaseOpacityChanged: (v) =>
                        setState(() => _gridBaseOpacity = v),
                    onGridFadeMultChanged: (v) =>
                        setState(() => _gridFadeMult = v),
                    onGridFadePowerChanged: (v) =>
                        setState(() => _gridFadePower = v),
                    onGridFadeMinChanged: (v) =>
                        setState(() => _gridFadeMin = v),
                    onClose: () =>
                        setState(() => _homeTuningSheetVisible = false),
                    onReset: _resetHomeBoardTuning,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _resetHomeBoardTuning() {
    setState(() {
      _homeBoardTopFactor = _defaultHomeBoardTopFactor;
      _homeBoardHeightFactor = _defaultHomeBoardHeightFactor;
      _homeBoardCanvasYOffset = _defaultHomeBoardCanvasYOffset;
      _homeBoardSceneScale = _defaultHomeBoardSceneScale;
      _homeBoardCameraLift = _defaultHomeBoardCameraLift;
      _homeBoardCameraDepth = _defaultHomeBoardCameraDepth;
      _homeBoardTargetZOffset = _defaultHomeBoardTargetZOffset;
      _homeBoardCinematicFov = _defaultHomeBoardCinematicFov;
      _homeBoardRotationY = _defaultHomeBoardRotationY;
      _homeCardTopFactor = _defaultHomeCardTopFactor;
      _leafShadowOpacity = _defaultLeafShadowOpacity;
      _stoneExtraOverlayEnabled = _defaultStoneExtraOverlayEnabled;
      _floatingParticlesEnabled = _defaultFloatingParticlesEnabled;
      _cornerLabelsEnabled = _defaultCornerLabelsEnabled;
      _boardTopBrightness = _defaultBoardTopBrightness;
      _toneMappingExposure = _defaultToneMappingExposure;
      _keyLightPosition = _defaultKeyLightPosition;
      _fillLightPosition = _defaultFillLightPosition;
      _keyLightIntensity = _defaultKeyLightIntensity;
      _fillLightIntensity = _defaultFillLightIntensity;
      _ambientLightIntensity = _defaultAmbientLightIntensity;
      _sheenLightIntensity = _defaultSheenLightIntensity;
      _keyLightColor = _defaultKeyLightColor;
      _fillLightColor = _defaultFillLightColor;
      _ambientLightColor = _defaultAmbientLightColor;
      _sheenLightColor = _defaultSheenLightColor;
      _windowCenterU = _defaultWindowCenterU;
      _windowCenterV = _defaultWindowCenterV;
      _windowSpreadU = _defaultWindowSpreadU;
      _windowSpreadV = _defaultWindowSpreadV;
      _gridBaseOpacity = _defaultGridBaseOpacity;
      _gridFadeMult = _defaultGridFadeMult;
      _gridFadePower = _defaultGridFadePower;
      _gridFadeMin = _defaultGridFadeMin;
    });
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

  Future<void> _loadHistory() async {
    final records = await _historyRepo.loadAll();
    if (!mounted) return;
    setState(() => _history = records);
  }

  Future<void> _importBoardFromScreenshot() async {
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

      setState(() {
        _isRecognizingScreenshot = true;
      });
      final result = await _recognizeBoard(bytes);
      if (!mounted) return;

      final edited = await Navigator.of(context).push<_ImportBoardDraft>(
        CupertinoPageRoute(
          builder: (_) => _ImportPreviewScreen(
            initialBoardSize: result.boardSize,
            initialBoard: result.board,
            confidence: result.confidence,
          ),
        ),
      );
      if (edited == null || !mounted) return;

      setState(() {
        _boardSize = edited.boardSize;
        _initialMode = CaptureInitialMode.setup;
      });
      await _saveSelection();
      if (!mounted) return;

      _startGame(
        humanColor: StoneColor.black,
        forceSetup: true,
        initialBoard: edited.board,
      );
    } catch (_) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('导入失败'),
          content: const Text('未能从截屏中识别棋盘，请确认图片清晰且包含完整棋盘。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizingScreenshot = false;
        });
      }
    }
  }

  Future<BoardRecognitionResult> _recognizeBoard(Uint8List bytes) async {
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

  void _startGame({
    required StoneColor humanColor,
    bool forceSetup = false,
    List<List<StoneColor>>? initialBoard,
  }) {
    _saveSelection();
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CaptureGameProvider(
            boardSize: _boardSize,
            captureTarget: _captureTarget,
            difficulty: _difficulty,
            humanColor: humanColor,
            initialMode: forceSetup ? CaptureInitialMode.setup : _initialMode,
            initialBoardOverride: initialBoard,
          ),
          child: CaptureGamePlayScreen(
            difficulty: _difficulty,
            captureTarget: _captureTarget,
            humanColor: humanColor,
            initialMode: forceSetup ? CaptureInitialMode.setup : _initialMode,
            initialBoardOverride: initialBoard,
          ),
        ),
      ),
    ).then((_) => _loadHistory());
  }

  /// Starts a new game seeded from a [GameRecord] (the "重下这一手" flow).
  void _startGameFromRecord(
    GameRecord record,
    DifficultyLevel difficulty,
    CaptureInitialMode mode,
  ) {
    final useOriginalBoard =
        mode == CaptureInitialMode.setup && record.initialBoardCells != null;
    final initialBoard = useOriginalBoard
        ? record.initialBoardCells!
            .map((row) => row
                .map((i) => StoneColor.values[i.clamp(0, StoneColor.values.length - 1)])
                .toList())
            .toList()
        : null;
    final humanColor = record.humanColor;

    setState(() {
      _difficulty = difficulty;
      _boardSize = record.boardSize;
      _initialMode = mode;
    });
    _saveSelection();

    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CaptureGameProvider(
            boardSize: record.boardSize,
            captureTarget: record.captureTarget,
            difficulty: difficulty,
            humanColor: humanColor,
            initialMode: mode,
            initialBoardOverride: initialBoard,
          ),
          child: CaptureGamePlayScreen(
            difficulty: difficulty,
            captureTarget: record.captureTarget,
            humanColor: humanColor,
            initialMode: mode,
            initialBoardOverride: initialBoard,
          ),
        ),
      ),
    ).then((_) => _loadHistory());
  }
}

class _ParticlePreviewCanvas extends StatelessWidget {
  const _ParticlePreviewCanvas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: PageHeroBanner(
          title: _CaptureCopy.pageTitle,
          subtitle: _CaptureCopy.pageSubtitle,
          showOrbitalArt: false,
        ),
      ),
    );
  }
}

class _HomeThreeBoardPreview extends StatelessWidget {
  const _HomeThreeBoardPreview({
    required this.constraints,
    required this.topFactor,
    required this.heightFactor,
    required this.canvasYOffset,
    required this.sceneScale,
    required this.cameraLift,
    required this.cameraDepth,
    required this.targetZOffset,
    required this.cinematicFov,
    required this.boardRotationY,
    required this.leafShadowOpacity,
    required this.stoneExtraOverlayEnabled,
    required this.floatingParticlesEnabled,
    required this.cornerLabelsEnabled,
    required this.boardTopBrightness,
    required this.toneMappingExposure,
    required this.keyLightPosition,
    required this.fillLightPosition,
    required this.keyLightIntensity,
    required this.fillLightIntensity,
    required this.ambientLightIntensity,
    required this.sheenLightIntensity,
    required this.keyLightColor,
    required this.fillLightColor,
    required this.ambientLightColor,
    required this.sheenLightColor,
    required this.showDebugGuides,
    required this.windowCenterU,
    required this.windowCenterV,
    required this.windowSpreadU,
    required this.windowSpreadV,
    required this.gridBaseOpacity,
    required this.gridFadeMult,
    required this.gridFadePower,
    required this.gridFadeMin,
  });

  final BoxConstraints constraints;
  final double topFactor;
  final double heightFactor;
  final double canvasYOffset;
  final double sceneScale;
  final double cameraLift;
  final double cameraDepth;
  final double targetZOffset;
  final double cinematicFov;
  final double boardRotationY;
  final double leafShadowOpacity;
  final bool stoneExtraOverlayEnabled;
  final bool floatingParticlesEnabled;
  final bool cornerLabelsEnabled;
  final double boardTopBrightness;
  final double toneMappingExposure;
  final Offset3 keyLightPosition;
  final Offset3 fillLightPosition;
  final double keyLightIntensity;
  final double fillLightIntensity;
  final double ambientLightIntensity;
  final double sheenLightIntensity;
  final int keyLightColor;
  final int fillLightColor;
  final int ambientLightColor;
  final int sheenLightColor;
  final bool showDebugGuides;
  final double windowCenterU;
  final double windowCenterV;
  final double windowSpreadU;
  final double windowSpreadV;
  final double gridBaseOpacity;
  final double gridFadeMult;
  final double gridFadePower;
  final double gridFadeMin;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: constraints.maxHeight * topFactor,
      left: 0,
      right: 0,
      height: constraints.maxHeight * heightFactor,
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(0, canvasYOffset),
          child: GoThreeBoardBackground(
            boardSize: 19,
            stones: kGoThreeDemoStones,
            particles: floatingParticlesEnabled,
            showCornerLabels: cornerLabelsEnabled,
            sceneScale: sceneScale,
            cameraLift: cameraLift,
            cameraDepth: cameraDepth,
            targetZOffset: targetZOffset,
            cinematicFov: cinematicFov,
            boardRotationY: boardRotationY,
            leafShadowOpacity: leafShadowOpacity,
            stoneExtraOverlayEnabled: stoneExtraOverlayEnabled,
            boardTopBrightness: boardTopBrightness,
            toneMappingExposure: toneMappingExposure,
            showDebugGuides: showDebugGuides,
            keyLightPosition: keyLightPosition,
            fillLightPosition: fillLightPosition,
            keyLightIntensity: keyLightIntensity,
            fillLightIntensity: fillLightIntensity,
            ambientLightIntensity: ambientLightIntensity,
            sheenLightIntensity: sheenLightIntensity,
            keyLightColor: keyLightColor,
            fillLightColor: fillLightColor,
            ambientLightColor: ambientLightColor,
            sheenLightColor: sheenLightColor,
            windowCenterU: windowCenterU,
            windowCenterV: windowCenterV,
            windowSpreadU: windowSpreadU,
            windowSpreadV: windowSpreadV,
            gridBaseOpacity: gridBaseOpacity,
            gridFadeMult: gridFadeMult,
            gridFadePower: gridFadePower,
            gridFadeMin: gridFadeMin,
          ),
        ),
      ),
    );
  }
}

class _HomeBoardTuningLauncher extends StatelessWidget {
  const _HomeBoardTuningLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF7FFFDF9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x26B68454)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: Size.zero,
          onPressed: onTap,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 18,
                color: Color(0xFFB68454),
              ),
              SizedBox(width: 6),
              Text(
                '调光',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A613A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBoardTuningSheet extends StatefulWidget {
  const _HomeBoardTuningSheet({
    required this.shadowOpacity,
    required this.stoneExtraOverlayEnabled,
    required this.floatingParticlesEnabled,
    required this.cornerLabelsEnabled,
    required this.boardTopBrightness,
    required this.toneMappingExposure,
    required this.keyLightPosition,
    required this.fillLightPosition,
    required this.keyLightIntensity,
    required this.fillLightIntensity,
    required this.ambientLightIntensity,
    required this.sheenLightIntensity,
    required this.keyLightColor,
    required this.fillLightColor,
    required this.ambientLightColor,
    required this.sheenLightColor,
    required this.boardTopFactor,
    required this.boardHeightFactor,
    required this.boardCanvasYOffset,
    required this.boardSceneScale,
    required this.boardCameraLift,
    required this.boardCameraDepth,
    required this.boardTargetZOffset,
    required this.boardCinematicFov,
    required this.boardRotationY,
    required this.onShadowOpacityChanged,
    required this.onStoneExtraOverlayChanged,
    required this.onFloatingParticlesChanged,
    required this.onCornerLabelsChanged,
    required this.onBoardTopBrightnessChanged,
    required this.onToneMappingExposureChanged,
    required this.onKeyLightPositionChanged,
    required this.onFillLightPositionChanged,
    required this.onKeyLightIntensityChanged,
    required this.onFillLightIntensityChanged,
    required this.onAmbientLightIntensityChanged,
    required this.onSheenLightIntensityChanged,
    required this.onKeyLightColorChanged,
    required this.onFillLightColorChanged,
    required this.onAmbientLightColorChanged,
    required this.onSheenLightColorChanged,
    required this.onBoardTopFactorChanged,
    required this.onBoardHeightFactorChanged,
    required this.onBoardCanvasYOffsetChanged,
    required this.onBoardSceneScaleChanged,
    required this.onBoardCameraLiftChanged,
    required this.onBoardCameraDepthChanged,
    required this.onBoardTargetZOffsetChanged,
    required this.onBoardCinematicFovChanged,
    required this.onBoardRotationYChanged,
    required this.onClose,
    required this.onReset,
    required this.windowCenterU,
    required this.windowCenterV,
    required this.windowSpreadU,
    required this.windowSpreadV,
    required this.gridBaseOpacity,
    required this.gridFadeMult,
    required this.gridFadePower,
    required this.gridFadeMin,
    required this.onWindowCenterUChanged,
    required this.onWindowCenterVChanged,
    required this.onWindowSpreadUChanged,
    required this.onWindowSpreadVChanged,
    required this.onGridBaseOpacityChanged,
    required this.onGridFadeMultChanged,
    required this.onGridFadePowerChanged,
    required this.onGridFadeMinChanged,
  });

  final double shadowOpacity;
  final bool stoneExtraOverlayEnabled;
  final bool floatingParticlesEnabled;
  final bool cornerLabelsEnabled;
  final double boardTopBrightness;
  final double toneMappingExposure;
  final Offset3 keyLightPosition;
  final Offset3 fillLightPosition;
  final double keyLightIntensity;
  final double fillLightIntensity;
  final double ambientLightIntensity;
  final double sheenLightIntensity;
  final int keyLightColor;
  final int fillLightColor;
  final int ambientLightColor;
  final int sheenLightColor;
  final double boardTopFactor;
  final double boardHeightFactor;
  final double boardCanvasYOffset;
  final double boardSceneScale;
  final double boardCameraLift;
  final double boardCameraDepth;
  final double boardTargetZOffset;
  final double boardCinematicFov;
  final double boardRotationY;
  final ValueChanged<double> onShadowOpacityChanged;
  final ValueChanged<bool> onStoneExtraOverlayChanged;
  final ValueChanged<bool> onFloatingParticlesChanged;
  final ValueChanged<bool> onCornerLabelsChanged;
  final ValueChanged<double> onBoardTopBrightnessChanged;
  final ValueChanged<double> onToneMappingExposureChanged;
  final ValueChanged<Offset3> onKeyLightPositionChanged;
  final ValueChanged<Offset3> onFillLightPositionChanged;
  final ValueChanged<double> onKeyLightIntensityChanged;
  final ValueChanged<double> onFillLightIntensityChanged;
  final ValueChanged<double> onAmbientLightIntensityChanged;
  final ValueChanged<double> onSheenLightIntensityChanged;
  final ValueChanged<int> onKeyLightColorChanged;
  final ValueChanged<int> onFillLightColorChanged;
  final ValueChanged<int> onAmbientLightColorChanged;
  final ValueChanged<int> onSheenLightColorChanged;
  final ValueChanged<double> onBoardTopFactorChanged;
  final ValueChanged<double> onBoardHeightFactorChanged;
  final ValueChanged<double> onBoardCanvasYOffsetChanged;
  final ValueChanged<double> onBoardSceneScaleChanged;
  final ValueChanged<double> onBoardCameraLiftChanged;
  final ValueChanged<double> onBoardCameraDepthChanged;
  final ValueChanged<double> onBoardTargetZOffsetChanged;
  final ValueChanged<double> onBoardCinematicFovChanged;
  final ValueChanged<double> onBoardRotationYChanged;
  final VoidCallback onClose;
  final VoidCallback onReset;
  final double windowCenterU;
  final double windowCenterV;
  final double windowSpreadU;
  final double windowSpreadV;
  final double gridBaseOpacity;
  final double gridFadeMult;
  final double gridFadePower;
  final double gridFadeMin;
  final ValueChanged<double> onWindowCenterUChanged;
  final ValueChanged<double> onWindowCenterVChanged;
  final ValueChanged<double> onWindowSpreadUChanged;
  final ValueChanged<double> onWindowSpreadVChanged;
  final ValueChanged<double> onGridBaseOpacityChanged;
  final ValueChanged<double> onGridFadeMultChanged;
  final ValueChanged<double> onGridFadePowerChanged;
  final ValueChanged<double> onGridFadeMinChanged;

  @override
  State<_HomeBoardTuningSheet> createState() => _HomeBoardTuningSheetState();
}

class _HomeBoardTuningSheetState extends State<_HomeBoardTuningSheet> {
  static const List<String> _tabTitles = ['基础', '构图', '主光', '补光', '环境', '格子'];
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final tabPages = <List<Widget>>[
      [
        _TuningSwitchRow(
          title: '棋子额外阴影叠加',
          value: widget.stoneExtraOverlayEnabled,
          onChanged: widget.onStoneExtraOverlayChanged,
        ),
        _TuningSwitchRow(
          title: '漂浮粒子',
          value: widget.floatingParticlesEnabled,
          onChanged: widget.onFloatingParticlesChanged,
        ),
        _TuningSwitchRow(
          title: '角标 ABCD',
          value: widget.cornerLabelsEnabled,
          onChanged: widget.onCornerLabelsChanged,
        ),
        _TuningSlider(
          label: '棋盘亮度',
          value: widget.boardTopBrightness,
          min: 0.40,
          max: 2.40,
          onChanged: widget.onBoardTopBrightnessChanged,
        ),
        _TuningSlider(
          label: '曝光',
          value: widget.toneMappingExposure,
          min: 0.10,
          max: 1.20,
          onChanged: widget.onToneMappingExposureChanged,
        ),
        _TuningSlider(
          label: '主光强度',
          value: widget.keyLightIntensity,
          min: 0.0,
          max: 1.8,
          onChanged: widget.onKeyLightIntensityChanged,
        ),
        _TuningSlider(
          label: '补光强度',
          value: widget.fillLightIntensity,
          min: 0.0,
          max: 1.2,
          onChanged: widget.onFillLightIntensityChanged,
        ),
        _TuningSlider(
          label: '环境光',
          value: widget.ambientLightIntensity,
          min: 0.0,
          max: 0.9,
          onChanged: widget.onAmbientLightIntensityChanged,
        ),
        const _TuningGroupTitle('棋盘氛围'),
        _TuningSlider(
          label: '叶影强度',
          value: widget.shadowOpacity,
          min: 0.04,
          max: 0.28,
          onChanged: widget.onShadowOpacityChanged,
        ),
      ],
      [
        _TuningSlider(
          label: 'FOV',
          value: widget.boardCinematicFov,
          min: 18,
          max: 100,
          onChanged: widget.onBoardCinematicFovChanged,
        ),
        _TuningSlider(
          label: '缩放',
          value: widget.boardSceneScale,
          min: 0.24,
          max: 2.0,
          onChanged: widget.onBoardSceneScaleChanged,
        ),
        _TuningSlider(
          label: '相机高',
          value: widget.boardCameraLift,
          min: 0.01,
          max: 20,
          onChanged: widget.onBoardCameraLiftChanged,
        ),
        _TuningSlider(
          label: '相机远',
          value: widget.boardCameraDepth,
          min: 1.0,
          max: 30,
          onChanged: widget.onBoardCameraDepthChanged,
        ),
        _TuningSlider(
          label: '目标Z',
          value: widget.boardTargetZOffset,
          min: -1.4,
          max: 0.6,
          onChanged: widget.onBoardTargetZOffsetChanged,
        ),
        _TuningSlider(
          label: '棋盘转向',
          value: widget.boardRotationY,
          min: -3.14,
          max: 3.14,
          onChanged: widget.onBoardRotationYChanged,
        ),
        const _TuningGroupTitle('画布位置'),
        _TuningSlider(
          label: '顶部',
          value: widget.boardTopFactor,
          min: 0.0,
          max: 0.18,
          onChanged: widget.onBoardTopFactorChanged,
        ),
        _TuningSlider(
          label: '高度',
          value: widget.boardHeightFactor,
          min: 0.48,
          max: 0.86,
          onChanged: widget.onBoardHeightFactorChanged,
        ),
        _TuningSlider(
          label: '偏移Y',
          value: widget.boardCanvasYOffset,
          min: -160,
          max: 60,
          onChanged: widget.onBoardCanvasYOffsetChanged,
        ),
      ],
      [
        _Vector3Editor(
          value: widget.keyLightPosition,
          onChanged: widget.onKeyLightPositionChanged,
        ),
        _TuningSlider(
          label: '主光强度',
          value: widget.keyLightIntensity,
          min: 0.0,
          max: 1.8,
          onChanged: widget.onKeyLightIntensityChanged,
        ),
        _RgbEditor(
          title: '主光颜色',
          colorHex: widget.keyLightColor,
          onChanged: widget.onKeyLightColorChanged,
        ),
      ],
      [
        _Vector3Editor(
          value: widget.fillLightPosition,
          onChanged: widget.onFillLightPositionChanged,
        ),
        _TuningSlider(
          label: '补光强度',
          value: widget.fillLightIntensity,
          min: 0.0,
          max: 1.2,
          onChanged: widget.onFillLightIntensityChanged,
        ),
        _RgbEditor(
          title: '补光颜色',
          colorHex: widget.fillLightColor,
          onChanged: widget.onFillLightColorChanged,
        ),
      ],
      [
        _TuningSlider(
          label: '环境光',
          value: widget.ambientLightIntensity,
          min: 0.0,
          max: 0.9,
          onChanged: widget.onAmbientLightIntensityChanged,
        ),
        _RgbEditor(
          title: '环境光颜色',
          colorHex: widget.ambientLightColor,
          onChanged: widget.onAmbientLightColorChanged,
        ),
        _TuningSlider(
          label: '高光灯',
          value: widget.sheenLightIntensity,
          min: 0.0,
          max: 1.4,
          onChanged: widget.onSheenLightIntensityChanged,
        ),
        _RgbEditor(
          title: '高光颜色',
          colorHex: widget.sheenLightColor,
          onChanged: widget.onSheenLightColorChanged,
        ),
      ],
      // 格子 tab
      [
        _TuningSlider(
          label: '窗光中心 U',
          value: widget.windowCenterU,
          min: 0.50,
          max: 1.00,
          onChanged: widget.onWindowCenterUChanged,
        ),
        _TuningSlider(
          label: '窗光中心 V',
          value: widget.windowCenterV,
          min: 0.00,
          max: 0.50,
          onChanged: widget.onWindowCenterVChanged,
        ),
        _TuningSlider(
          label: '窗光扩散 U',
          value: widget.windowSpreadU,
          min: 0.50,
          max: 4.00,
          onChanged: widget.onWindowSpreadUChanged,
        ),
        _TuningSlider(
          label: '窗光扩散 V',
          value: widget.windowSpreadV,
          min: 0.50,
          max: 4.00,
          onChanged: widget.onWindowSpreadVChanged,
        ),
        _TuningSlider(
          label: '格子基础透明度',
          value: widget.gridBaseOpacity,
          min: 0.10,
          max: 1.00,
          onChanged: widget.onGridBaseOpacityChanged,
        ),
        _TuningSlider(
          label: '格子淡化强度',
          value: widget.gridFadeMult,
          min: 0.00,
          max: 1.20,
          onChanged: widget.onGridFadeMultChanged,
        ),
        _TuningSlider(
          label: '格子淡化曲线',
          value: widget.gridFadePower,
          min: 0.20,
          max: 2.00,
          onChanged: widget.onGridFadePowerChanged,
        ),
        _TuningSlider(
          label: '格子最低不透明',
          value: widget.gridFadeMin,
          min: 0.00,
          max: 0.50,
          onChanged: widget.onGridFadeMinChanged,
        ),
      ],
    ];

    return Positioned.fill(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 1, end: 0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value * 460),
                  child: child,
                );
              },
              child: Container(
                height: MediaQuery.of(context).size.height * 0.34,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Color(0xF7FFFDF9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x2A000000),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: CupertinoSlidingSegmentedControl<int>(
                              groupValue: _selectedTab,
                              children: {
                                for (int i = 0; i < _tabTitles.length; i++)
                                  i: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      _tabTitles[i],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              },
                              onValueChanged: (next) {
                                if (next != null) {
                                  setState(() => _selectedTab = next);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(42, 30),
                          onPressed: widget.onReset,
                          child: const Text('重置'),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(42, 30),
                          onPressed: widget.onClose,
                          child: const Text('关闭'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: CupertinoScrollbar(
                        child: SingleChildScrollView(
                          child: Column(
                            children: tabPages[_selectedTab],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TuningSlider extends StatelessWidget {
  const _TuningSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF7E6F61)),
          ),
        ),
        Expanded(
          child: CupertinoSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: const Color(0xFFB68454),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10, color: Color(0xFF7E6F61)),
          ),
        ),
      ],
    );
  }
}

class _TuningGroupTitle extends StatelessWidget {
  const _TuningGroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6A5239),
          ),
        ),
      ),
    );
  }
}

class _TuningSwitchRow extends StatelessWidget {
  const _TuningSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5E4E42),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        CupertinoSwitch(
          value: value,
          activeTrackColor: const Color(0xFFB68454),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Vector3Editor extends StatelessWidget {
  const _Vector3Editor({required this.value, required this.onChanged});

  final Offset3 value;
  final ValueChanged<Offset3> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TuningSlider(
          label: 'X',
          value: value.x,
          min: -8,
          max: 8,
          onChanged: (next) => onChanged(Offset3(next, value.y, value.z)),
        ),
        _TuningSlider(
          label: 'Y',
          value: value.y,
          min: -1,
          max: 8,
          onChanged: (next) => onChanged(Offset3(value.x, next, value.z)),
        ),
        _TuningSlider(
          label: 'Z',
          value: value.z,
          min: -8,
          max: 8,
          onChanged: (next) => onChanged(Offset3(value.x, value.y, next)),
        ),
      ],
    );
  }
}

class _RgbEditor extends StatelessWidget {
  const _RgbEditor({
    required this.title,
    required this.colorHex,
    required this.onChanged,
  });

  final String title;
  final int colorHex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = (colorHex >> 16) & 0xFF;
    final g = (colorHex >> 8) & 0xFF;
    final b = colorHex & 0xFF;
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0x14B68454),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6A5645),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Color(0xFF000000 | colorHex),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0x33000000)),
                ),
              ),
            ],
          ),
          _TuningSlider(
            label: 'R',
            value: r.toDouble(),
            min: 0,
            max: 255,
            onChanged: (v) {
              onChanged(((v.round() & 0xFF) << 16) | (g << 8) | b);
            },
          ),
          _TuningSlider(
            label: 'G',
            value: g.toDouble(),
            min: 0,
            max: 255,
            onChanged: (v) {
              onChanged((r << 16) | ((v.round() & 0xFF) << 8) | b);
            },
          ),
          _TuningSlider(
            label: 'B',
            value: b.toDouble(),
            min: 0,
            max: 255,
            onChanged: (v) {
              onChanged((r << 16) | (g << 8) | (v.round() & 0xFF));
            },
          ),
        ],
      ),
    );
  }
}

class _CaptureCopy {
  static const pageTitle = '小闲围棋';

  static const _subtitles = [
    '围棋让我放松',
    '下棋使我更平静',
    '我在这里是专注的',
    '每一步都值得深思',
    '棋盘上只有当下',
    '落子无悔，心平气和',
    '围棋教会我耐心',
    '在这里，我找到专注',
    '下棋让我忘记烦恼',
    '一盘棋，一段宁静',
    '每手棋都是一次思考',
    '围棋是我的冥想',
    '在棋盘上，心绪沉静',
    '下一步，只看眼前',
    '围棋让我学会等待',
    '棋局如人生，从容应对',
    '落子一刻，万虑皆空',
    '下棋让我更专注',
    '围棋是内心的修炼',
    '在这里找到自己的节奏',
    '每盘棋都是新的开始',
    '棋盘上，时间慢了下来',
    '围棋让我与自己对话',
    '下棋时，世界变得安静',
    '棋局中学会取舍',
    '围棋给我带来平静',
    '每一步都有它的意义',
    '在棋盘上感受专注的力量',
    '围棋让我享受思考的过程',
    '落子时，心无杂念',
    '围棋是我放松的方式',
    '黑白之间，只有当下',
    '围棋教会我谦逊',
    '每次落子都是一次成长',
    '在这里，我可以慢下来',
    '下棋让思绪变得清晰',
    '围棋让我学会专注于当下',
    '棋局中，找到内心的平衡',
    '一子一子，皆是修行',
    '围棋让我感到愉悦',
    '棋盘上，输赢都是收获',
    '下棋使我沉淀下来',
    '围棋是一种心灵的放空',
    '每一盘棋都是一段旅程',
    '在棋局中找到宁静',
    '围棋让我学会了坚持',
    '落子之间，感受当下',
    '围棋让心绪安定',
    '棋盘是我思考的空间',
    '下棋，让我更了解自己',
  ];

  static const _millisecondsPerHour = 1000 * 3600;

  /// Returns a subtitle that is stable within the same hour but rotates
  /// across hours, using hours-since-epoch as the seed so the same clock
  /// hour on different days shows different sentences.
  static String get pageSubtitle {
    final hoursSinceEpoch =
        DateTime.now().millisecondsSinceEpoch ~/ _millisecondsPerHour;
    final index = Random(hoursSinceEpoch).nextInt(_subtitles.length);
    return _subtitles[index];
  }

  static const startAsBlackButton = '执黑先行';
  static const startAsWhiteButton = '执白后行';
  static const startSetupButton = '开始';
}

String _initialModeLabel(CaptureInitialMode mode) {
  return mode.label;
}

extension _CaptureInitialModeLabelExt on CaptureInitialMode {
  String get label {
    return switch (this) {
      CaptureInitialMode.twistCross => '扭十字',
      CaptureInitialMode.empty => '空白',
      CaptureInitialMode.setup => '摆棋',
    };
  }
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

class _PracticeHeader extends StatelessWidget {
  const _PracticeHeader({
    required this.title,
    required this.subtitle,
    required this.isAdjusting,
    required this.onAdjustTap,
  });

  final String title;
  final String subtitle;
  final bool isAdjusting;
  final VoidCallback onAdjustTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A2A1F),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8C7966),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(44, 44),
          onPressed: onAdjustTap,
          child: Text(
            isAdjusting ? '完成' : '调整 ›',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB68454),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfigPreview extends StatelessWidget {
  const _ConfigPreview({
    required this.boardSize,
    required this.difficulty,
    required this.initialMode,
  });

  final int boardSize;
  final DifficultyLevel difficulty;
  final CaptureInitialMode initialMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x26D8C1A4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ConfigPreviewItem(
              icon: CupertinoIcons.circle_grid_3x3_fill,
              label: '$boardSize 路',
            ),
          ),
          const _ConfigPreviewDivider(),
          Expanded(
            child: _ConfigPreviewItem(
              icon: CupertinoIcons.triangle_fill,
              label: difficulty.displayName,
            ),
          ),
          const _ConfigPreviewDivider(),
          Expanded(
            child: _ConfigPreviewItem(
              icon: CupertinoIcons.circle_grid_3x3_fill,
              label: _initialModeLabel(initialMode),
            ),
          ),
          const _ConfigPreviewDivider(),
          Expanded(
            child: _ConfigPreviewItem(
              icon: CupertinoIcons.star_fill,
              label: CaptureAiStyle.hunter.label,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigPreviewItem extends StatelessWidget {
  const _ConfigPreviewItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F0E3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Color(0xFFB68454)),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF36271E),
          ),
        ),
      ],
    );
  }
}

class _ConfigPreviewDivider extends StatelessWidget {
  const _ConfigPreviewDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 68,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0x1ED2B28E),
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

class _ImportScreenshotCard extends StatelessWidget {
  const _ImportScreenshotCard({
    required this.onTap,
    required this.isLoading,
  });

  final VoidCallback? onTap;
  final bool isLoading;

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
                color: const Color(0xFFECE4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: isLoading
                  ? const CupertinoActivityIndicator(radius: 10)
                  : const Icon(
                      CupertinoIcons.photo_on_rectangle,
                      color: Color(0xFF7A63C8),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading ? '识别中...' : '导入截屏摆棋',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF36271E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '自动识别棋盘和棋子，预览后微调进入摆棋',
                    style: TextStyle(
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

class _ImportBoardDraft {
  const _ImportBoardDraft({
    required this.boardSize,
    required this.board,
  });

  final int boardSize;
  final List<List<StoneColor>> board;
}

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
    final gameState = GameState(
      boardSize: _boardSize,
      board: _board,
      currentPlayer: StoneColor.black,
    );
    final confidencePct = (widget.confidence * 100).toStringAsFixed(0);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('截屏识别预览'),
        previousPageTitle: _CaptureCopy.pageTitle,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _startSetup,
          child: const Text('开始摆棋'),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '识别置信度 $confidencePct%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A63C8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '点击棋盘交叉点可循环切换：空 -> 黑 -> 白。确认后进入摆棋模式。',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B5C50)),
                    ),
                    const SizedBox(height: 12),
                    _PillSegmentControl<int>(
                      selectedValue: _boardSize,
                      options: const [
                        _SegmentOption(value: 9, label: '9 路'),
                        _SegmentOption(value: 13, label: '13 路'),
                        _SegmentOption(value: 19, label: '19 路'),
                      ],
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
                  onPressed: _startSetup,
                  child: const Text('进入摆棋模式'),
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

  void _startSetup() {
    Navigator.of(context).pop(
      _ImportBoardDraft(
        boardSize: _boardSize,
        board: _cloneBoard(_board),
      ),
    );
  }

  List<List<StoneColor>> _cloneBoard(List<List<StoneColor>> source) {
    return source.map((row) => List<StoneColor>.from(row)).toList();
  }
}

class CaptureGamePlayScreen extends StatefulWidget {
  const CaptureGamePlayScreen({
    super.key,
    required this.difficulty,
    required this.captureTarget,
    this.humanColor = StoneColor.black,
    this.initialMode = CaptureInitialMode.twistCross,
    this.initialBoardOverride,
  });

  final DifficultyLevel difficulty;
  final int captureTarget;
  final StoneColor humanColor;
  final CaptureInitialMode initialMode;

  /// The initial board passed to the provider (needed to persist the record).
  final List<List<StoneColor>>? initialBoardOverride;

  @override
  State<CaptureGamePlayScreen> createState() => _CaptureGamePlayScreenState();
}

class _CaptureGamePlayScreenState extends State<CaptureGamePlayScreen> {
  List<_HintMark> _hintMarks = const [];
  bool _isLoadingHints = false;
  bool _gameSaved = false;

  final _historyRepo = GameHistoryRepository();

  /// Converts a board of [StoneColor] to a list of int indices.
  static List<List<int>> _boardToInts(List<List<StoneColor>> board) =>
      board.map((row) => row.map((c) => c.index).toList()).toList();

  Future<void> _saveGame(CaptureGameProvider provider) async {
    if (_gameSaved) return;
    if (provider.moveLog.isEmpty) return; // nothing to save
    _gameSaved = true;

    final outcome = switch (provider.result) {
      CaptureGameResult.blackWins =>
        widget.humanColor == StoneColor.black
            ? GameOutcome.humanWins
            : GameOutcome.aiWins,
      CaptureGameResult.whiteWins =>
        widget.humanColor == StoneColor.white
            ? GameOutcome.humanWins
            : GameOutcome.aiWins,
      CaptureGameResult.none => GameOutcome.abandoned,
    };

    final initialBoardCells = widget.initialBoardOverride != null
        ? _boardToInts(widget.initialBoardOverride!)
        : null;

    final now = DateTime.now();
    final record = GameRecord(
      id: now.toIso8601String(),
      playedAt: now,
      boardSize: provider.boardSize,
      captureTarget: provider.captureTarget,
      difficulty: provider.difficulty.name,
      humanColorIndex: widget.humanColor.index,
      initialMode: widget.initialMode.name,
      initialBoardCells: initialBoardCells,
      moves: List<List<int>>.from(
        provider.moveLog.map((m) => List<int>.from(m)),
      ),
      outcome: outcome,
      finalBoard: _boardToInts(provider.gameState.board),
    );
    await _historyRepo.save(record);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        final provider = context.read<CaptureGameProvider>();
        _saveGame(provider);
      },
      child: Consumer<CaptureGameProvider>(
        builder: (context, provider, _) {
          // Auto-save when game finishes.
          if (provider.result != CaptureGameResult.none && !_gameSaved) {
            Future.microtask(() => _saveGame(provider));
          }

          final rates = provider.winRateEstimate;
          final blackRate =
              (rates[StoneColor.black]! * 100).toStringAsFixed(0);
          final whiteRate =
              (rates[StoneColor.white]! * 100).toStringAsFixed(0);
          final blackCaptured = provider.gameState.capturedByBlack.length;
          final whiteCaptured = provider.gameState.capturedByWhite.length;
          final aiThinking = provider.isAiThinking;
          final isFinished = provider.result != CaptureGameResult.none;
          final settings = context.watch<SettingsProvider?>();
          final showCaptureWarning = settings?.showCaptureWarning ?? true;

          return CupertinoPageScaffold(
            backgroundColor: const Color(0xFFF3F0ED),
            navigationBar: CupertinoNavigationBar(
              backgroundColor: const Color(0xFFF3F0ED),
              border: null,
              previousPageTitle: _CaptureCopy.pageTitle,
              middle: Text(
                '${_initialModeLabel(widget.initialMode)} · 吃${widget.captureTarget}子 · ${widget.difficulty.displayName}',
              ),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showGameConfigDialog(
                  context: context,
                  provider: provider,
                  settings: settings,
                ),
                child: const Icon(
                  CupertinoIcons.slider_horizontal_3,
                  color: Color(0xFFC3996E),
                  size: 20,
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
                              showCaptureWarning: showCaptureWarning,
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
                            text: isFinished ? '重下这一手' : '提示一手',
                            filled: true,
                            onPressed: isFinished
                                ? () => _showReplayDialog(context, provider)
                                : (_isLoadingHints
                                    ? null
                                    : () => _showHintsOnBoard(provider)),
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
      ),
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

  void _showReplayDialog(
    BuildContext context,
    CaptureGameProvider provider,
  ) {
    // Capture the root navigator before any pop operations.
    final rootNav = Navigator.of(context, rootNavigator: true);

    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => _ReplaySetupDialog(
        defaultDifficulty: provider.difficulty,
        defaultInitialMode: widget.initialMode,
        hasInitialBoard: widget.initialBoardOverride != null,
        onConfirm: (difficulty, mode) {
          Navigator.of(dialogContext).pop();

          final boardOverride =
              mode == CaptureInitialMode.setup ? widget.initialBoardOverride : null;

          // Pop the current play screen, then push the new game.
          rootNav.pop();
          rootNav.push(
            CupertinoPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => CaptureGameProvider(
                  boardSize: provider.boardSize,
                  captureTarget: provider.captureTarget,
                  difficulty: difficulty,
                  humanColor: widget.humanColor,
                  initialMode: mode,
                  initialBoardOverride: boardOverride,
                ),
                child: CaptureGamePlayScreen(
                  difficulty: difficulty,
                  captureTarget: provider.captureTarget,
                  humanColor: widget.humanColor,
                  initialMode: mode,
                  initialBoardOverride: boardOverride,
                ),
              ),
            ),
          );
        },
      ),
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

  void _showGameConfigDialog({
    required BuildContext context,
    required CaptureGameProvider provider,
    required SettingsProvider? settings,
  }) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('对局配置'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                const Text(
                  '本轮配置',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E7157)),
                ),
                const SizedBox(height: 8),
                _ConfigInfoRow(
                  title: 'AI 风格',
                  value: provider.aiStyle.label,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _showStylePicker(context, provider);
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  '全局配置',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E7157)),
                ),
                const SizedBox(height: 8),
                _ConfigSwitchRow(
                  title: '吃子预警',
                  value: settings?.showCaptureWarning ?? true,
                  onChanged: settings?.setShowCaptureWarning,
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('完成'),
            ),
          ],
        );
      },
    );
  }
}

class _ConfigInfoRow extends StatelessWidget {
  const _ConfigInfoRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, color: Color(0xFF2E2620)),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFC3996E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(CupertinoIcons.chevron_right, size: 15),
        ],
      ),
    );
  }
}

class _ConfigSwitchRow extends StatelessWidget {
  const _ConfigSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, color: Color(0xFF2E2620)),
        ),
        const Spacer(),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
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
    required this.showCaptureWarning,
    required this.onTap,
  });

  final GameState gameState;
  final bool enabled;
  final List<_HintMark> hintMarks;
  final bool showCaptureWarning;
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
                  painter: GoBoardPainter(
                    gameState: gameState,
                    showCaptureWarning: showCaptureWarning,
                  ),
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

// ---------------------------------------------------------------------------
// History section
// ---------------------------------------------------------------------------

/// Section card shown on the home screen listing recent games.
class _HistorySectionCard extends StatelessWidget {
  const _HistorySectionCard({
    required this.history,
    required this.onReplay,
  });

  final List<GameRecord> history;

  /// Called when the user confirms replay from the detail sheet.
  /// Args: (record, difficulty, mode)
  final void Function(
    GameRecord record,
    DifficultyLevel difficulty,
    CaptureInitialMode mode,
  ) onReplay;

  static const _maxVisible = 5;

  @override
  Widget build(BuildContext context) {
    final visible = history.take(_maxVisible).toList();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '历史对局',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A2A1F),
                  ),
                ),
              ),
              if (history.length > _maxVisible)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  onPressed: () => _showAllHistory(context),
                  child: const Text(
                    '全部 ›',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFB68454),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...visible.map(
            (r) => _HistoryRow(
              record: r,
              onTap: () => _showDetailSheet(context, r),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, GameRecord record) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _HistoryDetailSheet(
        record: record,
        onReplay: (difficulty, mode) {
          Navigator.of(ctx).pop();
          onReplay(record, difficulty, mode);
        },
      ),
    );
  }

  void _showAllHistory(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _FullHistoryScreen(
          history: history,
          onReplay: onReplay,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.record,
    required this.onTap,
  });

  final GameRecord record;
  final VoidCallback onTap;

  static const _outcomeColors = {
    GameOutcome.humanWins: Color(0xFF4A7C59),
    GameOutcome.aiWins: Color(0xFF8B3A3A),
    GameOutcome.abandoned: Color(0xFF8C7966),
  };

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(record.playedAt);
    final boardLabel = '${record.boardSize} 路';
    final diffLabel = record.difficultyLevel.displayName;
    final outcomeLabel = record.outcome.displayName;
    final outcomeColor =
        _outcomeColors[record.outcome] ?? const Color(0xFF8C7966);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Row(
        children: [
          _StoneCircle(isBlack: record.humanColorIndex == StoneColor.black.index),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$boardLabel · $diffLabel · ${record.totalMoves} 手',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A2A1F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF897564),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              outcomeLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: outcomeColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            CupertinoIcons.chevron_right,
            color: Color(0xFFCBAF8C),
            size: 14,
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '今天 ${_pad(dt.hour)}:${_pad(dt.minute)}';
    if (diff.inDays == 1) return '昨天 ${_pad(dt.hour)}:${_pad(dt.minute)}';
    return '${dt.month}/${dt.day} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

class _StoneCircle extends StatelessWidget {
  const _StoneCircle({required this.isBlack});

  final bool isBlack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isBlack ? const Color(0xFF1A1A1A) : const Color(0xFFF5F0E8),
        border: Border.all(
          color: isBlack ? const Color(0xFF3A3A3A) : const Color(0xFFBCA88A),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History detail sheet
// ---------------------------------------------------------------------------

class _HistoryDetailSheet extends StatelessWidget {
  const _HistoryDetailSheet({
    required this.record,
    required this.onReplay,
  });

  final GameRecord record;
  final void Function(DifficultyLevel difficulty, CaptureInitialMode mode)
      onReplay;

  @override
  Widget build(BuildContext context) {
    final boardState = _buildFinalBoardState(record);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F4EC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x33B68454),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${record.boardSize} 路 · 吃${record.captureTarget}子 · ${record.difficultyLevel.displayName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3A2A1F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFullDate(record.playedAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8C7966),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _OutcomeBadge(outcome: record.outcome),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (boardState != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0DFC9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GoBoardWidget(
                        gameState: boardState,
                        onTap: null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '共 ${record.totalMoves} 手',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8C7966),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _PrimaryActionButton(
                title: '重下这一手',
                onPressed: () => _promptReplay(context),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  void _promptReplay(BuildContext context) {
    // Show the replay dialog on top of the sheet; then close both when confirmed.
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => _ReplaySetupDialog(
        defaultDifficulty: record.difficultyLevel,
        defaultInitialMode: CaptureInitialMode.values.firstWhere(
          (m) => m.name == record.initialMode,
          orElse: () => CaptureInitialMode.twistCross,
        ),
        hasInitialBoard: record.initialBoardCells != null,
        onConfirm: (difficulty, mode) {
          Navigator.of(ctx).pop(); // close the dialog
          Navigator.of(context).pop(); // close the detail sheet
          onReplay(difficulty, mode);
        },
      ),
    );
  }

  static String _formatFullDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static GameState? _buildFinalBoardState(GameRecord record) {
    final fb = record.finalBoard;
    if (fb == null) return null;
    try {
      final board = fb
          .map((row) => row
              .map((i) =>
                  StoneColor.values[i.clamp(0, StoneColor.values.length - 1)])
              .toList())
          .toList();
      return GameState(
        boardSize: record.boardSize,
        board: board,
        currentPlayer: StoneColor.black,
      );
    } catch (_) {
      return null;
    }
  }
}

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({required this.outcome});

  final GameOutcome outcome;

  static const _bgColors = {
    GameOutcome.humanWins: Color(0xFFE6F4EC),
    GameOutcome.aiWins: Color(0xFFF9E6E6),
    GameOutcome.abandoned: Color(0xFFF0EAE2),
  };

  static const _fgColors = {
    GameOutcome.humanWins: Color(0xFF3D7A56),
    GameOutcome.aiWins: Color(0xFF8B3A3A),
    GameOutcome.abandoned: Color(0xFF7A6A5A),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColors[outcome],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        outcome.displayName,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _fgColors[outcome],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full history screen
// ---------------------------------------------------------------------------

class _FullHistoryScreen extends StatelessWidget {
  const _FullHistoryScreen({
    required this.history,
    required this.onReplay,
  });

  final List<GameRecord> history;
  final void Function(
    GameRecord record,
    DifficultyLevel difficulty,
    CaptureInitialMode mode,
  ) onReplay;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kPageBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('历史对局'),
        previousPageTitle: '小闲围棋',
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: history.length,
          separatorBuilder: (_, __) => Container(
            height: 0.5,
            color: const Color(0x26D8C1A4),
          ),
          itemBuilder: (ctx, i) {
            final r = history[i];
            return _HistoryRow(
              record: r,
              onTap: () => showCupertinoModalPopup<void>(
                context: ctx,
                builder: (_) => _HistoryDetailSheet(
                  record: r,
                  onReplay: (difficulty, mode) {
                    // The detail sheet has already been popped by _promptReplay.
                    Navigator.of(ctx).pop(); // close the full history screen
                    onReplay(r, difficulty, mode);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Replay setup dialog
// ---------------------------------------------------------------------------

/// A dialog that lets the user choose difficulty and initial mode before
/// replaying a recorded game.
class _ReplaySetupDialog extends StatefulWidget {
  const _ReplaySetupDialog({
    required this.defaultDifficulty,
    required this.defaultInitialMode,
    required this.hasInitialBoard,
    required this.onConfirm,
  });

  final DifficultyLevel defaultDifficulty;
  final CaptureInitialMode defaultInitialMode;

  /// Whether the original record had an `initialBoardOverride`.
  final bool hasInitialBoard;

  final void Function(DifficultyLevel difficulty, CaptureInitialMode mode)
      onConfirm;

  @override
  State<_ReplaySetupDialog> createState() => _ReplaySetupDialogState();
}

class _ReplaySetupDialogState extends State<_ReplaySetupDialog> {
  late DifficultyLevel _difficulty;
  late bool _usePlacementMode;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.defaultDifficulty;
    _usePlacementMode =
        widget.defaultInitialMode == CaptureInitialMode.setup;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('重下这一手'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI 难度',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8E7157),
              ),
            ),
            const SizedBox(height: 8),
            CupertinoSlidingSegmentedControl<DifficultyLevel>(
              groupValue: _difficulty,
              children: {
                for (final d in DifficultyLevel.values)
                  d: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    child: Text(
                      d.displayName,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              },
              onValueChanged: (v) {
                if (v != null) setState(() => _difficulty = v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '摆棋模式',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2E2620),
                    ),
                  ),
                ),
                CupertinoSwitch(
                  value: _usePlacementMode,
                  activeTrackColor: const Color(0xFFB68454),
                  onChanged: (v) => setState(() => _usePlacementMode = v),
                ),
              ],
            ),
            if (_usePlacementMode && widget.hasInitialBoard)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '将使用原始棋盘布局进入摆棋模式',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8C7A6A)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          isDestructiveAction: true,
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            final mode = _usePlacementMode
                ? CaptureInitialMode.setup
                : (widget.defaultInitialMode == CaptureInitialMode.setup
                    ? CaptureInitialMode.twistCross
                    : widget.defaultInitialMode);
            widget.onConfirm(_difficulty, mode);
          },
          child: const Text('开始'),
        ),
      ],
    );
  }
}
