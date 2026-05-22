import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/board_image_recognizer.dart';
import '../game/model_board_image_recognizer.dart';
import '../game/ai_algorithm_framework.dart';
import '../game/capture_ai.dart';
import '../game/ai_rank_level.dart';
import '../game/game_mode.dart';
import '../game/go_engine.dart';
import '../game/katago_flutter_onnx_model_adapter.dart';
import '../game/katago_model_adapter.dart';
import '../game/mcts_engine.dart';
import '../models/board_position.dart';
import '../models/game_record.dart';
import '../models/game_state.dart';
import '../providers/capture_game_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_log_store.dart';
import '../services/game_history_repository.dart';
import '../services/player_rank_repository.dart';
import '../theme/app_theme.dart';
import '../theme/theme_context.dart';
import '../ui/board_coordinates.dart';
import '../widgets/go_board_widget.dart';
import '../widgets/go_three_board_background.dart';
import '../widgets/page_hero_banner.dart';

class CaptureGameScreen extends StatefulWidget {
  const CaptureGameScreen({
    super.key,
    this.leafShadowEnabled,
    this.leafShadowOpacity,
    this.leafShadowSpeed,
    this.leafShadowDrift,
    this.leafShadowRotation,
    this.leafShadowScale,
    this.leafShadowOffsetX,
    this.leafShadowOffsetZ,
    this.onLeafShadowEnabledChanged,
    this.onLeafShadowOpacityChanged,
    this.onLeafShadowSpeedChanged,
    this.onLeafShadowDriftChanged,
    this.onLeafShadowRotationChanged,
    this.onLeafShadowScaleChanged,
    this.onLeafShadowOffsetXChanged,
    this.onLeafShadowOffsetZChanged,
  });

  final bool? leafShadowEnabled;
  final double? leafShadowOpacity;
  final double? leafShadowSpeed;
  final double? leafShadowDrift;
  final double? leafShadowRotation;
  final double? leafShadowScale;
  final double? leafShadowOffsetX;
  final double? leafShadowOffsetZ;
  final ValueChanged<bool>? onLeafShadowEnabledChanged;
  final ValueChanged<double>? onLeafShadowOpacityChanged;
  final ValueChanged<double>? onLeafShadowSpeedChanged;
  final ValueChanged<double>? onLeafShadowDriftChanged;
  final ValueChanged<double>? onLeafShadowRotationChanged;
  final ValueChanged<double>? onLeafShadowScaleChanged;
  final ValueChanged<double>? onLeafShadowOffsetXChanged;
  final ValueChanged<double>? onLeafShadowOffsetZChanged;

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
  bool _leafShadowEnabled = _CaptureGameScreenState._defaultLeafShadowEnabled;
  double _leafShadowOpacity = _CaptureGameScreenState._defaultLeafShadowOpacity;
  double _leafShadowSpeed = _CaptureGameScreenState._defaultLeafShadowSpeed;
  double _leafShadowDrift = _CaptureGameScreenState._defaultLeafShadowDrift;
  double _leafShadowRotation =
      _CaptureGameScreenState._defaultLeafShadowRotation;
  double _leafShadowScale = _CaptureGameScreenState._defaultLeafShadowScale;
  double _leafShadowOffsetX = _CaptureGameScreenState._defaultLeafShadowOffsetX;
  double _leafShadowOffsetZ = _CaptureGameScreenState._defaultLeafShadowOffsetZ;
  bool _stoneExtraOverlayEnabled =
      _CaptureGameScreenState._defaultStoneExtraOverlayEnabled;
  bool _cornerLabelsEnabled =
      _CaptureGameScreenState._defaultCornerLabelsEnabled;
  double _boardTopBrightness =
      _CaptureGameScreenState._defaultBoardTopBrightness;
  int _boardWoodColor = _CaptureGameScreenState._defaultBoardWoodColor;
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
  double _windowPlateau = _CaptureGameScreenState._defaultWindowPlateau;
  double _windowFalloff = _CaptureGameScreenState._defaultWindowFalloff;
  double _windowRotation = _CaptureGameScreenState._defaultWindowRotation;
  // Grid dissolution controls
  double _gridBaseOpacity = _CaptureGameScreenState._defaultGridBaseOpacity;
  double _gridFadeMult = _CaptureGameScreenState._defaultGridFadeMult;
  double _gridFadePower = _CaptureGameScreenState._defaultGridFadePower;
  double _gridFadeMin = _CaptureGameScreenState._defaultGridFadeMin;
  double _lightMapFloor = _CaptureGameScreenState._defaultLightMapFloor;
  double _lightMapIntensity = _CaptureGameScreenState._defaultLightMapIntensity;

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
                  leafShadowEnabled: _leafShadowEnabled,
                  leafShadowOpacity: _leafShadowOpacity,
                  leafShadowSpeed: _leafShadowSpeed,
                  leafShadowDrift: _leafShadowDrift,
                  leafShadowRotation: _leafShadowRotation,
                  leafShadowScale: _leafShadowScale,
                  leafShadowOffsetX: _leafShadowOffsetX,
                  leafShadowOffsetZ: _leafShadowOffsetZ,
                  stoneExtraOverlayEnabled: _stoneExtraOverlayEnabled,
                  cornerLabelsEnabled: _cornerLabelsEnabled,
                  boardTopBrightness: _boardTopBrightness,
                  boardWoodColor: _boardWoodColor,
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
                  showDebugGuides: _panelVisible,
                  windowCenterU: _windowCenterU,
                  windowCenterV: _windowCenterV,
                  windowSpreadU: _windowSpreadU,
                  windowSpreadV: _windowSpreadV,
                  windowPlateau: _windowPlateau,
                  windowFalloff: _windowFalloff,
                  windowRotation: _windowRotation,
                  gridBaseOpacity: _gridBaseOpacity,
                  gridFadeMult: _gridFadeMult,
                  gridFadePower: _gridFadePower,
                  gridFadeMin: _gridFadeMin,
                  lightMapFloor: _lightMapFloor,
                  lightMapIntensity: _lightMapIntensity,
                ),
                if (_panelVisible)
                  _HomeBoardTuningSheet(
                    leafShadowEnabled: _leafShadowEnabled,
                    shadowOpacity: _leafShadowOpacity,
                    leafShadowSpeed: _leafShadowSpeed,
                    leafShadowDrift: _leafShadowDrift,
                    leafShadowRotation: _leafShadowRotation,
                    leafShadowScale: _leafShadowScale,
                    leafShadowOffsetX: _leafShadowOffsetX,
                    leafShadowOffsetZ: _leafShadowOffsetZ,
                    stoneExtraOverlayEnabled: _stoneExtraOverlayEnabled,
                    cornerLabelsEnabled: _cornerLabelsEnabled,
                    boardTopBrightness: _boardTopBrightness,
                    boardWoodColor: _boardWoodColor,
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
                    onLeafShadowEnabledChanged: (value) =>
                        setState(() => _leafShadowEnabled = value),
                    onShadowOpacityChanged: (value) =>
                        setState(() => _leafShadowOpacity = value),
                    onLeafShadowSpeedChanged: (value) =>
                        setState(() => _leafShadowSpeed = value),
                    onLeafShadowDriftChanged: (value) =>
                        setState(() => _leafShadowDrift = value),
                    onLeafShadowRotationChanged: (value) =>
                        setState(() => _leafShadowRotation = value),
                    onLeafShadowScaleChanged: (value) =>
                        setState(() => _leafShadowScale = value),
                    onLeafShadowOffsetXChanged: (value) =>
                        setState(() => _leafShadowOffsetX = value),
                    onLeafShadowOffsetZChanged: (value) =>
                        setState(() => _leafShadowOffsetZ = value),
                    onStoneExtraOverlayChanged: (value) =>
                        setState(() => _stoneExtraOverlayEnabled = value),
                    onCornerLabelsChanged: (value) =>
                        setState(() => _cornerLabelsEnabled = value),
                    onBoardTopBrightnessChanged: (value) =>
                        setState(() => _boardTopBrightness = value),
                    onBoardWoodColorChanged: (value) =>
                        setState(() => _boardWoodColor = value),
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
                    windowPlateau: _windowPlateau,
                    windowFalloff: _windowFalloff,
                    windowRotation: _windowRotation,
                    gridBaseOpacity: _gridBaseOpacity,
                    gridFadeMult: _gridFadeMult,
                    gridFadePower: _gridFadePower,
                    gridFadeMin: _gridFadeMin,
                    lightMapFloor: _lightMapFloor,
                    lightMapIntensity: _lightMapIntensity,
                    onWindowCenterUChanged: (v) =>
                        setState(() => _windowCenterU = v),
                    onWindowCenterVChanged: (v) =>
                        setState(() => _windowCenterV = v),
                    onWindowSpreadUChanged: (v) =>
                        setState(() => _windowSpreadU = v),
                    onWindowSpreadVChanged: (v) =>
                        setState(() => _windowSpreadV = v),
                    onWindowPlateauChanged: (v) =>
                        setState(() => _windowPlateau = v),
                    onWindowFalloffChanged: (v) =>
                        setState(() => _windowFalloff = v),
                    onWindowRotationChanged: (v) =>
                        setState(() => _windowRotation = v),
                    onGridBaseOpacityChanged: (v) =>
                        setState(() => _gridBaseOpacity = v),
                    onGridFadeMultChanged: (v) =>
                        setState(() => _gridFadeMult = v),
                    onGridFadePowerChanged: (v) =>
                        setState(() => _gridFadePower = v),
                    onGridFadeMinChanged: (v) =>
                        setState(() => _gridFadeMin = v),
                    onLightMapFloorChanged: (v) =>
                        setState(() => _lightMapFloor = v),
                    onLightMapIntensityChanged: (v) =>
                        setState(() => _lightMapIntensity = v),
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
      _leafShadowEnabled = _CaptureGameScreenState._defaultLeafShadowEnabled;
      _leafShadowOpacity = _CaptureGameScreenState._defaultLeafShadowOpacity;
      _leafShadowSpeed = _CaptureGameScreenState._defaultLeafShadowSpeed;
      _leafShadowDrift = _CaptureGameScreenState._defaultLeafShadowDrift;
      _leafShadowRotation = _CaptureGameScreenState._defaultLeafShadowRotation;
      _leafShadowScale = _CaptureGameScreenState._defaultLeafShadowScale;
      _leafShadowOffsetX = _CaptureGameScreenState._defaultLeafShadowOffsetX;
      _leafShadowOffsetZ = _CaptureGameScreenState._defaultLeafShadowOffsetZ;
      _stoneExtraOverlayEnabled =
          _CaptureGameScreenState._defaultStoneExtraOverlayEnabled;
      _cornerLabelsEnabled =
          _CaptureGameScreenState._defaultCornerLabelsEnabled;
      _boardTopBrightness = _CaptureGameScreenState._defaultBoardTopBrightness;
      _boardWoodColor = _CaptureGameScreenState._defaultBoardWoodColor;
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
      _windowPlateau = _CaptureGameScreenState._defaultWindowPlateau;
      _windowFalloff = _CaptureGameScreenState._defaultWindowFalloff;
      _windowRotation = _CaptureGameScreenState._defaultWindowRotation;
      _gridBaseOpacity = _CaptureGameScreenState._defaultGridBaseOpacity;
      _gridFadeMult = _CaptureGameScreenState._defaultGridFadeMult;
      _gridFadePower = _CaptureGameScreenState._defaultGridFadePower;
      _gridFadeMin = _CaptureGameScreenState._defaultGridFadeMin;
      _lightMapFloor = _CaptureGameScreenState._defaultLightMapFloor;
      _lightMapIntensity = _CaptureGameScreenState._defaultLightMapIntensity;
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

enum _ModelLoadDecision {
  ready,
  useRules,
}

/// Returned from [CaptureGamePlayScreen] when the user forks from review mode.
/// The home screen receives this via `Navigator.pop` and immediately starts a
/// new game with the forked board — ensuring `_loadHistory` is called when
/// both the original AND the forked game complete.
class _ForkRequest {
  const _ForkRequest({
    required this.initialBoardOverride,
    required this.initialPlayerOverride,
    required this.inheritedMoves,
    required this.inheritedMarkedMoveNumbers,
    required this.boardSize,
    required this.captureTarget,
    required this.difficulty,
    required this.gameMode,
    required this.humanColor,
    required this.aiStyle,
    required this.aiAlgorithmConfigId,
    required this.aiRank,
    required this.initialMode,
  });

  final List<List<StoneColor>>? initialBoardOverride;
  final StoneColor? initialPlayerOverride;
  final List<List<int>> inheritedMoves;
  final Set<int> inheritedMarkedMoveNumbers;
  final int boardSize;
  final int captureTarget;
  final DifficultyLevel difficulty;
  final GameMode gameMode;
  final StoneColor humanColor;
  final CaptureAiStyle aiStyle;
  final String? aiAlgorithmConfigId;
  final int aiRank;
  final CaptureInitialMode initialMode;
}

class _CaptureGameScreenState extends State<CaptureGameScreen> {
  static const double _defaultHomeBoardTopFactor = 0.06;
  static const double _defaultHomeBoardHeightFactor = 0.62;
  static const double _defaultHomeBoardCanvasYOffset = -128.0;
  static const double _defaultHomeBoardSceneScale = 0.88;
  static const double _defaultHomeBoardCameraLift = 0.01;
  static const double _defaultHomeBoardCameraDepth = 17.2;
  static const double _defaultHomeBoardTargetZOffset = 0.0;
  static const double _defaultHomeBoardCinematicFov = 28.0;
  static const double _defaultHomeBoardRotationY = -0.62;
  static const bool _defaultLeafShadowEnabled = true;
  static const double _defaultLeafShadowOpacity = 0.16;
  static const double _defaultLeafShadowSpeed = 0.05;
  static const double _defaultLeafShadowDrift = 0.14;
  static const double _defaultLeafShadowRotation = 0.19;
  static const double _defaultLeafShadowScale = 1.65;
  static const double _defaultLeafShadowOffsetX = -1.38;
  static const double _defaultLeafShadowOffsetZ = -2.0;
  static const bool _defaultStoneExtraOverlayEnabled = true;
  static const bool _defaultCornerLabelsEnabled = false;
  static const double _defaultBoardTopBrightness = 1.0;
  static const int _defaultBoardWoodColor = 0xd0b39c;
  static const double _defaultToneMappingExposure = 0.44;
  static const Offset3 _defaultKeyLightPosition = Offset3(5.5, 5.5, 5.5);
  static const Offset3 _defaultFillLightPosition = Offset3(-4.8, 2.2, 3.2);
  static const double _defaultKeyLightIntensity = 1.44;
  static const double _defaultFillLightIntensity = 0.09;
  static const double _defaultAmbientLightIntensity = 0.15;
  static const double _defaultSheenLightIntensity = 0.14;
  static const int _defaultKeyLightColor = 0xfff0d2;
  static const int _defaultFillLightColor = 0xf4e8d8;
  static const int _defaultAmbientLightColor = 0xffeddc;
  static const int _defaultSheenLightColor = 0xfffaed;
  // Window irradiance defaults
  static const double _defaultWindowCenterU = 0.89;
  static const double _defaultWindowCenterV = 0.43;
  static const double _defaultWindowSpreadU = 1.17;
  static const double _defaultWindowSpreadV = 3.64;
  static const double _defaultWindowPlateau = 0.73;
  static const double _defaultWindowFalloff = 0.97;
  static const double _defaultWindowRotation = 0.39;
  // Grid dissolution defaults
  static const double _defaultGridBaseOpacity = 0.78;
  static const double _defaultGridFadeMult = 0.00;
  static const double _defaultGridFadePower = 0.66;
  static const double _defaultGridFadeMin = 0.20;
  static const double _defaultLightMapFloor = 0.12;
  static const double _defaultLightMapIntensity = 1.49;

  // ── SharedPreferences keys ──────────────────────────────────────────────────
  // Legacy key (read once for migration, then ignored).
  static const _legacyDifficultyKey = 'capture_setup.difficulty';
  static const _boardSizeKey = 'capture_setup.board_size';
  static const _initialModeKey = 'capture_setup.initial_mode';
  // New difficulty keys.
  static const _difficultyModeKey = 'capture_setup.difficulty_mode';
  static const _manualRankKey = 'capture_setup.manual_rank';
  static const _aiAlgorithmConfigKey = 'capture_setup.ai_algorithm_config';
  static const _territoryAiAlgorithmConfigKey =
      'capture_setup.territory_ai_algorithm_config';
  static const _playModeKey = 'capture_setup.play_mode';
  // ─────────────────────────────────────────────────────────────────────────────
  static const _captureTarget = 5;

  static const _modeCapture = 'capture';
  static const _modeTerritory = 'territory';
  static const _defaultDifficultyMode = 'manual';
  static const _defaultAiAlgorithmConfigId = 'mcts_counter_standard_v1';

  /// 'auto' = system chooses a comparable opponent from history rank;
  /// 'manual' = player picks a named real algorithm config.
  String _difficultyMode = _defaultDifficultyMode;

  /// Selected real algorithm-strength config when [_difficultyMode] == 'manual'.
  String _aiAlgorithmConfigId = _defaultAiAlgorithmConfigId;
  String _territoryAiAlgorithmConfigId = 'katago_onnx_standard_v1';

  /// Rank computed from recent history; refreshed on [_restoreSelection].
  int _computedRank = AiRankLevel.defaultRank;
  int _boardSize = 9;
  String _playMode = _modeCapture;
  CaptureInitialMode _initialMode = CaptureInitialMode.cross;
  bool _isAdjusting = false;
  bool _isRecognizingScreenshot = false;
  bool _isPreparingKatago = false;
  bool _homeTuningSheetVisible = false;
  final _homeScrollController = ScrollController();
  final _motivationHeroKey = GlobalKey<_MotivationHeroTitleState>();
  bool _heroTapProxyEnabled = true;

  final _historyRepo = GameHistoryRepository();
  List<GameRecord> _history = const [];
  double _homeBoardTopFactor = _defaultHomeBoardTopFactor;
  double _homeBoardHeightFactor = _defaultHomeBoardHeightFactor;
  double _homeBoardCanvasYOffset = _defaultHomeBoardCanvasYOffset;
  double _homeBoardSceneScale = _defaultHomeBoardSceneScale;
  double _homeBoardCameraLift = _defaultHomeBoardCameraLift;
  double _homeBoardCameraDepth = _defaultHomeBoardCameraDepth;

  AiAlgorithmConfig? get _selectedAiAlgorithmConfig {
    final options = _playableAiOpponentOptionsForMode(_selectedGameMode);
    if (_difficultyMode == 'manual') {
      final selectedId = _isTerritoryMode
          ? _territoryAiAlgorithmConfigId
          : _aiAlgorithmConfigId;
      return options.map((option) => option.config).firstWhere(
            (config) => config.id == selectedId,
            orElse: () => options.first.config,
          );
    }
    if (_isTerritoryMode) {
      return _territoryAiAlgorithmConfigForRank(_computedRank);
    }
    return _aiAlgorithmConfigForRank(_computedRank);
  }

  double _homeBoardTargetZOffset = _defaultHomeBoardTargetZOffset;
  double _homeBoardCinematicFov = _defaultHomeBoardCinematicFov;
  double _homeBoardRotationY = _defaultHomeBoardRotationY;
  bool _leafShadowEnabled = _defaultLeafShadowEnabled;
  double _leafShadowOpacity = _defaultLeafShadowOpacity;
  double _leafShadowSpeed = _defaultLeafShadowSpeed;
  double _leafShadowDrift = _defaultLeafShadowDrift;
  double _leafShadowRotation = _defaultLeafShadowRotation;
  double _leafShadowScale = _defaultLeafShadowScale;
  double _leafShadowOffsetX = _defaultLeafShadowOffsetX;
  double _leafShadowOffsetZ = _defaultLeafShadowOffsetZ;
  bool _stoneExtraOverlayEnabled = _defaultStoneExtraOverlayEnabled;
  bool _cornerLabelsEnabled = _defaultCornerLabelsEnabled;
  double _boardTopBrightness = _defaultBoardTopBrightness;
  int _boardWoodColor = _defaultBoardWoodColor;
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
  double _windowPlateau = _defaultWindowPlateau;
  double _windowFalloff = _defaultWindowFalloff;
  double _windowRotation = _defaultWindowRotation;
  double _gridBaseOpacity = _defaultGridBaseOpacity;
  double _gridFadeMult = _defaultGridFadeMult;
  double _gridFadePower = _defaultGridFadePower;
  double _gridFadeMin = _defaultGridFadeMin;
  double _lightMapFloor = _defaultLightMapFloor;
  double _lightMapIntensity = _defaultLightMapIntensity;

  @override
  void initState() {
    super.initState();
    _homeScrollController.addListener(_syncHeroTapProxy);
    _restoreSelection();
    _loadHistory();
  }

  @override
  void dispose() {
    _homeScrollController
      ..removeListener(_syncHeroTapProxy)
      ..dispose();
    super.dispose();
  }

  void _syncHeroTapProxy() {
    final shouldEnable = !_homeScrollController.hasClients ||
        _homeScrollController.offset < _MotivationHeroTitle.height;
    if (shouldEnable == _heroTapProxyEnabled) return;
    setState(() => _heroTapProxyEnabled = shouldEnable);
  }

  @override
  Widget build(BuildContext context) {
    final developerMode = context.select<SettingsProvider?, bool>(
      (settings) => settings?.developerMode ?? false,
    );
    final showsSharedBoard = context.select<SettingsProvider?, bool>(
      (settings) => settings?.appTheme.showsSharedBoard ?? true,
    );

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const regularCardTop = kPageHeroContentOffset + 8;
            const boardRevealCardTop = regularCardTop * 2;
            final cardTop =
                showsSharedBoard ? boardRevealCardTop : regularCardTop;
            final heroTitleTop = MediaQuery.of(context).padding.top + 36;
            // Let the scrollable content cover the hero title while scrolling.
            // The spacer preserves the first card's resting position.
            final adjustedCardTop =
                cardTop + MediaQuery.of(context).padding.top;

            return Stack(
              children: [
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: PageHeroBanner(
                    title: _CaptureCopy.pageTitle,
                    titleWidget: SizedBox.shrink(),
                    showOrbitalArt: false,
                  ),
                ),
                Positioned(
                  top: heroTitleTop,
                  left: 24,
                  right: 16,
                  child: _MotivationHeroTitle(
                    key: _motivationHeroKey,
                    title: _CaptureCopy.pageTitle,
                    motivation: _CaptureCopy.motivation,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: CustomScrollView(
                      controller: _homeScrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(height: adjustedCardTop),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _OuterSectionTitle(
                                  title: '下一盤',
                                  isVisible: false,
                                ),
                                const SizedBox(height: 8),
                                _SectionCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _PracticeHeader(
                                        title: _selectedModeTitle,
                                        isAdjusting: _isAdjusting,
                                        onAdjustTap: () => setState(
                                          () => _isAdjusting = !_isAdjusting,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      if (_isAdjusting) ...[
                                        const _SectionLabel(title: '模式'),
                                        const SizedBox(height: 4),
                                        _PillSegmentControl<String>(
                                          selectedValue: _playMode,
                                          options: [
                                            _SegmentOption(
                                              value: _modeCapture,
                                              label: _captureModeSegmentLabel,
                                            ),
                                            const _SegmentOption(
                                              value: _modeTerritory,
                                              label: '圍空',
                                            ),
                                          ],
                                          onChanged: (value) =>
                                              _updateSelection(playMode: value),
                                        ),
                                        const SizedBox(height: 8),
                                        _ModeHintText(
                                          text: _playMode == _modeTerritory
                                              ? '圍空模式為真實數子對局：雙方連續停一手後按地盤結算。'
                                              : '吃子模式仍為先吃 $_captureTarget 子取勝。',
                                        ),
                                        const SizedBox(height: 20),
                                        const _SectionLabel(title: 'AI 棋力'),
                                        const SizedBox(height: 8),
                                        _PillSegmentControl<String>(
                                          selectedValue: _difficultyMode,
                                          options: const [
                                            _SegmentOption(
                                              value: 'auto',
                                              label: '不分伯仲',
                                            ),
                                            _SegmentOption(
                                              value: 'manual',
                                              label: '指定棋手',
                                            ),
                                          ],
                                          onChanged: (value) =>
                                              _updateSelection(
                                                  difficultyMode: value),
                                        ),
                                        if (_difficultyMode == 'manual') ...[
                                          const SizedBox(height: 8),
                                          _AiOpponentTile(
                                            selectedConfigId: _isTerritoryMode
                                                ? _territoryAiAlgorithmConfigId
                                                : _aiAlgorithmConfigId,
                                            options:
                                                _playableAiOpponentOptionsForMode(
                                              _selectedGameMode,
                                            ),
                                            onChanged: (configId) =>
                                                _updateSelection(
                                                    aiAlgorithmConfigId:
                                                        configId),
                                          ),
                                        ],
                                        if (_playMode == _modeTerritory) ...[
                                          const SizedBox(height: 20),
                                          const _SectionLabel(title: 'AI 棋力'),
                                          const SizedBox(height: 8),
                                          const _ModeHintText(
                                            text:
                                                '圍空模式只使用 KataGo 棋手；不同棋力由同一模型的策略參數控制。',
                                          )
                                        ],
                                        const SizedBox(height: 20),
                                        const _SectionLabel(title: '初始'),
                                        const SizedBox(height: 8),
                                        _PillSegmentControl<CaptureInitialMode>(
                                          selectedValue: _initialMode,
                                          options: const [
                                            _SegmentOption(
                                              value: CaptureInitialMode.cross,
                                              label: '十字',
                                            ),
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
                                              label: '擺棋',
                                            ),
                                          ],
                                          onChanged: (value) =>
                                              _updateSelection(
                                                  initialMode: value),
                                        ),
                                        const SizedBox(height: 20),
                                        const _SectionLabel(title: '棋盤'),
                                        const SizedBox(height: 4),
                                        _PillSegmentControl<int>(
                                          selectedValue: _boardSize,
                                          options: const [
                                            _SegmentOption(
                                              value: 9,
                                              label: '9 路',
                                            ),
                                            _SegmentOption(
                                              value: 13,
                                              label: '13 路',
                                            ),
                                            _SegmentOption(
                                              value: 19,
                                              label: '19 路',
                                            ),
                                          ],
                                          onChanged: (value) =>
                                              _updateSelection(
                                                  boardSize: value),
                                        ),
                                        const SizedBox(height: 24),
                                      ] else ...[
                                        _ConfigPreview(
                                          difficultyMode: _difficultyMode,
                                          computedRank: _computedRank,
                                          activeAiConfig:
                                              _selectedAiAlgorithmConfig,
                                          aiAlgorithmConfigId: _isTerritoryMode
                                              ? _territoryAiAlgorithmConfigId
                                              : _aiAlgorithmConfigId,
                                          isTerritoryMode: _isTerritoryMode,
                                          onTap: () => setState(
                                            () => _isAdjusting = true,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                      if (_initialMode ==
                                          CaptureInitialMode.setup) ...[
                                        _PrimaryActionButton(
                                          title: _startButtonTitle(
                                            _CaptureCopy.startSetupButton,
                                          ),
                                          onPressed: () => _startGame(
                                              humanColor: StoneColor.black),
                                        ),
                                      ] else ...[
                                        _PrimaryActionButton(
                                          title: _startButtonTitle(
                                            _CaptureCopy.startAsBlackButton,
                                          ),
                                          onPressed: () => _startGame(
                                              humanColor: StoneColor.black),
                                        ),
                                        const SizedBox(height: 10),
                                        _SecondaryActionButton(
                                          title: _startButtonTitle(
                                            _CaptureCopy.startAsWhiteButton,
                                          ),
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
                ),
                if (_heroTapProxyEnabled)
                  Positioned(
                    top: heroTitleTop,
                    left: 24,
                    right: 16,
                    height: _MotivationHeroTitle.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _motivationHeroKey.currentState?.handleTap(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (kIsWeb && developerMode)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: _HomeBoardTuningLauncher(
                        onTap: () =>
                            setState(() => _homeTuningSheetVisible = true),
                      ),
                    ),
                  ),
                if (kIsWeb && developerMode && _homeTuningSheetVisible)
                  _HomeBoardTuningSheet(
                    leafShadowEnabled:
                        widget.leafShadowEnabled ?? _leafShadowEnabled,
                    shadowOpacity:
                        widget.leafShadowOpacity ?? _leafShadowOpacity,
                    leafShadowSpeed: widget.leafShadowSpeed ?? _leafShadowSpeed,
                    leafShadowDrift: widget.leafShadowDrift ?? _leafShadowDrift,
                    leafShadowRotation:
                        widget.leafShadowRotation ?? _leafShadowRotation,
                    leafShadowScale: widget.leafShadowScale ?? _leafShadowScale,
                    leafShadowOffsetX:
                        widget.leafShadowOffsetX ?? _leafShadowOffsetX,
                    leafShadowOffsetZ:
                        widget.leafShadowOffsetZ ?? _leafShadowOffsetZ,
                    stoneExtraOverlayEnabled: _stoneExtraOverlayEnabled,
                    cornerLabelsEnabled:
                        _homeTuningSheetVisible && _cornerLabelsEnabled,
                    boardTopBrightness: _boardTopBrightness,
                    boardWoodColor: _boardWoodColor,
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
                    onLeafShadowEnabledChanged: (value) {
                      widget.onLeafShadowEnabledChanged?.call(value);
                      setState(() => _leafShadowEnabled = value);
                    },
                    onShadowOpacityChanged: (value) {
                      widget.onLeafShadowOpacityChanged?.call(value);
                      setState(() => _leafShadowOpacity = value);
                    },
                    onLeafShadowSpeedChanged: (value) {
                      widget.onLeafShadowSpeedChanged?.call(value);
                      setState(() => _leafShadowSpeed = value);
                    },
                    onLeafShadowDriftChanged: (value) {
                      widget.onLeafShadowDriftChanged?.call(value);
                      setState(() => _leafShadowDrift = value);
                    },
                    onLeafShadowRotationChanged: (value) {
                      widget.onLeafShadowRotationChanged?.call(value);
                      setState(() => _leafShadowRotation = value);
                    },
                    onLeafShadowScaleChanged: (value) {
                      widget.onLeafShadowScaleChanged?.call(value);
                      setState(() => _leafShadowScale = value);
                    },
                    onLeafShadowOffsetXChanged: (value) {
                      widget.onLeafShadowOffsetXChanged?.call(value);
                      setState(() => _leafShadowOffsetX = value);
                    },
                    onLeafShadowOffsetZChanged: (value) {
                      widget.onLeafShadowOffsetZChanged?.call(value);
                      setState(() => _leafShadowOffsetZ = value);
                    },
                    onStoneExtraOverlayChanged: (value) =>
                        setState(() => _stoneExtraOverlayEnabled = value),
                    onCornerLabelsChanged: (value) =>
                        setState(() => _cornerLabelsEnabled = value),
                    onBoardTopBrightnessChanged: (value) =>
                        setState(() => _boardTopBrightness = value),
                    onBoardWoodColorChanged: (value) =>
                        setState(() => _boardWoodColor = value),
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
                    windowPlateau: _windowPlateau,
                    windowFalloff: _windowFalloff,
                    windowRotation: _windowRotation,
                    gridBaseOpacity: _gridBaseOpacity,
                    gridFadeMult: _gridFadeMult,
                    gridFadePower: _gridFadePower,
                    gridFadeMin: _gridFadeMin,
                    lightMapFloor: _lightMapFloor,
                    lightMapIntensity: _lightMapIntensity,
                    onWindowCenterUChanged: (v) =>
                        setState(() => _windowCenterU = v),
                    onWindowCenterVChanged: (v) =>
                        setState(() => _windowCenterV = v),
                    onWindowSpreadUChanged: (v) =>
                        setState(() => _windowSpreadU = v),
                    onWindowSpreadVChanged: (v) =>
                        setState(() => _windowSpreadV = v),
                    onWindowPlateauChanged: (v) =>
                        setState(() => _windowPlateau = v),
                    onWindowFalloffChanged: (v) =>
                        setState(() => _windowFalloff = v),
                    onWindowRotationChanged: (v) =>
                        setState(() => _windowRotation = v),
                    onGridBaseOpacityChanged: (v) =>
                        setState(() => _gridBaseOpacity = v),
                    onGridFadeMultChanged: (v) =>
                        setState(() => _gridFadeMult = v),
                    onGridFadePowerChanged: (v) =>
                        setState(() => _gridFadePower = v),
                    onGridFadeMinChanged: (v) =>
                        setState(() => _gridFadeMin = v),
                    onLightMapFloorChanged: (v) =>
                        setState(() => _lightMapFloor = v),
                    onLightMapIntensityChanged: (v) =>
                        setState(() => _lightMapIntensity = v),
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
    widget.onLeafShadowEnabledChanged?.call(_defaultLeafShadowEnabled);
    widget.onLeafShadowOpacityChanged?.call(_defaultLeafShadowOpacity);
    widget.onLeafShadowSpeedChanged?.call(_defaultLeafShadowSpeed);
    widget.onLeafShadowDriftChanged?.call(_defaultLeafShadowDrift);
    widget.onLeafShadowRotationChanged?.call(_defaultLeafShadowRotation);
    widget.onLeafShadowScaleChanged?.call(_defaultLeafShadowScale);
    widget.onLeafShadowOffsetXChanged?.call(_defaultLeafShadowOffsetX);
    widget.onLeafShadowOffsetZChanged?.call(_defaultLeafShadowOffsetZ);
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
      _leafShadowEnabled = _defaultLeafShadowEnabled;
      _leafShadowOpacity = _defaultLeafShadowOpacity;
      _leafShadowSpeed = _defaultLeafShadowSpeed;
      _leafShadowDrift = _defaultLeafShadowDrift;
      _leafShadowRotation = _defaultLeafShadowRotation;
      _leafShadowScale = _defaultLeafShadowScale;
      _leafShadowOffsetX = _defaultLeafShadowOffsetX;
      _leafShadowOffsetZ = _defaultLeafShadowOffsetZ;
      _stoneExtraOverlayEnabled = _defaultStoneExtraOverlayEnabled;
      _cornerLabelsEnabled = _defaultCornerLabelsEnabled;
      _boardTopBrightness = _defaultBoardTopBrightness;
      _boardWoodColor = _defaultBoardWoodColor;
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
      _windowPlateau = _defaultWindowPlateau;
      _windowFalloff = _defaultWindowFalloff;
      _windowRotation = _defaultWindowRotation;
      _gridBaseOpacity = _defaultGridBaseOpacity;
      _gridFadeMult = _defaultGridFadeMult;
      _gridFadePower = _defaultGridFadePower;
      _gridFadeMin = _defaultGridFadeMin;
      _lightMapFloor = _defaultLightMapFloor;
      _lightMapIntensity = _defaultLightMapIntensity;
    });
  }

  String get _selectedModeTitle {
    final boardSizeLabel = '$_boardSize 路';
    if (_playMode == _modeTerritory) {
      return '圍空 · $boardSizeLabel · ${_initialMode.label}';
    }
    return '吃 $_captureTarget 子取勝 · $boardSizeLabel · ${_initialMode.label}';
  }

  String get _captureModeSegmentLabel => '吃 $_captureTarget 子取勝';
  bool get _isTerritoryMode => _playMode == _modeTerritory;
  GameMode get _selectedGameMode =>
      _isTerritoryMode ? GameMode.territory : GameMode.capture;

  Future<void> _restoreSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedBoardSize = prefs.getInt(_boardSizeKey);
    final savedInitialMode = prefs.getString(_initialModeKey);

    // Read new difficulty keys; normalize unknown stored values to 'auto'.
    final rawDifficultyMode =
        prefs.getString(_difficultyModeKey) ?? _defaultDifficultyMode;
    String difficultyMode =
        (rawDifficultyMode == 'auto' || rawDifficultyMode == 'manual')
            ? rawDifficultyMode
            : 'auto';
    final hasLegacyManualRank = prefs.containsKey(_manualRankKey);
    var migratedLegacyDifficulty = false;
    int legacyManualRank =
        prefs.getInt(_manualRankKey) ?? AiRankLevel.defaultRank;

    // Migrate from legacy difficulty key if new keys haven't been set yet.
    if (!prefs.containsKey(_difficultyModeKey)) {
      final legacy = prefs.getString(_legacyDifficultyKey);
      if (legacy != null) {
        difficultyMode = 'manual';
        migratedLegacyDifficulty = true;
        legacyManualRank = switch (legacy) {
          'beginner' => 4,
          'advanced' => 20,
          _ => 12, // intermediate
        };
      }
    }

    legacyManualRank =
        legacyManualRank.clamp(AiRankLevel.min, AiRankLevel.max).toInt();

    final savedAiAlgorithmConfig = prefs.getString(_aiAlgorithmConfigKey);
    final savedTerritoryAiAlgorithmConfig =
        prefs.getString(_territoryAiAlgorithmConfigKey);
    final savedPlayMode = prefs.getString(_playModeKey);

    // Compute rank from history for 'auto' mode.
    final history = await GameHistoryRepository().loadAllChronological();
    final computedRank = PlayerRankRepository.computeCurrentRank(history);

    if (!mounted) return;
    setState(() {
      _difficultyMode = difficultyMode;
      _computedRank = computedRank;
      if (savedAiAlgorithmConfig != null &&
          _playableAiOpponentOptionsForMode(GameMode.capture)
              .any((option) => option.config.id == savedAiAlgorithmConfig)) {
        _aiAlgorithmConfigId = savedAiAlgorithmConfig;
      } else if (difficultyMode == 'manual' &&
          (hasLegacyManualRank || migratedLegacyDifficulty)) {
        _aiAlgorithmConfigId = _aiAlgorithmConfigForRank(legacyManualRank).id;
      }
      if (savedTerritoryAiAlgorithmConfig != null &&
          _playableAiOpponentOptionsForMode(GameMode.territory).any((option) =>
              option.config.id == savedTerritoryAiAlgorithmConfig)) {
        _territoryAiAlgorithmConfigId = savedTerritoryAiAlgorithmConfig;
      }
      if (savedPlayMode == _modeCapture || savedPlayMode == _modeTerritory) {
        _playMode = savedPlayMode!;
      }
      _initialMode = captureInitialModeFromStorageKey(
        savedInitialMode,
        fallback: _initialMode,
      );
      if (savedBoardSize == 9 || savedBoardSize == 13 || savedBoardSize == 19) {
        _boardSize = savedBoardSize!;
      }
    });
  }

  void _updateSelection({
    String? difficultyMode,
    String? aiAlgorithmConfigId,
    int? boardSize,
    CaptureInitialMode? initialMode,
    String? playMode,
  }) {
    setState(() {
      if (difficultyMode != null) _difficultyMode = difficultyMode;
      if (aiAlgorithmConfigId != null) {
        if (_isTerritoryMode || playMode == _modeTerritory) {
          _territoryAiAlgorithmConfigId = aiAlgorithmConfigId;
        } else {
          _aiAlgorithmConfigId = aiAlgorithmConfigId;
        }
      }
      _boardSize = boardSize ?? _boardSize;
      if (playMode != null) _playMode = playMode;
      _initialMode = initialMode ?? _initialMode;
    });
    _saveSelection();
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_difficultyModeKey, _difficultyMode),
      prefs.setString(_aiAlgorithmConfigKey, _aiAlgorithmConfigId),
      prefs.setString(
          _territoryAiAlgorithmConfigKey, _territoryAiAlgorithmConfigId),
      prefs.setInt(_boardSizeKey, _boardSize),
      prefs.setString(_playModeKey, _playMode),
      prefs.setString(
          _initialModeKey, captureInitialModeStorageKey(_initialMode)),
    ]);
  }

  Future<void> _loadHistory() async {
    final records = await _historyRepo.loadAll();
    if (!mounted) return;
    setState(() => _history = records);
  }

  Future<void> _importBoardFromScreenshot() async {
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

      setState(() {
        _isRecognizingScreenshot = true;
      });
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
    } catch (error, stackTrace) {
      AppLogStore.instance.add(
        category: AppLogCategory.screenshotRecognition,
        level: AppLogLevel.error,
        message: '截圖匯入失敗',
        details: 'algorithm: ${algorithm.storageValue}',
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
      if (mounted) {
        setState(() {
          _isRecognizingScreenshot = false;
        });
      }
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

  Future<void> _startGame({
    required StoneColor humanColor,
    bool forceSetup = false,
    List<List<StoneColor>>? initialBoard,
  }) async {
    final selectedAiConfig = _selectedAiAlgorithmConfig;
    final katagoModelAdapter = await _prepareKatagoForWebStart(
      selectedAiConfig,
    );
    if (!mounted ||
        (kIsWeb &&
            _isKatagoOnnxConfig(selectedAiConfig) &&
            katagoModelAdapter == null)) {
      return;
    }
    _saveSelection();

    final effectiveRank = selectedAiConfig == null
        ? _computedRank
        : _rankForAiAlgorithmConfig(selectedAiConfig);
    final effectiveDifficulty = AiRankLevel.difficultyZone(effectiveRank);

    Navigator.of(context, rootNavigator: true)
        .push(
          CupertinoPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => CaptureGameProvider(
                boardSize: _boardSize,
                captureTarget: _captureTarget,
                difficulty: selectedAiConfig?.robotConfig.difficulty ??
                    effectiveDifficulty,
                gameMode: _selectedGameMode,
                humanColor: humanColor,
                initialMode:
                    forceSetup ? CaptureInitialMode.setup : _initialMode,
                initialBoardOverride: initialBoard,
                aiAlgorithmConfig: selectedAiConfig,
                katagoModelAdapter: katagoModelAdapter,
              ),
              child: CaptureGamePlayScreen(
                aiRank: effectiveRank,
                captureTarget: _captureTarget,
                gameMode: _selectedGameMode,
                humanColor: humanColor,
                initialMode:
                    forceSetup ? CaptureInitialMode.setup : _initialMode,
                initialBoardOverride: initialBoard,
              ),
            ),
          ),
        )
        .then(_onGameScreenResult);
  }

  Future<AsyncKatagoModelAdapter?> _prepareKatagoForWebStart(
    AiAlgorithmConfig? config,
  ) async {
    // Spec: docs/specs_map/main_game_flow.yaml#configuration_controls
    if (!kIsWeb || !_isKatagoOnnxConfig(config)) return null;
    if (_isPreparingKatago) return null;
    setState(() => _isPreparingKatago = true);
    final adapter = FlutterKatagoOnnxModelAdapter();
    final cancelPreparation = Completer<void>();
    var preparationDialogOpen = true;
    unawaited(
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _KatagoPreparationDialog(
          onClose: () {
            if (!cancelPreparation.isCompleted) {
              cancelPreparation.complete();
            }
            preparationDialogOpen = false;
            Navigator.of(dialogContext, rootNavigator: true).pop();
          },
        ),
      ).whenComplete(() => preparationDialogOpen = false),
    );

    Future<void> closePreparationDialog() async {
      if (!mounted || !preparationDialogOpen) return;
      preparationDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    Future<bool> waitForPreparationStep(Future<void> step) async {
      final result = await Future.any<bool>([
        step.then((_) => true),
        cancelPreparation.future.then((_) => false),
      ]);
      return result;
    }

    Future<KatagoModelEvaluation?> waitForEvaluation(
      Future<KatagoModelEvaluation> step,
    ) async {
      final result = await Future.any<Object?>([
        step,
        cancelPreparation.future.then((_) => null),
      ]);
      return result as KatagoModelEvaluation?;
    }

    try {
      final request = _katagoReadinessRequest(config!);
      final preload = adapter.preload([request]);
      if (!await waitForPreparationStep(preload)) {
        unawaited(preload.whenComplete(adapter.close));
        return null;
      }
      final chooseMove = adapter.chooseMove(request);
      final evaluation = await waitForEvaluation(chooseMove);
      if (evaluation == null) {
        unawaited(chooseMove.whenComplete(adapter.close));
        return null;
      }
      if (evaluation.status == KatagoBackendStatus.ready &&
          evaluation.move != null) {
        await closePreparationDialog();
        return adapter;
      }
      await adapter.close();
      await closePreparationDialog();
      if (mounted) {
        _showKatagoPreparationFailed(
          evaluation.failureReason ?? 'katago_onnx_model_not_ready',
        );
      }
      return null;
    } catch (error) {
      await adapter.close();
      await closePreparationDialog();
      if (mounted) {
        _showKatagoPreparationFailed('$error');
      }
      return null;
    } finally {
      await closePreparationDialog();
      if (mounted) setState(() => _isPreparingKatago = false);
    }
  }

  KatagoModelRequest _katagoReadinessRequest(AiAlgorithmConfig config) {
    final params = config.parameters;
    return KatagoModelRequest(
      board: SimBoard(_boardSize, captureTarget: _captureTarget),
      modelAsset: params['modelAsset'] as String,
      timeBudgetMillis: (params['timeBudgetMillis'] as num?)?.toInt() ?? 10000,
      policyTemperature:
          (params['policyTemperature'] as num?)?.toDouble() ?? 0.0,
      candidateLimit: (params['candidateLimit'] as num?)?.toInt() ?? 1,
      policyPlane: (params['policyPlane'] as num?)?.toInt() ?? 0,
    );
  }

  bool _isKatagoOnnxConfig(AiAlgorithmConfig? config) {
    return config?.frameworkId == AiAlgorithmFrameworkId.katago &&
        config?.parameters['backend'] == 'onnx';
  }

  String _startButtonTitle(String fallback) {
    return _isPreparingKatago && _isKatagoOnnxConfig(_selectedAiAlgorithmConfig)
        ? '正在準備 KataGo...'
        : fallback;
  }

  void _showKatagoPreparationFailed(String reason) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('KataGo 尚未就緒'),
        content: Text(
          'Web 端需要先載入 KataGo 模型。請確認模型已打包到 assets/models 後重新構建。\n\n$reason',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// Handles the result from a [CaptureGamePlayScreen] pop.
  ///
  /// Reloads history (so both original and forked games appear), and if the
  /// game screen requested a fork, immediately starts the forked game.
  void _onGameScreenResult(Object? result) {
    _loadHistory();
    if (result is _ForkRequest) {
      _startForkedGame(result);
    }
  }

  void _startForkedGame(_ForkRequest fork) {
    Navigator.of(context, rootNavigator: true)
        .push<Object?>(
          CupertinoPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => CaptureGameProvider(
                boardSize: fork.boardSize,
                captureTarget: fork.captureTarget,
                difficulty: fork.difficulty,
                gameMode: fork.gameMode,
                humanColor: fork.humanColor,
                initialMode: fork.initialMode,
                initialBoardOverride: fork.initialBoardOverride,
                initialPlayerOverride: fork.initialPlayerOverride,
                initialMoveLog: fork.inheritedMoves,
                aiAlgorithmConfig: fork.aiAlgorithmConfigId == null
                    ? null
                    : AiAlgorithmRegistry.configById(fork.aiAlgorithmConfigId!),
              )..setAiStyle(fork.aiStyle),
              child: CaptureGamePlayScreen(
                aiRank: fork.aiRank,
                captureTarget: fork.captureTarget,
                gameMode: fork.gameMode,
                humanColor: fork.humanColor,
                initialMode: fork.initialMode,
                initialBoardOverride: fork.initialBoardOverride,
                initialPlayerOverride: fork.initialPlayerOverride,
                inheritedMoves: const [],
                inheritedMarkedMoveNumbers: fork.inheritedMarkedMoveNumbers,
              ),
            ),
          ),
        )
        .then(_onGameScreenResult);
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
    required this.leafShadowEnabled,
    required this.leafShadowOpacity,
    required this.leafShadowSpeed,
    required this.leafShadowDrift,
    required this.leafShadowRotation,
    required this.leafShadowScale,
    required this.leafShadowOffsetX,
    required this.leafShadowOffsetZ,
    required this.stoneExtraOverlayEnabled,
    required this.cornerLabelsEnabled,
    required this.boardTopBrightness,
    required this.boardWoodColor,
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
    required this.windowPlateau,
    required this.windowFalloff,
    required this.windowRotation,
    required this.gridBaseOpacity,
    required this.gridFadeMult,
    required this.gridFadePower,
    required this.gridFadeMin,
    required this.lightMapFloor,
    required this.lightMapIntensity,
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
  final bool leafShadowEnabled;
  final double leafShadowOpacity;
  final double leafShadowSpeed;
  final double leafShadowDrift;
  final double leafShadowRotation;
  final double leafShadowScale;
  final double leafShadowOffsetX;
  final double leafShadowOffsetZ;
  final bool stoneExtraOverlayEnabled;
  final bool cornerLabelsEnabled;
  final double boardTopBrightness;
  final int boardWoodColor;
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
  final double windowPlateau;
  final double windowFalloff;
  final double windowRotation;
  final double gridBaseOpacity;
  final double gridFadeMult;
  final double gridFadePower;
  final double gridFadeMin;
  final double lightMapFloor;
  final double lightMapIntensity;

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
            particles: false,
            showCornerLabels: cornerLabelsEnabled,
            sceneScale: sceneScale,
            cameraLift: cameraLift,
            cameraDepth: cameraDepth,
            targetZOffset: targetZOffset,
            cinematicFov: cinematicFov,
            boardRotationY: boardRotationY,
            leafShadowEnabled: leafShadowEnabled,
            leafShadowOpacity: leafShadowOpacity,
            leafShadowSpeed: leafShadowSpeed,
            leafShadowDrift: leafShadowDrift,
            leafShadowRotation: leafShadowRotation,
            leafShadowScale: leafShadowScale,
            leafShadowOffsetX: leafShadowOffsetX,
            leafShadowOffsetZ: leafShadowOffsetZ,
            stoneExtraOverlayEnabled: stoneExtraOverlayEnabled,
            boardTopBrightness: boardTopBrightness,
            boardWoodColor: boardWoodColor,
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
            windowPlateau: windowPlateau,
            windowFalloff: windowFalloff,
            windowRotation: windowRotation,
            gridBaseOpacity: gridBaseOpacity,
            gridFadeMult: gridFadeMult,
            gridFadePower: gridFadePower,
            gridFadeMin: gridFadeMin,
            lightMapFloor: lightMapFloor,
            lightMapIntensity: lightMapIntensity,
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
                '調光',
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
    required this.leafShadowEnabled,
    required this.shadowOpacity,
    required this.leafShadowSpeed,
    required this.leafShadowDrift,
    required this.leafShadowRotation,
    required this.leafShadowScale,
    required this.leafShadowOffsetX,
    required this.leafShadowOffsetZ,
    required this.stoneExtraOverlayEnabled,
    required this.cornerLabelsEnabled,
    required this.boardTopBrightness,
    required this.boardWoodColor,
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
    required this.onLeafShadowEnabledChanged,
    required this.onShadowOpacityChanged,
    required this.onLeafShadowSpeedChanged,
    required this.onLeafShadowDriftChanged,
    required this.onLeafShadowRotationChanged,
    required this.onLeafShadowScaleChanged,
    required this.onLeafShadowOffsetXChanged,
    required this.onLeafShadowOffsetZChanged,
    required this.onStoneExtraOverlayChanged,
    required this.onCornerLabelsChanged,
    required this.onBoardTopBrightnessChanged,
    required this.onBoardWoodColorChanged,
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
    required this.windowPlateau,
    required this.windowFalloff,
    required this.windowRotation,
    required this.gridBaseOpacity,
    required this.gridFadeMult,
    required this.gridFadePower,
    required this.gridFadeMin,
    required this.lightMapFloor,
    required this.lightMapIntensity,
    required this.onWindowCenterUChanged,
    required this.onWindowCenterVChanged,
    required this.onWindowSpreadUChanged,
    required this.onWindowSpreadVChanged,
    required this.onWindowPlateauChanged,
    required this.onWindowFalloffChanged,
    required this.onWindowRotationChanged,
    required this.onGridBaseOpacityChanged,
    required this.onGridFadeMultChanged,
    required this.onGridFadePowerChanged,
    required this.onGridFadeMinChanged,
    required this.onLightMapFloorChanged,
    required this.onLightMapIntensityChanged,
  });

  final bool leafShadowEnabled;
  final double shadowOpacity;
  final double leafShadowSpeed;
  final double leafShadowDrift;
  final double leafShadowRotation;
  final double leafShadowScale;
  final double leafShadowOffsetX;
  final double leafShadowOffsetZ;
  final bool stoneExtraOverlayEnabled;
  final bool cornerLabelsEnabled;
  final double boardTopBrightness;
  final int boardWoodColor;
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
  final ValueChanged<bool> onLeafShadowEnabledChanged;
  final ValueChanged<double> onShadowOpacityChanged;
  final ValueChanged<double> onLeafShadowSpeedChanged;
  final ValueChanged<double> onLeafShadowDriftChanged;
  final ValueChanged<double> onLeafShadowRotationChanged;
  final ValueChanged<double> onLeafShadowScaleChanged;
  final ValueChanged<double> onLeafShadowOffsetXChanged;
  final ValueChanged<double> onLeafShadowOffsetZChanged;
  final ValueChanged<bool> onStoneExtraOverlayChanged;
  final ValueChanged<bool> onCornerLabelsChanged;
  final ValueChanged<double> onBoardTopBrightnessChanged;
  final ValueChanged<int> onBoardWoodColorChanged;
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
  final double windowPlateau;
  final double windowFalloff;
  final double windowRotation;
  final double gridBaseOpacity;
  final double gridFadeMult;
  final double gridFadePower;
  final double gridFadeMin;
  final double lightMapFloor;
  final double lightMapIntensity;
  final ValueChanged<double> onWindowCenterUChanged;
  final ValueChanged<double> onWindowCenterVChanged;
  final ValueChanged<double> onWindowSpreadUChanged;
  final ValueChanged<double> onWindowSpreadVChanged;
  final ValueChanged<double> onWindowPlateauChanged;
  final ValueChanged<double> onWindowFalloffChanged;
  final ValueChanged<double> onWindowRotationChanged;
  final ValueChanged<double> onGridBaseOpacityChanged;
  final ValueChanged<double> onGridFadeMultChanged;
  final ValueChanged<double> onGridFadePowerChanged;
  final ValueChanged<double> onGridFadeMinChanged;
  final ValueChanged<double> onLightMapFloorChanged;
  final ValueChanged<double> onLightMapIntensityChanged;

  @override
  State<_HomeBoardTuningSheet> createState() => _HomeBoardTuningSheetState();
}

class _HomeBoardTuningSheetState extends State<_HomeBoardTuningSheet> {
  static const List<String> _tabTitles = [
    '基礎',
    '構圖',
    '主光',
    '補光',
    '環境',
    '格線',
    '動畫',
  ];
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final tabPages = <List<Widget>>[
      [
        _TuningSwitchRow(
          title: '棋子額外陰影疊加',
          value: widget.stoneExtraOverlayEnabled,
          onChanged: widget.onStoneExtraOverlayChanged,
        ),
        _TuningSwitchRow(
          title: '角標 ABCD',
          value: widget.cornerLabelsEnabled,
          onChanged: widget.onCornerLabelsChanged,
        ),
        _TuningSlider(
          label: '棋盤亮度',
          value: widget.boardTopBrightness,
          min: 0.40,
          max: 2.40,
          onChanged: widget.onBoardTopBrightnessChanged,
        ),
        _RgbEditor(
          title: '棋盤本色',
          colorHex: widget.boardWoodColor,
          onChanged: widget.onBoardWoodColorChanged,
        ),
        _TuningSlider(
          label: '曝光',
          value: widget.toneMappingExposure,
          min: 0.10,
          max: 1.20,
          onChanged: widget.onToneMappingExposureChanged,
        ),
        _TuningSlider(
          label: '主光強度',
          value: widget.keyLightIntensity,
          min: 0.0,
          max: 1.8,
          onChanged: widget.onKeyLightIntensityChanged,
        ),
        _TuningSlider(
          label: '補光強度',
          value: widget.fillLightIntensity,
          min: 0.0,
          max: 1.2,
          onChanged: widget.onFillLightIntensityChanged,
        ),
        _TuningSlider(
          label: '環境光',
          value: widget.ambientLightIntensity,
          min: 0.0,
          max: 0.9,
          onChanged: widget.onAmbientLightIntensityChanged,
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
          label: '縮放',
          value: widget.boardSceneScale,
          min: 0.24,
          max: 2.0,
          onChanged: widget.onBoardSceneScaleChanged,
        ),
        _TuningSlider(
          label: '相機高',
          value: widget.boardCameraLift,
          min: 0.01,
          max: 20,
          onChanged: widget.onBoardCameraLiftChanged,
        ),
        _TuningSlider(
          label: '相機遠',
          value: widget.boardCameraDepth,
          min: 1.0,
          max: 30,
          onChanged: widget.onBoardCameraDepthChanged,
        ),
        _TuningSlider(
          label: '目標Z',
          value: widget.boardTargetZOffset,
          min: -1.4,
          max: 0.6,
          onChanged: widget.onBoardTargetZOffsetChanged,
        ),
        _TuningSlider(
          label: '棋盤轉向',
          value: widget.boardRotationY,
          min: -3.14,
          max: 3.14,
          onChanged: widget.onBoardRotationYChanged,
        ),
        const _TuningGroupTitle('畫布位置'),
        _TuningSlider(
          label: '頂部',
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
          label: '主光強度',
          value: widget.keyLightIntensity,
          min: 0.0,
          max: 1.8,
          onChanged: widget.onKeyLightIntensityChanged,
        ),
        _RgbEditor(
          title: '主光顏色',
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
          label: '補光強度',
          value: widget.fillLightIntensity,
          min: 0.0,
          max: 1.2,
          onChanged: widget.onFillLightIntensityChanged,
        ),
        _RgbEditor(
          title: '補光顏色',
          colorHex: widget.fillLightColor,
          onChanged: widget.onFillLightColorChanged,
        ),
      ],
      [
        _TuningSlider(
          label: '環境光',
          value: widget.ambientLightIntensity,
          min: 0.0,
          max: 0.9,
          onChanged: widget.onAmbientLightIntensityChanged,
        ),
        _RgbEditor(
          title: '環境光顏色',
          colorHex: widget.ambientLightColor,
          onChanged: widget.onAmbientLightColorChanged,
        ),
        _TuningSlider(
          label: '高光燈',
          value: widget.sheenLightIntensity,
          min: 0.0,
          max: 1.4,
          onChanged: widget.onSheenLightIntensityChanged,
        ),
        _RgbEditor(
          title: '高光顏色',
          colorHex: widget.sheenLightColor,
          onChanged: widget.onSheenLightColorChanged,
        ),
      ],
      // 格線 tab
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
          label: '窗光擴散 U',
          value: widget.windowSpreadU,
          min: 0.50,
          max: 4.00,
          onChanged: widget.onWindowSpreadUChanged,
        ),
        _TuningSlider(
          label: '窗光擴散 V',
          value: widget.windowSpreadV,
          min: 0.50,
          max: 4.00,
          onChanged: widget.onWindowSpreadVChanged,
        ),
        _TuningSlider(
          label: '窗光平台',
          value: widget.windowPlateau,
          min: 0.00,
          max: 0.95,
          onChanged: widget.onWindowPlateauChanged,
        ),
        _TuningSlider(
          label: '窗光衰減',
          value: widget.windowFalloff,
          min: 0.05,
          max: 1.50,
          onChanged: widget.onWindowFalloffChanged,
        ),
        _TuningSlider(
          label: '窗光旋轉',
          value: widget.windowRotation,
          min: -3.14,
          max: 3.14,
          onChanged: widget.onWindowRotationChanged,
        ),
        _TuningSlider(
          label: '格線基礎透明度',
          value: widget.gridBaseOpacity,
          min: 0.10,
          max: 1.00,
          onChanged: widget.onGridBaseOpacityChanged,
        ),
        _TuningSlider(
          label: '格線淡化強度',
          value: widget.gridFadeMult,
          min: 0.00,
          max: 1.20,
          onChanged: widget.onGridFadeMultChanged,
        ),
        _TuningSlider(
          label: '格線淡化曲線',
          value: widget.gridFadePower,
          min: 0.20,
          max: 2.00,
          onChanged: widget.onGridFadePowerChanged,
        ),
        _TuningSlider(
          label: '格線最低不透明',
          value: widget.gridFadeMin,
          min: 0.00,
          max: 0.50,
          onChanged: widget.onGridFadeMinChanged,
        ),
        _TuningSlider(
          label: 'lightMap 地板',
          value: widget.lightMapFloor,
          min: 0.00,
          max: 0.90,
          onChanged: widget.onLightMapFloorChanged,
        ),
        _TuningSlider(
          label: 'lightMap 強度',
          value: widget.lightMapIntensity,
          min: 0.50,
          max: 4.00,
          onChanged: widget.onLightMapIntensityChanged,
        ),
      ],
      [
        const _TuningGroupTitle('桂花樹影'),
        _TuningSwitchRow(
          title: '啟用樹影',
          value: widget.leafShadowEnabled,
          onChanged: widget.onLeafShadowEnabledChanged,
        ),
        _TuningSlider(
          label: '葉影強度',
          value: widget.shadowOpacity,
          min: 0.04,
          max: 0.42,
          onChanged: widget.onShadowOpacityChanged,
        ),
        _TuningSlider(
          label: '葉影速度',
          value: widget.leafShadowSpeed,
          min: 0.00,
          max: 0.60,
          onChanged: widget.onLeafShadowSpeedChanged,
        ),
        _TuningSlider(
          label: '葉影擺幅',
          value: widget.leafShadowDrift,
          min: 0.00,
          max: 0.18,
          onChanged: widget.onLeafShadowDriftChanged,
        ),
        _TuningSlider(
          label: '葉影旋轉',
          value: widget.leafShadowRotation,
          min: -3.14,
          max: 3.14,
          onChanged: widget.onLeafShadowRotationChanged,
        ),
        _TuningSlider(
          label: '葉影縮放',
          value: widget.leafShadowScale,
          min: 0.05,
          max: 2.40,
          onChanged: widget.onLeafShadowScaleChanged,
        ),
        _TuningSlider(
          label: '葉影位置 X',
          value: widget.leafShadowOffsetX,
          min: -2.00,
          max: 2.00,
          onChanged: widget.onLeafShadowOffsetXChanged,
        ),
        _TuningSlider(
          label: '葉影位置 Z',
          value: widget.leafShadowOffsetZ,
          min: -2.00,
          max: 2.00,
          onChanged: widget.onLeafShadowOffsetZChanged,
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
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(42, 30),
                          onPressed: widget.onReset,
                          child: const Text('重設'),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(42, 30),
                          onPressed: widget.onClose,
                          child: const Text('關閉'),
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
  static const pageTitle = '围棋谜题';

  static const _motivations = [
    '圍棋讓我放鬆',
    '下棋使我更平靜',
    '我在這裡是專注的',
    '每一步都值得深思',
    '棋盤上只有當下',
    '落子無悔，心平氣和',
    '圍棋教會我耐心',
    '在這裡，我找到專注',
    '下棋讓我忘記煩惱',
    '一盤棋，一段寧靜',
    '每手棋都是一次思考',
    '圍棋是我的冥想',
    '在棋盤上，心緒沉靜',
    '下一步，只看眼前',
    '圍棋讓我學會等待',
    '棋局如人生，從容應對',
    '落子一刻，萬慮皆空',
    '下棋讓我更專注',
    '圍棋是內心的修煉',
    '在這裡找到自己的節奏',
    '每盤棋都是新的開始',
    '棋盤上，時間慢了下來',
    '圍棋讓我與自己對話',
    '下棋時，世界變得安靜',
    '棋局中學會取捨',
    '圍棋給我帶來平靜',
    '每一步都有它的意義',
    '在棋盤上感受專注的力量',
    '圍棋讓我享受思考的過程',
    '落子時，心無雜念',
    '圍棋是我放鬆的方式',
    '黑白之間，只有當下',
    '圍棋教會我謙遜',
    '每次落子都是一次成長',
    '在這裡，我可以慢下來',
    '下棋讓思緒變得清晰',
    '圍棋讓我學會專注於當下',
    '棋局中，找到內心的平衡',
    '一子一子，皆是修行',
    '圍棋讓我感到愉悅',
    '棋盤上，輸贏都是收穫',
    '下棋使我沉澱下來',
    '圍棋是一種心靈的放空',
    '每一盤棋都是一段旅程',
    '在棋局中找到寧靜',
    '圍棋讓我學會了堅持',
    '落子之間，感受當下',
    '圍棋讓心緒安定',
    '棋盤是我思考的空間',
    '下棋，讓我更了解自己',
  ];

  static const _millisecondsPerHour = 1000 * 3600;

  /// Returns a motivation line that is stable within the same hour but rotates
  /// across hours, using hours-since-epoch as the seed so the same clock
  /// hour on different days shows different sentences.
  static String get motivation {
    final hoursSinceEpoch =
        DateTime.now().millisecondsSinceEpoch ~/ _millisecondsPerHour;
    final index = Random(hoursSinceEpoch).nextInt(_motivations.length);
    return _motivations[index];
  }

  static String randomMotivation({String? except}) {
    if (_motivations.length == 1) {
      return _motivations.first;
    }
    final candidates = except == null
        ? _motivations
        : _motivations.where((motivation) => motivation != except).toList();
    return candidates[Random().nextInt(candidates.length)];
  }

  static const startAsBlackButton = '執黑先行';
  static const startAsWhiteButton = '執白後行';
  static const startSetupButton = '開始';
}

class _MotivationHeroTitle extends StatefulWidget {
  const _MotivationHeroTitle({
    super.key,
    required this.title,
    required this.motivation,
  });

  /// Fixed height of this widget; used by the parent Stack to position the
  /// scroll view so its hit-test area begins below this widget.
  static const double height = 72.0;

  final String title;
  final String motivation;

  @override
  State<_MotivationHeroTitle> createState() => _MotivationHeroTitleState();
}

class _MotivationHeroTitleState extends State<_MotivationHeroTitle>
    with SingleTickerProviderStateMixin {
  static bool _hasPlayedInProcess = false;

  static const _holdDuration = Duration(seconds: 5);
  static const _transitionDuration = Duration(milliseconds: 900);

  late final AnimationController _controller;
  late final Animation<double> _curve;
  late String _currentMotivation;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _currentMotivation = widget.motivation;
    final shouldPlayIntro = !_hasPlayedInProcess;
    _hasPlayedInProcess = true;
    _controller = AnimationController(
      vsync: this,
      duration: _transitionDuration,
      value: shouldPlayIntro ? 0 : 1,
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (shouldPlayIntro) {
      _holdTimer = Timer(_holdDuration, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleTitleTap() {
    _holdTimer?.cancel();
    if (_controller.isAnimating) {
      _controller.forward();
      return;
    }
    if (_controller.status != AnimationStatus.completed) {
      _controller.forward();
      return;
    }
    setState(() {
      _currentMotivation =
          _CaptureCopy.randomMotivation(except: _currentMotivation);
    });
  }

  void handleTap() {
    if (_controller.status == AnimationStatus.completed) {
      _handleMotivationTap();
    } else {
      _handleTitleTap();
    }
  }

  Widget _buildMotivationText(TextStyle style) {
    return RichText(
      key: ValueKey(_currentMotivation),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: '‘ ',
            style: style.copyWith(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              height: 1.0,
            ),
          ),
          TextSpan(
            text: _currentMotivation,
            style: style,
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationSwitcher(TextStyle style) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offset,
            child: child,
          ),
        );
      },
      child: _buildMotivationText(style),
    );
  }

  void _handleMotivationTap() {
    if (_controller.status != AnimationStatus.completed ||
        _controller.isAnimating) {
      return;
    }
    setState(() {
      _currentMotivation =
          _CaptureCopy.randomMotivation(except: _currentMotivation);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final style = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: palette.heroTitle,
      height: 1.12,
    );

    return SizedBox(
      height: _MotivationHeroTitle.height,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) {
          final progress = _curve.value;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topLeft,
            children: [
              Opacity(
                opacity: 1 - progress,
                child: IgnorePointer(
                  ignoring: progress >= 0.5,
                  child: Transform.translate(
                    offset: Offset(0, -10 * progress),
                    child: GestureDetector(
                      onTap: _handleTitleTap,
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: progress,
                child: IgnorePointer(
                  ignoring: progress < 0.5,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - progress)),
                    child: Transform.scale(
                      scale: 0.98 + 0.02 * progress,
                      alignment: Alignment.topLeft,
                      child: GestureDetector(
                        onTap: _handleMotivationTap,
                        child: _buildMotivationSwitcher(style),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _CaptureInitialModeLabelExt on CaptureInitialMode {
  String get label {
    return switch (this) {
      CaptureInitialMode.cross => '十字',
      CaptureInitialMode.twistCross => '扭十字',
      CaptureInitialMode.empty => '空白',
      CaptureInitialMode.setup => '擺棋',
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
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final primaryEnd = isClassic
        ? palette.primary
        : Color.lerp(palette.primary, CupertinoColors.black, 0.20)!;

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.primary, primaryEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: isClassic ? 0.20 : 0.24),
              blurRadius: isClassic ? 12 : 18,
              offset: Offset(0, isClassic ? 4 : 8),
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
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final secondaryFill = isClassic
        ? palette.setupPanelBackground
        : palette.primary.withValues(alpha: 0.10);
    final secondaryText = isClassic
        ? palette.setupActionText
        : Color.lerp(palette.primary, CupertinoColors.black, 0.18);
    final secondaryBorder =
        isClassic ? palette.setupActionText : CupertinoColors.transparent;

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: secondaryFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: secondaryBorder),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 12),
          borderRadius: BorderRadius.circular(14),
          onPressed: onPressed,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: secondaryText,
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
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final cardBackground =
        isClassic ? palette.setupPanelBackground : const Color(0xF7FFFDF9);

    return Container(
      padding: kPageSectionCardPadding,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(kPageSectionCardRadius),
        border: isClassic ? null : Border.all(color: const Color(0x26D8C1A4)),
        boxShadow: isClassic
            ? null
            : const [
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
    final palette = context.appPalette;
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: palette.setupTitleText,
      ),
    );
  }
}

class _OuterSectionTitle extends StatelessWidget {
  const _OuterSectionTitle({
    required this.title,
    this.isVisible = true,
  });

  final String title;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isVisible
              ? CupertinoColors.secondaryLabel.resolveFrom(context)
              : CupertinoColors.transparent,
        ),
      ),
    );
  }
}

class _PracticeHeader extends StatelessWidget {
  const _PracticeHeader({
    required this.title,
    required this.isAdjusting,
    required this.onAdjustTap,
  });

  final String title;
  final bool isAdjusting;
  final VoidCallback onAdjustTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
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
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.setupTitleText,
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
            isAdjusting ? '完成' : '調整 ›',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: palette.setupActionText,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeHintText extends StatelessWidget {
  const _ModeHintText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}

class _AiOpponentOption {
  const _AiOpponentOption({
    required this.config,
    required this.name,
    required this.subtitle,
    required this.summary,
  });

  final AiAlgorithmConfig config;
  final String name;
  final String subtitle;
  final String summary;
}

List<_AiOpponentOption> get _aiOpponentOptions => [
      _AiOpponentOption(
        config: AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1'),
        name: '小石',
        subtitle: 'Heuristic-1 · 入门启发',
        summary: '轻量规则判断，适合熟悉吃子节奏。',
      ),
      _AiOpponentOption(
        config: AiAlgorithmRegistry.configById('heuristic_counter_standard_v1'),
        name: '青竹',
        subtitle: 'Heuristic-2 · 反击启发',
        summary: '更偏防守和反击，计算很快。',
      ),
      _AiOpponentOption(
        config: AiAlgorithmRegistry.configById('mcts_counter_weak_v1'),
        name: '奥斯卡',
        subtitle: 'MCTS-1 · 快速试探',
        summary: '少量模拟搜索，有一定随机探索。',
      ),
      _AiOpponentOption(
        config: AiAlgorithmRegistry.configById('mcts_counter_standard_v1'),
        name: '阿尔法',
        subtitle: 'MCTS-2 · 战术搜索',
        summary: '更高搜索预算，带两层吃子风险检查。',
      ),
      _AiOpponentOption(
        config:
            AiAlgorithmRegistry.configById('hybrid_tactical_counter_weak_v1'),
        name: '云岚',
        subtitle: 'Hybrid-1 · 轻量战术',
        summary: '启发式和搜索混合，偏实战。',
      ),
      _AiOpponentOption(
        config: AiAlgorithmRegistry.configById(
            'hybrid_tactical_counter_standard_v1'),
        name: '玄策',
        subtitle: 'Hybrid-2 · 混合战术',
        summary: '更完整的混合战术配置。',
      ),
      _AiOpponentOption(
        config: AiAlgorithmRegistry.configById('katago_onnx_weak_v1'),
        name: '小林',
        subtitle: 'KataGo-1 · ONNX 策略',
        summary: '真实 KataGo ONNX 配置；不可用时会明确报错，不会 fallback。',
      ),
      _AiOpponentOption(
        config: AiAlgorithmRegistry.configById('katago_onnx_standard_v1'),
        name: '星野',
        subtitle: 'KataGo-2 · ONNX 搜索',
        summary: '真实 KataGo ONNX 标准配置；不可用时会明确报错，不会 fallback。',
      ),
    ];

List<_AiOpponentOption> get _playableAiOpponentOptions => _aiOpponentOptions
    .where(
        (option) => option.config.runtimeMode == AiAlgorithmRuntimeMode.native)
    .toList(growable: false);

List<_AiOpponentOption> _playableAiOpponentOptionsForMode(GameMode mode) {
  final nativeOptions = _playableAiOpponentOptions;
  return switch (mode) {
    GameMode.capture => nativeOptions,
    GameMode.territory => nativeOptions
        .where((option) =>
            option.config.frameworkId == AiAlgorithmFrameworkId.katago)
        .toList(growable: false),
  };
}

_AiOpponentOption _aiOpponentOption(String configId) {
  return _aiOpponentOptions.firstWhere(
    (option) => option.config.id == configId,
    orElse: () => _playableAiOpponentOptions.first,
  );
}

int _rankForAiAlgorithmConfig(AiAlgorithmConfig config) {
  return switch (config.strengthTier) {
    AiAlgorithmStrengthTier.weak => 8,
    AiAlgorithmStrengthTier.standard => 16,
    AiAlgorithmStrengthTier.strong => 24,
  };
}

AiAlgorithmConfig _aiAlgorithmConfigForRank(int rank) {
  if (rank <= 9) {
    return AiAlgorithmRegistry.configById('mcts_counter_weak_v1');
  }
  if (rank <= 19) {
    return AiAlgorithmRegistry.configById('mcts_counter_standard_v1');
  }
  return AiAlgorithmRegistry.configById('katago_onnx_standard_v1');
}

AiAlgorithmConfig _territoryAiAlgorithmConfigForRank(int rank) {
  if (rank <= 9) {
    return AiAlgorithmRegistry.configById('katago_onnx_weak_v1');
  }
  return AiAlgorithmRegistry.configById('katago_onnx_standard_v1');
}

class _ConfigPreview extends StatelessWidget {
  const _ConfigPreview({
    required this.difficultyMode,
    required this.computedRank,
    required this.activeAiConfig,
    required this.aiAlgorithmConfigId,
    required this.isTerritoryMode,
    required this.onTap,
  });

  final String difficultyMode;
  final int computedRank;
  final AiAlgorithmConfig? activeAiConfig;
  final String aiAlgorithmConfigId;
  final bool isTerritoryMode;
  final VoidCallback onTap;

  String get _difficultyLabel {
    final option = _aiOpponentOption(
      (difficultyMode == 'manual' ? aiAlgorithmConfigId : activeAiConfig?.id) ??
          aiAlgorithmConfigId,
    );
    return difficultyMode == 'manual'
        ? '指定·${option.name}'
        : '不分伯仲·${option.name}';
  }

  String get _algorithmLabel {
    final option = _aiOpponentOption(
      (difficultyMode == 'manual' ? aiAlgorithmConfigId : activeAiConfig?.id) ??
          aiAlgorithmConfigId,
    );
    if (difficultyMode == 'auto') {
      return '${option.subtitle} · 約${AiRankLevel.displayName(computedRank)}';
    }
    return option.subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isClassic ? 0 : 12,
          vertical: isClassic ? 4 : 14,
        ),
        decoration: isClassic
            ? null
            : BoxDecoration(
                color: palette.setupPanelBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.setupPanelBorder),
              ),
        child: Row(
          children: [
            Expanded(
              child: _ConfigPreviewItem(
                icon: CupertinoIcons.triangle_fill,
                title: 'AI 棋力',
                value: _difficultyLabel,
              ),
            ),
            const _ConfigPreviewDivider(),
            Expanded(
              child: _ConfigPreviewItem(
                icon: CupertinoIcons.star_fill,
                title: '算法',
                value: _algorithmLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigPreviewItem extends StatelessWidget {
  const _ConfigPreviewItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.setupIconBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: palette.setupIconForeground),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.setupLabelText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.setupValueText,
                ),
              ),
            ],
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
    final palette = context.appPalette;
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: palette.setupDivider,
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
    final palette = context.appPalette;
    final selectedIndex =
        options.indexWhere((option) => option.value == selectedValue);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.segmentTrack,
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
                    color: palette.segmentSelected,
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

class _AiOpponentTile extends StatelessWidget {
  const _AiOpponentTile({
    required this.selectedConfigId,
    required this.options,
    required this.onChanged,
  });

  final String selectedConfigId;
  final List<_AiOpponentOption> options;
  final ValueChanged<String> onChanged;

  _AiOpponentOption get _selected => options.firstWhere(
        (option) => option.config.id == selectedConfigId,
        orElse: () => options.first,
      );

  void _showPicker(BuildContext context) {
    final selected = _selected;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('選擇 AI 棋手'),
        message: Text('${selected.name}：${selected.summary}'),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: () {
                onChanged(option.config.id);
                Navigator.of(ctx).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.config.id == selected.config.id
                        ? '${option.name} · 目前'
                        : option.name,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final selected = _selected;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: palette.setupPanelBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.setupPanelBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.setupIconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                selected.name.substring(0, 1),
                style: TextStyle(
                  color: palette.setupIconForeground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.name,
                    style: TextStyle(
                      fontSize: 16.5,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      color: palette.setupValueText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selected.subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: palette.setupLabelText,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '›',
              style: TextStyle(
                fontSize: 18,
                height: 1,
                color: palette.setupActionText,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                color: iconContainerColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconBorderColor),
              ),
              alignment: Alignment.center,
              child: isLoading
                  ? const CupertinoActivityIndicator(radius: 10)
                  : Icon(
                      CupertinoIcons.photo_on_rectangle,
                      color: iconColor,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading ? '辨識中...' : '匯入截圖擺棋',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '自動辨識棋盤和棋子，預覽後微調進入擺棋',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: chevronColor,
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

class _KatagoPreparationDialog extends StatelessWidget {
  const _KatagoPreparationDialog({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final subtitleColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Center(
      child: CupertinoPopupSurface(
        isSurfacePainted: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
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
                    onPressed: onClose,
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: CupertinoColors.tertiaryLabel.resolveFrom(
                        context,
                      ),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Center(
                  child: CupertinoActivityIndicator(radius: 13),
                ),
                const SizedBox(height: 14),
                Text(
                  '正在準備 KataGo',
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
                  '首次使用需要下載約 70M 的模型，耗時取決於網路環境，通常約 30 秒。你可以關閉此視窗，切換其他棋手後再開始。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: onClose,
                  child: const Text('關閉'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
                      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
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
                      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
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
            (settings) => settings.boardCoordinateSystem);
    final gameState = GameState(
      boardSize: _boardSize,
      board: _board,
      currentPlayer: StoneColor.black,
    );
    final confidencePct = (widget.confidence * 100).toStringAsFixed(0);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('截圖辨識預覽'),
        previousPageTitle: _CaptureCopy.pageTitle,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _startSetup,
          child: const Text('開始擺棋'),
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
                  onPressed: _startSetup,
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
    required this.aiRank,
    required this.captureTarget,
    required this.gameMode,
    this.humanColor = StoneColor.black,
    this.initialMode = CaptureInitialMode.cross,
    this.initialBoardOverride,
    this.initialPlayerOverride,
    this.inheritedMoves = const [],
    this.inheritedMarkedMoveNumbers = const {},
  });

  final int aiRank;
  final int captureTarget;
  final GameMode gameMode;
  final StoneColor humanColor;
  final CaptureInitialMode initialMode;

  /// The initial board passed to the provider (needed to persist the record).
  final List<List<StoneColor>>? initialBoardOverride;

  /// The initial player override — non-null only for forked games that start
  /// with White to move. Persisted in [GameRecord] so history replay is
  /// correct.
  final StoneColor? initialPlayerOverride;
  final List<List<int>> inheritedMoves;
  final Set<int> inheritedMarkedMoveNumbers;

  @override
  State<CaptureGamePlayScreen> createState() => _CaptureGamePlayScreenState();
}

class _CaptureGamePlayScreenState extends State<CaptureGamePlayScreen>
    with SingleTickerProviderStateMixin {
  List<_HintMark> _hintMarks = const [];
  bool _isLoadingHints = false;
  bool _gameSaved = false;
  bool _resultDialogShown = false;
  String? _shownAiFailureReason;
  bool _moveLogVisible = false;
  bool _showMoveNumbers = false;
  bool _initializedScreenSettings = false;
  bool _forking = false;
  final Set<int> _markedMoveNumbers = <int>{};
  int? _reviewMoveIndex;
  List<GameState>? _reviewStates;

  // Training partner mode state.
  _TrainingHintSession? _trainingHintSession;
  KatagoPolicyPlane _trainingPolicyPlane = KatagoPolicyPlane.normal;
  _TrainingHintUiState _trainingHintState = _TrainingHintUiState.idle;

  /// Last-move coordinates shown while the ripple animation plays.
  List<int>? _rippleMove;
  late final AnimationController _rippleController;

  final _historyRepo = GameHistoryRepository();

  @override
  void initState() {
    super.initState();
    _markedMoveNumbers.addAll(
      widget.inheritedMarkedMoveNumbers.where((moveNo) => moveNo > 0),
    );
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedScreenSettings) return;
    _initializedScreenSettings = true;
    final settings = context.read<SettingsProvider?>();
    _moveLogVisible = settings?.showMoveLog ?? false;
    _showMoveNumbers = settings?.showMoveNumbers ?? false;
  }

  @override
  void dispose() {
    _trainingHintSession?.cancel();
    _trainingHintSession = null;
    _rippleController.dispose();
    super.dispose();
  }

  /// Converts a board of [StoneColor] to a list of int indices.
  static List<List<int>> _boardToInts(List<List<StoneColor>> board) =>
      board.map((row) => row.map((c) => c.index).toList()).toList();

  Future<void> _saveGame(CaptureGameProvider provider) async {
    if (_gameSaved) return;
    if (provider.moveLog.isEmpty) return; // nothing to save

    final outcome = switch (provider.result) {
      CaptureGameResult.blackWins => widget.humanColor == StoneColor.black
          ? GameOutcome.humanWins
          : GameOutcome.aiWins,
      CaptureGameResult.whiteWins => widget.humanColor == StoneColor.white
          ? GameOutcome.humanWins
          : GameOutcome.aiWins,
      CaptureGameResult.draw => GameOutcome.draw,
      CaptureGameResult.none => GameOutcome.abandoned,
    };

    final initialBoardCells = widget.initialBoardOverride != null
        ? _boardToInts(widget.initialBoardOverride!)
        : null;

    final now = DateTime.now();
    final moveCount = provider.moveLog.length;
    final validMarkedMoves = _markedMoveNumbers
        .where((moveNo) => moveNo > 0 && moveNo <= moveCount)
        .toList()
      ..sort();
    final record = GameRecord(
      id: now.toIso8601String(),
      playedAt: now,
      boardSize: provider.boardSize,
      captureTarget: provider.captureTarget,
      difficulty: provider.difficulty.name,
      gameMode: widget.gameMode,
      humanColorIndex: widget.humanColor.index,
      initialMode: captureInitialModeStorageKey(widget.initialMode),
      initialBoardCells: initialBoardCells,
      initialFirstPlayerIndex: widget.initialPlayerOverride?.index,
      moves: List<List<int>>.from(
        provider.moveLog.map((m) => List<int>.from(m)),
      ),
      markedMoveNumbers: validMarkedMoves,
      outcome: outcome,
      finalBoard: _boardToInts(provider.gameState.board),
      aiRank: widget.aiRank,
      aiStyleName: provider.aiStyle.name,
    );
    try {
      await _historyRepo.save(record);
      _gameSaved = true;
    } catch (_) {
      // Save failed; _gameSaved stays false so a retry is possible.
    }
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

          final blackCaptured = provider.gameState.capturedByBlack.length;
          final whiteCaptured = provider.gameState.capturedByWhite.length;
          final territoryScore = provider.territoryScore;
          final aiThinking = provider.isAiThinking;
          final isFinished = provider.result != CaptureGameResult.none;
          if (!isFinished) {
            _resultDialogShown = false;
          } else if (_trainingHintSession != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || provider.result == CaptureGameResult.none) {
                return;
              }
              _trainingHintSession?.cancel();
              _trainingHintSession = null;
              setState(() {
                _hintMarks = const [];
              });
            });
          }
          if (!provider.isPlacementMode && isFinished && !_resultDialogShown) {
            _resultDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _startRippleAnimation(context, provider);
            });
          }
          final aiFailureReason = provider.aiFailureReason;
          if (aiFailureReason == null) {
            _shownAiFailureReason = null;
          } else if (_shownAiFailureReason != aiFailureReason) {
            _shownAiFailureReason = aiFailureReason;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _showAiFailureDialog(aiFailureReason);
            });
          }
          final settings = context.watch<SettingsProvider?>();
          final showCaptureWarning = settings?.showCaptureWarning ?? true;
          final palette = context.appPalette;

          // Resolve review mode state.
          final moveLogLen = provider.moveLog.length;
          if (_reviewMoveIndex != null && _reviewMoveIndex! > moveLogLen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _reviewMoveIndex = null;
                  _reviewStates = null;
                });
              }
            });
          }
          final inReviewMode = _reviewMoveIndex != null &&
              _reviewMoveIndex! >= 1 &&
              _reviewMoveIndex! <= moveLogLen;
          final reviewGameState = (inReviewMode &&
                  _reviewStates != null &&
                  _reviewMoveIndex! < _reviewStates!.length)
              ? _reviewStates![_reviewMoveIndex!]
              : null;
          final displayedMoves = _displayMoveLog(provider);
          final displayedReviewMoveNumber = _displayReviewMoveNumber;
          final boardMoveNumberMoves = inReviewMode
              ? displayedMoves.take(displayedReviewMoveNumber ?? 0).toList()
              : displayedMoves;
          final selectedMarkMoveNumber = _activeMarkMoveNumber(provider);
          final selectedMoveMarked = selectedMarkMoveNumber != null &&
              _markedMoveNumbers.contains(selectedMarkMoveNumber);

          return CupertinoPageScaffold(
            backgroundColor: palette.pageBackground,
            navigationBar: CupertinoNavigationBar(
              backgroundColor: palette.pageBackground,
              border: null,
              previousPageTitle: _CaptureCopy.pageTitle,
              middle: Text(
                _buildGameTitle(provider, widget.humanColor),
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
                  onPressed: () => _showOperationMenu(
                    context: context,
                    buttonContext: buttonContext,
                    provider: provider,
                    settings: settings,
                  ),
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
                children: [
                  // Spec: docs/specs_map/main_game_flow.yaml#training_coach_katago
                  if (provider.trainingMode)
                    _TrainingModeStatusBar(
                      state: isFinished
                          ? _TrainingHintUiState.finished
                          : _trainingHintState,
                      hintCount: _hintMarks.length,
                      strategy: _trainingPolicyPlane,
                      onStrategyTap: () =>
                          _showTrainingStrategyPicker(context, provider),
                      onDetailsTap: _hintMarks.isEmpty
                          ? null
                          : () => _showTrainingDetails(context),
                      onLeave: () => _leaveTrainingMode(provider),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: (_moveLogVisible || inReviewMode)
                        ? _MoveLogStrip(
                            moves: displayedMoves,
                            boardSize: provider.boardSize,
                            coordinateSystem: settings?.boardCoordinateSystem ??
                                BoardCoordinateSystem.chinese,
                            currentPlayer: provider.gameState.currentPlayer,
                            markedMoveNumbers: _markedMoveNumbers,
                            palette: palette,
                            reviewMoveIndex: displayedReviewMoveNumber,
                            onMoveTap: (moveNumber) =>
                                _handleMoveTap(moveNumber, provider),
                            onHide: () => setState(() {
                              _moveLogVisible = false;
                              _reviewMoveIndex = null;
                              _reviewStates = null;
                            }),
                          )
                        : const SizedBox(height: 45),
                  ),
                  if (inReviewMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _ReviewActionButtons(
                          isForking: _forking,
                          currentMoveMarked: selectedMoveMarked,
                          onLatest: () => setState(() {
                            _reviewMoveIndex = null;
                            _hintMarks = const [];
                          }),
                          onFork: () => unawaited(_handleFork(provider)),
                          onToggleMark: () => _toggleMarkedMove(provider),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        inReviewMode ? 2 : 6,
                        16,
                        10,
                      ),
                      child: _CaptureBoardArea(
                        gameMode: widget.gameMode,
                        gameState: reviewGameState ?? provider.gameState,
                        coordinateSystem: settings?.boardCoordinateSystem ??
                            BoardCoordinateSystem.chinese,
                        enabled: !aiThinking && !isFinished && !inReviewMode,
                        hintMarks: inReviewMode ? const [] : _hintMarks,
                        showMoveNumbers: _showMoveNumbers,
                        moveNumberMoves: boardMoveNumberMoves,
                        showCaptureWarning: showCaptureWarning,
                        captureTarget: widget.captureTarget,
                        blackCaptured:
                            reviewGameState?.capturedByBlack.length ??
                                blackCaptured,
                        whiteCaptured:
                            reviewGameState?.capturedByWhite.length ??
                                whiteCaptured,
                        territoryScore: territoryScore,
                        humanColor: widget.humanColor,
                        rippleMove: _rippleMove,
                        rippleAnimation: _rippleController,
                        onTap: (row, col) => _handleBoardTap(
                          provider: provider,
                          row: row,
                          col: col,
                        ),
                        onReviewTap: inReviewMode ? _showReviewModeTip : null,
                      ),
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

  List<List<int>> _displayMoveLog(CaptureGameProvider provider) {
    if (widget.inheritedMoves.isEmpty) return provider.moveLog;
    return [
      for (final move in widget.inheritedMoves) List<int>.from(move),
      for (final move in provider.moveLog) List<int>.from(move),
    ];
  }

  int? get _displayReviewMoveNumber {
    final localReviewMove = _reviewMoveIndex;
    if (localReviewMove == null) return null;
    return widget.inheritedMoves.length + localReviewMove;
  }

  int? _activeMarkMoveNumber(CaptureGameProvider provider) {
    final reviewMove = _displayReviewMoveNumber;
    if (reviewMove != null) return reviewMove;
    final displayMoveCount =
        widget.inheritedMoves.length + provider.moveLog.length;
    return displayMoveCount == 0 ? null : displayMoveCount;
  }

  void _toggleMarkedMove(CaptureGameProvider provider) {
    final moveNo = _activeMarkMoveNumber(provider);
    if (moveNo == null) return;
    setState(() {
      if (!_markedMoveNumbers.add(moveNo)) {
        _markedMoveNumbers.remove(moveNo);
      }
    });
  }

  void _showOperationMenu({
    required BuildContext context,
    required BuildContext buttonContext,
    required CaptureGameProvider provider,
    required SettingsProvider? settings,
  }) {
    final canUndo = provider.canUndo;
    final canHint = !_isLoadingHints;
    final markMoveNumber = _activeMarkMoveNumber(provider);
    final canMarkMove = markMoveNumber != null;
    final canCopyMoveLog = provider.moveLog.isNotEmpty ||
        widget.inheritedMoves.isNotEmpty ||
        _orderedInitialMoves(provider).isNotEmpty;
    final canPass = provider.isTerritoryMode &&
        !provider.isAiThinking &&
        provider.result == CaptureGameResult.none &&
        provider.gameState.currentPlayer == widget.humanColor;
    final currentMoveMarked =
        markMoveNumber != null && _markedMoveNumbers.contains(markMoveNumber);
    final showCaptureWarning = settings?.showCaptureWarning ?? true;
    final coordinateSystem =
        settings?.boardCoordinateSystem ?? BoardCoordinateSystem.chinese;
    final canEnterTrainingMode = provider.isTerritoryMode &&
        !provider.trainingMode &&
        provider.result == CaptureGameResult.none &&
        !provider.isPlacementMode;
    final trainingModeUnavailableReason =
        provider.isTerritoryMode ? null : '吃 5 子模式不可用';
    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return;

    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonRect = buttonTopLeft & buttonBox.size;
    const menuWidth = 178.0;
    // 11 items plus dividers. The training item is taller when it needs a
    // disabled-state reason.
    const menuItemHeight = 48.0;
    const disabledTrainingItemHeight = 58.0;
    const menuDividerHeight = 0.6;
    const menuItemCount = 11;
    final menuHeight = menuItemCount * menuItemHeight +
        (menuItemCount - 1) * menuDividerHeight +
        (trainingModeUnavailableReason == null
            ? 0
            : disabledTrainingItemHeight - menuItemHeight);
    const edgePadding = 12.0;
    final media = MediaQuery.of(context);
    final preferredTop = buttonRect.top - menuHeight - 8;
    final menuOpensBelow = preferredTop < media.padding.top + edgePadding;
    final menuAlignment =
        menuOpensBelow ? Alignment.topRight : Alignment.bottomRight;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '關閉操作選單',
      barrierColor: CupertinoColors.black.withValues(alpha: 0.02),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (menuContext, _, __) {
        final menuMedia = MediaQuery.of(menuContext);
        final maxLeft = menuMedia.size.width - menuWidth - edgePadding;
        final left = (buttonRect.right - menuWidth).clamp(edgePadding, maxLeft);
        var top = preferredTop;
        final minTop = menuMedia.padding.top + edgePadding;
        if (top < minTop) {
          top = buttonRect.bottom + 8;
        }

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: _OperationContextMenu(
                aiConfigLabel: _aiOpponentOption(
                  provider.activeAlgorithmConfig?.id ??
                      _aiAlgorithmConfigForRank(widget.aiRank).id,
                ).subtitle,
                captureWarningEnabled: showCaptureWarning,
                moveLogVisible: _moveLogVisible,
                showMoveNumbers: _showMoveNumbers,
                currentMoveMarked: currentMoveMarked,
                canUndo: canUndo,
                canHint: canHint,
                canMarkMove: canMarkMove,
                canCopyMoveLog: canCopyMoveLog,
                canPass: canPass,
                canToggleCaptureWarning: settings != null,
                canEnterTrainingMode: canEnterTrainingMode,
                trainingModeUnavailableReason: trainingModeUnavailableReason,
                onToggleCaptureWarning: () {
                  Navigator.of(menuContext).pop();
                  settings?.setShowCaptureWarning(!showCaptureWarning);
                },
                onToggleMoveLog: () {
                  setState(() {
                    _moveLogVisible = !_moveLogVisible;
                    // Hiding the log also exits review mode so the user is
                    // not stuck in a mode they can no longer see.
                    if (!_moveLogVisible) {
                      _reviewMoveIndex = null;
                      _reviewStates = null;
                    }
                  });
                  Navigator.of(menuContext).pop();
                },
                onToggleMoveNumbers: () {
                  setState(() {
                    _showMoveNumbers = !_showMoveNumbers;
                  });
                  Navigator.of(menuContext).pop();
                },
                onToggleMarkMove: () {
                  Navigator.of(menuContext).pop();
                  if (!canMarkMove) return;
                  _toggleMarkedMove(provider);
                },
                onUndo: () {
                  Navigator.of(menuContext).pop();
                  provider.undoMove();
                },
                onHint: () {
                  Navigator.of(menuContext).pop();
                  _showHintsOnBoard(provider);
                },
                onPass: () async {
                  Navigator.of(menuContext).pop();
                  await provider.passTurn();
                },
                onEnterTrainingMode: () {
                  Navigator.of(menuContext).pop();
                  _enterTrainingMode(provider);
                },
                onCopyText: () {
                  Navigator.of(menuContext).pop();
                  _copyMovesAsText(provider, coordinateSystem);
                },
                onCopySgf: () {
                  Navigator.of(menuContext).pop();
                  _copyMovesAsSgf(provider);
                },
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            alignment: menuAlignment,
            child: child,
          ),
        );
      },
    );
  }

  String _buildGameTitle(CaptureGameProvider provider, StoneColor humanColor) {
    if (provider.result == CaptureGameResult.blackWins) return '對局結束';
    if (provider.result == CaptureGameResult.whiteWins) return '對局結束';
    if (provider.result == CaptureGameResult.draw) return '對局結束';
    if (provider.trainingMode) return 'AI 陪練模式';
    final colorName =
        provider.gameState.currentPlayer == StoneColor.black ? '黑棋' : '白棋';
    if (provider.isAiThinking ||
        (!provider.isPlacementMode &&
            provider.gameState.currentPlayer != humanColor)) {
      return 'AI（$colorName）正在思考';
    }
    return '輪到你（$colorName）落子';
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
      if (provider.trainingMode && provider.result == CaptureGameResult.none) {
        // Restart hint session for the new board position.
        _trainingHintSession?.cancel();
        _trainingHintState = _TrainingHintUiState.refreshing;
        _trainingHintSession = _TrainingHintSession(
          provider: provider,
          strategy: _trainingPolicyPlane,
          onUpdate: (marks) {
            if (!mounted) return;
            setState(() {
              _hintMarks = marks;
              _trainingHintState = marks.isEmpty
                  ? _TrainingHintUiState.empty
                  : _TrainingHintUiState.ready;
            });
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              if (_hintMarks.isEmpty &&
                  (_trainingHintState == _TrainingHintUiState.loading ||
                      _trainingHintState == _TrainingHintUiState.refreshing)) {
                _trainingHintState = _TrainingHintUiState.empty;
              }
            });
          },
        );
        _trainingHintSession!.start();
      } else {
        _trainingHintSession?.cancel();
        _trainingHintSession = null;
      }
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
            .where((pos) => pos.row >= 0 && pos.col >= 0)
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

  void _enterTrainingMode(CaptureGameProvider provider) {
    provider.enterTrainingMode();
    setState(() {
      _hintMarks = const [];
      _trainingHintState = _TrainingHintUiState.loading;
    });
    _trainingHintSession?.cancel();
    _trainingHintSession = _TrainingHintSession(
      provider: provider,
      strategy: _trainingPolicyPlane,
      onUpdate: (marks) {
        if (!mounted) return;
        setState(() {
          _hintMarks = marks;
          _trainingHintState = marks.isEmpty
              ? _TrainingHintUiState.empty
              : _TrainingHintUiState.ready;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          if (_hintMarks.isEmpty &&
              (_trainingHintState == _TrainingHintUiState.loading ||
                  _trainingHintState == _TrainingHintUiState.refreshing)) {
            _trainingHintState = _TrainingHintUiState.empty;
          }
        });
      },
    );
    _trainingHintSession!.start();
  }

  void _leaveTrainingMode(CaptureGameProvider provider) {
    _trainingHintSession?.cancel();
    _trainingHintSession = null;
    setState(() {
      _hintMarks = const [];
      _trainingHintState = _TrainingHintUiState.idle;
    });
    provider.exitTrainingMode();
  }

  void _showTrainingStrategyPicker(
    BuildContext context,
    CaptureGameProvider provider,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('策略視角'),
        actions: [
          for (final strategy in KatagoPolicyPlane.values)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _setTrainingStrategy(provider, strategy);
              },
              child: Text(strategy.explanationLabel),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _setTrainingStrategy(
    CaptureGameProvider provider,
    KatagoPolicyPlane strategy,
  ) {
    if (_trainingPolicyPlane == strategy) return;
    _trainingHintSession?.cancel();
    _trainingHintSession = null;
    setState(() {
      _trainingPolicyPlane = strategy;
      _hintMarks = const [];
      _trainingHintState = _TrainingHintUiState.refreshing;
    });
    if (!provider.trainingMode || provider.result != CaptureGameResult.none) {
      return;
    }
    _trainingHintSession = _TrainingHintSession(
      provider: provider,
      strategy: _trainingPolicyPlane,
      onUpdate: (marks) {
        if (!mounted) return;
        setState(() {
          _hintMarks = marks;
          _trainingHintState = marks.isEmpty
              ? _TrainingHintUiState.empty
              : _TrainingHintUiState.ready;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          if (_hintMarks.isEmpty &&
              (_trainingHintState == _TrainingHintUiState.refreshing ||
                  _trainingHintState == _TrainingHintUiState.loading)) {
            _trainingHintState = _TrainingHintUiState.empty;
          }
        });
      },
    );
    _trainingHintSession!.start();
  }

  void _showTrainingDetails(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('推薦詳情'),
        message: _TrainingExplanationPanel(hints: _hintMarks),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('完成'),
        ),
      ),
    );
  }

  _ResultDialogState _resultDialogState(CaptureGameProvider provider) {
    if (provider.result == CaptureGameResult.none) {
      throw StateError('Result dialog requires a finished game result.');
    }
    final humanWins = (provider.result == CaptureGameResult.blackWins &&
            widget.humanColor == StoneColor.black) ||
        (provider.result == CaptureGameResult.whiteWins &&
            widget.humanColor == StoneColor.white);
    if (provider.result == CaptureGameResult.draw) {
      return _ResultDialogState.draw;
    }
    return humanWins ? _ResultDialogState.victory : _ResultDialogState.notWin;
  }

  Future<void> _startRippleAnimation(
    BuildContext context,
    CaptureGameProvider provider,
  ) async {
    final lastMove = provider.moveLog.isNotEmpty ? provider.moveLog.last : null;
    setState(() => _rippleMove = lastMove);
    _rippleController.reset();
    await _rippleController.forward();
    if (!mounted) return;
    setState(() => _rippleMove = null);
    // ignore: use_build_context_synchronously
    await _showGameResultDialog(this.context, provider);
  }

  Future<void> _showGameResultDialog(
    BuildContext context,
    CaptureGameProvider provider,
  ) async {
    final resultState = _resultDialogState(provider);
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _GameResultDialog(
          state: resultState,
          onPlayAgain: () {
            provider.newGame();
            if (mounted) {
              setState(() {
                _hintMarks = const [];
                _isLoadingHints = false;
                _gameSaved = false;
                _resultDialogShown = false;
              });
            }
            Navigator.of(dialogContext).pop();
          },
          onReview: () {
            Navigator.of(dialogContext).pop();
            if (mounted) setState(() => _moveLogVisible = true);
          },
          onLeave: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).maybePop();
          },
        );
      },
    );
  }

  Future<void> _showAiFailureDialog(String reason) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('AI 無法落子'),
        content: Text(reason),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyMoveLogAsText(
    CaptureGameProvider provider,
    BoardCoordinateSystem coordinateSystem,
  ) async {
    if (provider.moveLog.isEmpty) return;
    final text = _buildMoveLogPlainText(provider, coordinateSystem);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showCopiedDialog('已複製棋譜文字');
  }

  Future<void> _copyMoveLogAsSgf(CaptureGameProvider provider) async {
    if (provider.moveLog.isEmpty) return;
    final sgf = _buildMoveLogSgf(provider);
    await Clipboard.setData(ClipboardData(text: sgf));
    if (!mounted) return;
    _showCopiedDialog('已複製 SGF');
  }

  void _showCopiedDialog(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('已複製'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  String _buildMoveLogPlainText(
    CaptureGameProvider provider,
    BoardCoordinateSystem coordinateSystem,
  ) {
    final lines = <String>[];
    for (var i = 0; i < provider.moveLog.length; i++) {
      final coordinate = _formatBoardCoordinate(
        provider.moveLog[i],
        provider.boardSize,
        coordinateSystem,
      );
      lines.add('${i + 1} $coordinate');
    }
    return lines.join('\n');
  }

  String _buildMoveLogSgf(CaptureGameProvider provider) {
    final root = StringBuffer(
      '(;FF[4]GM[1]CA[UTF-8]AP[go-puzzle]SZ[${provider.boardSize}]',
    );
    final initialPlayer = provider.initialPlayerOverride ?? StoneColor.black;
    if (initialPlayer == StoneColor.white) {
      root.write('PL[W]');
    }

    final board = _buildInitialBoard(provider);
    final blackSetup = <String>[];
    final whiteSetup = <String>[];
    final orderedInitialMoves = _orderedInitialMoves(provider);
    for (var i = 0; i < orderedInitialMoves.length; i++) {
      final move = orderedInitialMoves[i];
      if (move.length < 2) continue;
      final row = move[0];
      final col = move[1];
      if (row < 0 ||
          row >= provider.boardSize ||
          col < 0 ||
          col >= provider.boardSize) {
        continue;
      }
      final stone = _orderedInitialMoveColor(provider, board, row, col, i);
      if (stone == StoneColor.black) {
        blackSetup.add(_toSgfPoint(row, col));
      } else if (stone == StoneColor.white) {
        whiteSetup.add(_toSgfPoint(row, col));
      }
    }
    if (blackSetup.isNotEmpty) {
      root.write('AB');
      for (final point in blackSetup) {
        root.write('[$point]');
      }
    }
    if (whiteSetup.isNotEmpty) {
      root.write('AW');
      for (final point in whiteSetup) {
        root.write('[$point]');
      }
    }
    for (var i = 0; i < provider.moveLog.length; i++) {
      final move = provider.moveLog[i];
      if (move.length < 2) break;
      final row = move[0];
      final col = move[1];
      if (row < 0 ||
          row >= provider.boardSize ||
          col < 0 ||
          col >= provider.boardSize) {
        break;
      }
      final isBlackMove = i.isEven
          ? initialPlayer == StoneColor.black
          : initialPlayer == StoneColor.white;
      root.write(isBlackMove ? ';B[' : ';W[');
      root.write(_toSgfPoint(row, col));
      root.write(']');
    }
    root.write(')');
    return root.toString();
  }

  List<List<StoneColor>> _buildInitialBoard(CaptureGameProvider provider) {
    final board = List.generate(
      provider.boardSize,
      (_) => List<StoneColor>.filled(provider.boardSize, StoneColor.empty),
    );
    if (provider.initialBoardOverride != null) {
      final source = provider.initialBoardOverride!;
      for (var row = 0; row < provider.boardSize; row++) {
        for (var col = 0; col < provider.boardSize; col++) {
          board[row][col] = source[row][col];
        }
      }
      return board;
    }
    applyCaptureInitialLayout(board, provider.initialMode);
    return board;
  }

  String _toSgfPoint(int row, int col) {
    return '${String.fromCharCode(97 + col)}${String.fromCharCode(97 + row)}';
  }

  // ---------------------------------------------------------------------------
  // Review mode helpers
  // ---------------------------------------------------------------------------

  static List<GameState> _buildReviewStates(CaptureGameProvider provider) {
    final emptyBoard = List.generate(
      provider.boardSize,
      (_) => List<StoneColor>.filled(provider.boardSize, StoneColor.empty),
    );
    if (provider.initialBoardOverride != null) {
      final src = provider.initialBoardOverride!;
      for (int r = 0; r < provider.boardSize; r++) {
        for (int c = 0; c < provider.boardSize; c++) {
          emptyBoard[r][c] = src[r][c];
        }
      }
    } else {
      applyCaptureInitialLayout(emptyBoard, provider.initialMode);
    }
    var state = GameState(
      boardSize: provider.boardSize,
      board: emptyBoard,
      currentPlayer: provider.initialPlayerOverride ?? StoneColor.black,
      gameMode: provider.gameMode,
    );
    final states = <GameState>[state];
    for (final move in provider.moveLog) {
      if (move.length < 2) break;
      final next = move[0] == -1 && move[1] == -1
          ? GoEngine.passTurn(state)
          : GoEngine.placeStone(state, move[0], move[1]);
      if (next == null) break;
      state = next;
      states.add(state);
    }
    return states;
  }

  void _handleMoveTap(int moveNumber, CaptureGameProvider provider) {
    final moveLog = provider.moveLog;
    if (moveLog.isEmpty) return;
    // Always rebuild to avoid stale states after undo/redo that returns the
    // move log to the same length with different moves.
    _reviewStates = _buildReviewStates(provider);
    setState(() {
      _reviewMoveIndex = moveNumber.clamp(1, moveLog.length);
      _hintMarks = const [];
    });
  }

  Future<void> _handleFork(CaptureGameProvider provider) async {
    if (_forking) return;
    if (_reviewMoveIndex == null ||
        _reviewStates == null ||
        _reviewMoveIndex! >= _reviewStates!.length) {
      return;
    }
    // Set guard synchronously before the first await to prevent double-tap.
    _forking = true;
    try {
      await _saveGame(provider);
      if (!mounted) return;
      // Pop this game screen with a _ForkRequest result so the home screen can
      // push the forked game via _startForkedGame — this ensures _loadHistory()
      // is called when BOTH the original and forked games complete.
      final forkMoveCount = _reviewMoveIndex!;
      final forkInheritedMoves = [
        for (final move in provider.moveLog.take(_reviewMoveIndex!))
          List<int>.from(move),
      ];
      final forkMarkedMoveNumbers = _markedMoveNumbers
          .where((moveNo) => moveNo > 0 && moveNo <= forkMoveCount)
          .toSet();
      Navigator.of(context, rootNavigator: true).pop(
        _ForkRequest(
          initialBoardOverride: widget.initialBoardOverride == null
              ? null
              : widget.initialBoardOverride!
                  .map((row) => List<StoneColor>.from(row))
                  .toList(),
          initialPlayerOverride: widget.initialPlayerOverride,
          inheritedMoves: forkInheritedMoves,
          inheritedMarkedMoveNumbers: forkMarkedMoveNumbers,
          boardSize: provider.boardSize,
          captureTarget: provider.captureTarget,
          difficulty: provider.difficulty,
          gameMode: provider.gameMode,
          humanColor: provider.humanColor,
          aiStyle: provider.aiStyle,
          aiAlgorithmConfigId: provider.activeAlgorithmConfig?.id,
          aiRank: widget.aiRank,
          initialMode: widget.initialMode,
        ),
      );
    } finally {
      if (mounted) setState(() => _forking = false);
    }
  }

  void _showReviewModeTip() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('复盘模式'),
        content: const Text('请使用「分叉」从此处开始游戏'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  void _showCopyBanner(String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CopyBannerOverlay(
        message: message,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _copyMovesAsText(
    CaptureGameProvider provider,
    BoardCoordinateSystem coordinateSystem,
  ) async {
    final inheritedMoves = widget.inheritedMoves.isNotEmpty
        ? widget.inheritedMoves
        : _orderedInitialMoves(provider);
    final moves = provider.moveLog;
    if (inheritedMoves.isEmpty && moves.isEmpty) return;
    final boardSize = provider.boardSize;
    final total = inheritedMoves.length + moves.length;
    final padWidth = total.toString().length < 2 ? 2 : total.toString().length;
    final initialPlayer = provider.initialPlayerOverride ?? StoneColor.black;
    final buffer = StringBuffer();
    for (var i = 0; i < inheritedMoves.length; i++) {
      if (i > 0) buffer.write('\n');
      buffer.write(
        _formatMoveTextLine(
          moveNumber: i + 1,
          move: inheritedMoves[i],
          boardSize: boardSize,
          coordinateSystem: coordinateSystem,
          initialPlayer: initialPlayer,
          padWidth: padWidth,
        ),
      );
    }
    if (inheritedMoves.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write('---');
    }
    for (var i = 0; i < moves.length; i++) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(
        _formatMoveTextLine(
          moveNumber: inheritedMoves.length + i + 1,
          move: moves[i],
          boardSize: boardSize,
          coordinateSystem: coordinateSystem,
          initialPlayer: initialPlayer,
          padWidth: padWidth,
        ),
      );
    }
    await Clipboard.setData(ClipboardData(text: '${buffer.toString()}\n'));
    if (mounted) _showCopyBanner('棋譜已複製');
  }

  String _formatMoveTextLine({
    required int moveNumber,
    required List<int> move,
    required int boardSize,
    required BoardCoordinateSystem coordinateSystem,
    required StoneColor initialPlayer,
    required int padWidth,
  }) {
    final numStr = '$moveNumber'.padLeft(padWidth, '0');
    final isInitialColor = moveNumber.isOdd;
    final color = initialPlayer == StoneColor.black
        ? (isInitialColor ? 'B' : 'W')
        : (isInitialColor ? 'W' : 'B');
    final coordinate = _formatBoardCoordinate(
      move,
      boardSize,
      coordinateSystem,
    );
    return '$numStr $color[$coordinate]';
  }

  List<List<int>> _orderedInitialMoves(CaptureGameProvider provider) {
    return orderedCaptureInitialMoves(
      boardSize: provider.boardSize,
      initialMode: provider.initialMode,
      initialBoardOverride: provider.initialBoardOverride,
      initialPlayer: provider.initialPlayerOverride ?? StoneColor.black,
    );
  }

  StoneColor _orderedInitialMoveColor(
    CaptureGameProvider provider,
    List<List<StoneColor>> initialBoard,
    int row,
    int col,
    int index,
  ) {
    if (provider.initialBoardOverride == null &&
        (provider.initialMode == CaptureInitialMode.cross ||
            provider.initialMode == CaptureInitialMode.twistCross)) {
      return index.isEven ? StoneColor.black : StoneColor.white;
    }
    return initialBoard[row][col];
  }

  Future<void> _copyMovesAsSgf(CaptureGameProvider provider) async {
    final moves = provider.moveLog;
    final boardSize = provider.boardSize;

    // Reconstruct the initial board position.
    final initialBoard = List.generate(
      boardSize,
      (_) => List<StoneColor>.filled(boardSize, StoneColor.empty),
    );
    if (provider.initialBoardOverride != null) {
      for (int r = 0; r < boardSize; r++) {
        for (int c = 0; c < boardSize; c++) {
          initialBoard[r][c] = provider.initialBoardOverride![r][c];
        }
      }
    } else {
      applyCaptureInitialLayout(initialBoard, provider.initialMode);
    }

    final initialPlayer = provider.initialPlayerOverride ?? StoneColor.black;

    // Collect initial stones for AB / AW root properties.
    final abCoords = <String>[];
    final awCoords = <String>[];
    final orderedInitialMoves = _orderedInitialMoves(provider);
    for (var i = 0; i < orderedInitialMoves.length; i++) {
      final move = orderedInitialMoves[i];
      if (move.length < 2) continue;
      final row = move[0];
      final col = move[1];
      if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) {
        continue;
      }
      final stone =
          _orderedInitialMoveColor(provider, initialBoard, row, col, i);
      if (stone == StoneColor.black) {
        abCoords.add(_toSgfCoord(col, row));
      } else if (stone == StoneColor.white) {
        awCoords.add(_toSgfCoord(col, row));
      }
    }

    final buffer = StringBuffer('(;FF[4]GM[1]SZ[$boardSize]');
    if (abCoords.isNotEmpty) {
      buffer.write('AB${abCoords.map((s) => '[$s]').join()}');
    }
    if (awCoords.isNotEmpty) {
      buffer.write('AW${awCoords.map((s) => '[$s]').join()}');
    }
    if (initialPlayer != StoneColor.black) {
      buffer.write('PL[W]');
    }

    var currentColor = initialPlayer;
    for (final move in moves) {
      if (move.length < 2) break;
      final colorChar = currentColor == StoneColor.black ? 'B' : 'W';
      buffer.write(';$colorChar[${_toSgfCoord(move[1], move[0])}]');
      currentColor = currentColor == StoneColor.black
          ? StoneColor.white
          : StoneColor.black;
    }
    buffer.write(')');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) _showCopyBanner('SGF 已複製');
  }
}

class _CaptureBoardArea extends StatelessWidget {
  const _CaptureBoardArea({
    required this.gameMode,
    required this.gameState,
    required this.coordinateSystem,
    required this.enabled,
    required this.hintMarks,
    required this.showMoveNumbers,
    required this.moveNumberMoves,
    required this.showCaptureWarning,
    required this.captureTarget,
    required this.blackCaptured,
    required this.whiteCaptured,
    required this.territoryScore,
    required this.humanColor,
    required this.onTap,
    this.onReviewTap,
    this.rippleMove,
    this.rippleAnimation,
  });

  final GameMode gameMode;
  final GameState gameState;
  final BoardCoordinateSystem coordinateSystem;
  final bool enabled;
  final List<_HintMark> hintMarks;
  final bool showMoveNumbers;
  final List<List<int>> moveNumberMoves;
  final bool showCaptureWarning;
  final int captureTarget;
  final int blackCaptured;
  final int whiteCaptured;
  final TerritoryScore territoryScore;
  final StoneColor humanColor;
  final Future<bool> Function(int row, int col) onTap;
  final VoidCallback? onReviewTap;
  final List<int>? rippleMove;
  final Animation<double>? rippleAnimation;

  @override
  Widget build(BuildContext context) {
    final aiColor = humanColor.opponent;
    final humanCapturedAiCount =
        humanColor == StoneColor.black ? blackCaptured : whiteCaptured;
    final aiCapturedHumanCount =
        aiColor == StoneColor.black ? blackCaptured : whiteCaptured;
    final humanArea = humanColor == StoneColor.black
        ? territoryScore.blackArea
        : territoryScore.whiteArea;
    final aiArea = aiColor == StoneColor.black
        ? territoryScore.blackArea
        : territoryScore.whiteArea;

    return LayoutBuilder(
      builder: (context, constraints) {
        const markerHeightEstimate = 18.0;
        const markerGap = 8.0;
        const markerInset = 24.0;
        final boardExtent = min(
          constraints.maxWidth,
          max(
            160.0,
            constraints.maxHeight - markerHeightEstimate * 2 - markerGap * 2,
          ),
        );

        return Center(
          child: SizedBox(
            width: boardExtent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: markerInset),
                    child: gameMode == GameMode.territory
                        ? _TerritoryScoreCard(
                            isBlack: humanColor == StoneColor.black,
                            score: humanArea,
                            alignEnd: true,
                            label: '你',
                          )
                        : _PlayerSideCard(
                            isBlack: humanColor == StoneColor.black,
                            progress: aiCapturedHumanCount,
                            captureTarget: captureTarget,
                            alignEnd: true,
                          ),
                  ),
                ),
                const SizedBox(height: markerGap),
                SizedBox.square(
                  dimension: boardExtent,
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
                        gameState: gameState,
                        coordinateSystem: coordinateSystem,
                        enabled: enabled,
                        hintMarks: hintMarks,
                        showMoveNumbers: showMoveNumbers,
                        moveNumberMoves: moveNumberMoves,
                        showCaptureWarning: showCaptureWarning,
                        onTap: onTap,
                        onDisabledTap: onReviewTap,
                        rippleMove: rippleMove,
                        rippleAnimation: rippleAnimation,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: markerGap),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: markerInset),
                    child: gameMode == GameMode.territory
                        ? _TerritoryScoreCard(
                            isBlack: aiColor == StoneColor.black,
                            score: aiArea,
                            alignEnd: false,
                            label: 'AI',
                          )
                        : _PlayerSideCard(
                            isBlack: aiColor == StoneColor.black,
                            progress: humanCapturedAiCount,
                            captureTarget: captureTarget,
                            alignEnd: false,
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
}

class _PlayerSideCard extends StatelessWidget {
  const _PlayerSideCard({
    required this.isBlack,
    required this.progress,
    required this.captureTarget,
    required this.alignEnd,
  });

  final bool isBlack;
  final int progress;
  final int captureTarget;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final active = progress.clamp(0, captureTarget);
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Wrap(
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
    );
  }
}

class _TerritoryScoreCard extends StatelessWidget {
  const _TerritoryScoreCard({
    required this.isBlack,
    required this.score,
    required this.alignEnd,
    required this.label,
  });

  final bool isBlack;
  final int score;
  final bool alignEnd;
  final String label;

  @override
  Widget build(BuildContext context) {
    final background =
        isBlack ? const Color(0xFF2A2A2A) : const Color(0xFFF7F2EA);
    final textColor = isBlack ? CupertinoColors.white : const Color(0xFF4A3A2A);
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD5BEA6), width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$label · $score 目',
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _formatBoardCoordinate(
  List<int> move,
  int boardSize,
  BoardCoordinateSystem coordinateSystem,
) {
  if (move.length < 2) return '-';
  final row = move[0];
  final col = move[1];
  if (row == -1 && col == -1) return '停一手';
  if (col < 0 || col >= boardSize || row < 0 || row >= boardSize) {
    return '-';
  }
  return formatBoardCoordinate(
    row: row,
    col: col,
    boardSize: boardSize,
    coordinateSystem: coordinateSystem,
  );
}

String _formatChineseCoordinate(List<int> move, int boardSize) {
  if (move.length < 2) return '-';
  final row = move[0];
  final col = move[1];
  if (col < 0 || col >= boardSize || row < 0 || row >= boardSize) {
    return '-';
  }
  const chineseNums = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
    '十',
    '十一',
    '十二',
    '十三',
    '十四',
    '十五',
    '十六',
    '十七',
    '十八',
    '十九',
  ];
  final rowFromBottom = boardSize - row - 1;
  final rowLabel = rowFromBottom < chineseNums.length
      ? chineseNums[rowFromBottom]
      : '$rowFromBottom';
  return '${col + 1}$rowLabel';
}

/// Converts a 0-based (col, row) board position to the two-letter SGF
/// coordinate string (e.g., col=4, row=5 → "ef").
String _toSgfCoord(int col, int row) {
  return '${String.fromCharCode('a'.codeUnitAt(0) + col)}'
      '${String.fromCharCode('a'.codeUnitAt(0) + row)}';
}

class _CopyBannerOverlay extends StatefulWidget {
  const _CopyBannerOverlay({
    required this.message,
    required this.onDone,
  });

  final String message;
  final VoidCallback onDone;

  @override
  State<_CopyBannerOverlay> createState() => _CopyBannerOverlayState();
}

class _CopyBannerOverlayState extends State<_CopyBannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1400), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 48,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _opacity,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xE6333333),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveLogStrip extends StatefulWidget {
  const _MoveLogStrip({
    required this.moves,
    required this.boardSize,
    required this.coordinateSystem,
    required this.currentPlayer,
    required this.markedMoveNumbers,
    required this.palette,
    required this.onHide,
    this.reviewMoveIndex,
    this.onMoveTap,
  });

  final List<List<int>> moves;
  final int boardSize;
  final BoardCoordinateSystem coordinateSystem;
  final StoneColor currentPlayer;
  final Set<int> markedMoveNumbers;
  final AppThemePalette palette;
  final VoidCallback onHide;
  final int? reviewMoveIndex;
  final void Function(int moveNumber)? onMoveTap;

  @override
  State<_MoveLogStrip> createState() => _MoveLogStripState();
}

class _MoveLogStripState extends State<_MoveLogStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToLatestMove();
  }

  @override
  void didUpdateWidget(covariant _MoveLogStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moves.length > oldWidget.moves.length) {
      _scrollToLatestMove();
    }
  }

  void _scrollToLatestMove() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
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
                    for (var index = 0;
                        index < widget.moves.length;
                        index++) ...[
                      _MoveLogChip(
                        moveNumber: index + 1,
                        coordinate: _formatBoardCoordinate(
                          widget.moves[index],
                          widget.boardSize,
                          widget.coordinateSystem,
                        ),
                        stoneColor:
                            index.isEven ? StoneColor.black : StoneColor.white,
                        marked: widget.markedMoveNumbers.contains(index + 1),
                        palette: widget.palette,
                        isReviewing: widget.reviewMoveIndex == index + 1,
                        onTap: widget.onMoveTap != null
                            ? () => widget.onMoveTap!(index + 1)
                            : null,
                      ),
                      if (index != widget.moves.length - 1)
                        const SizedBox(width: 6),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveLogChip extends StatelessWidget {
  const _MoveLogChip({
    required this.moveNumber,
    required this.coordinate,
    required this.stoneColor,
    required this.marked,
    required this.palette,
    this.isReviewing = false,
    this.onTap,
  });

  final int moveNumber;
  final String coordinate;
  final StoneColor stoneColor;
  final bool marked;
  final AppThemePalette palette;
  final bool isReviewing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = isReviewing
        ? palette.primary.withValues(alpha: 0.88)
        : palette.segmentTrack.withValues(alpha: 0.82);
    final borderColor =
        isReviewing ? palette.primary : palette.primary.withValues(alpha: 0.16);
    final textColor = isReviewing ? CupertinoColors.white : palette.segmentText;
    final isBlackMove = stoneColor == StoneColor.black;
    final badgeBackground = isBlackMove
        ? const Color(0xFF2C2925)
        : CupertinoColors.white.withValues(alpha: 0.96);
    final badgeBorder = isBlackMove
        ? const Color(0xFF2C2925)
        : const Color(0xFF8F7359).withValues(alpha: 0.62);
    final badgeTextColor =
        isBlackMove ? CupertinoColors.white : const Color(0xFF4C4035);

    final chip = Container(
      padding: EdgeInsets.fromLTRB(4, 3, marked ? 14 : 7, 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor, width: isReviewing ? 1.1 : 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeBorder, width: 0.8),
            ),
            child: Text(
              '$moveNumber',
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 10,
                height: 1,
                color: badgeTextColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Padding(
            padding: EdgeInsets.only(right: marked ? 1 : 0),
            child: Text(
              coordinate,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                color: textColor,
                fontWeight: isReviewing ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );

    Widget result = chip;
    if (onTap != null) {
      result = GestureDetector(onTap: onTap, child: result);
    }
    if (!marked) return result;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        result,
        Positioned(
          top: 2,
          right: 2,
          child: Semantics(
            label: '已打标',
            excludeSemantics: true,
            child: const Text(
              '⭐',
              style: TextStyle(fontSize: 11, height: 1),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewActionButtons extends StatelessWidget {
  const _ReviewActionButtons({
    required this.isForking,
    required this.currentMoveMarked,
    required this.onLatest,
    required this.onFork,
    required this.onToggleMark,
  });

  final bool isForking;
  final bool currentMoveMarked;
  final VoidCallback onLatest;
  final VoidCallback onFork;
  final VoidCallback onToggleMark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFF2EBE3),
          borderRadius: BorderRadius.circular(14),
          onPressed: onLatest,
          child: const Text(
            '最新',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8F7359),
            ),
          ),
        ),
        const SizedBox(width: 10),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFC28A56),
          borderRadius: BorderRadius.circular(14),
          onPressed: isForking ? null : onFork,
          child: const Text(
            '分叉',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFF2EBE3),
          borderRadius: BorderRadius.circular(14),
          onPressed: onToggleMark,
          child: Text(
            currentMoveMarked ? '取消標記' : '標記',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8F7359),
            ),
          ),
        ),
      ],
    );
  }
}

class _OperationContextMenu extends StatelessWidget {
  const _OperationContextMenu({
    required this.aiConfigLabel,
    required this.captureWarningEnabled,
    required this.moveLogVisible,
    required this.showMoveNumbers,
    required this.currentMoveMarked,
    required this.canUndo,
    required this.canHint,
    required this.canMarkMove,
    required this.canCopyMoveLog,
    required this.canPass,
    required this.canToggleCaptureWarning,
    required this.canEnterTrainingMode,
    required this.trainingModeUnavailableReason,
    required this.onToggleCaptureWarning,
    required this.onToggleMoveLog,
    required this.onToggleMoveNumbers,
    required this.onToggleMarkMove,
    required this.onUndo,
    required this.onHint,
    required this.onPass,
    required this.onEnterTrainingMode,
    required this.onCopyText,
    required this.onCopySgf,
  });

  final String aiConfigLabel;
  final bool captureWarningEnabled;
  final bool moveLogVisible;
  final bool showMoveNumbers;
  final bool currentMoveMarked;
  final bool canUndo;
  final bool canHint;
  final bool canMarkMove;
  final bool canCopyMoveLog;
  final bool canPass;
  final bool canToggleCaptureWarning;
  final bool canEnterTrainingMode;
  final String? trainingModeUnavailableReason;
  final VoidCallback onToggleCaptureWarning;
  final VoidCallback onToggleMoveLog;
  final VoidCallback onToggleMoveNumbers;
  final VoidCallback onToggleMarkMove;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onPass;
  final VoidCallback onEnterTrainingMode;
  final VoidCallback onCopyText;
  final VoidCallback onCopySgf;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground
            .resolveFrom(context)
            .withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: CupertinoColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.24),
          width: 0.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OperationMenuItem(
              text: 'AI 棋力：$aiConfigLabel',
              enabled: false,
              onPressed: () {},
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: captureWarningEnabled ? '吃子預警：開' : '吃子預警：關',
              enabled: canToggleCaptureWarning,
              onPressed: onToggleCaptureWarning,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: moveLogVisible ? '隱藏棋譜' : '顯示棋譜',
              enabled: true,
              onPressed: onToggleMoveLog,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: showMoveNumbers ? '隱藏手數' : '顯示手數',
              enabled: true,
              onPressed: onToggleMoveNumbers,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: currentMoveMarked ? '取消標記此手' : '標記此手',
              enabled: canMarkMove,
              onPressed: onToggleMarkMove,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: '後退一手',
              enabled: canUndo,
              onPressed: onUndo,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: '停一手',
              enabled: canPass,
              onPressed: onPass,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: '提示一手',
              enabled: canHint,
              onPressed: onHint,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: '進入陪練模式',
              subtitle: trainingModeUnavailableReason,
              enabled: canEnterTrainingMode,
              onPressed: onEnterTrainingMode,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: '複製棋譜為文字',
              enabled: canCopyMoveLog,
              onPressed: onCopyText,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: '複製棋譜為 SGF',
              enabled: canCopyMoveLog,
              onPressed: onCopySgf,
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationMenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.6,
      margin: const EdgeInsets.only(left: 14),
      color: CupertinoColors.separator
          .resolveFrom(context)
          .withValues(alpha: 0.30),
    );
  }
}

class _OperationMenuItem extends StatelessWidget {
  const _OperationMenuItem({
    required this.text,
    this.subtitle,
    required this.enabled,
    required this.onPressed,
  });

  final String text;
  final String? subtitle;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final titleColor = enabled
        ? CupertinoColors.label.resolveFrom(context)
        : CupertinoColors.inactiveGray.resolveFrom(context);
    final subtitle = this.subtitle;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: enabled ? onPressed : null,
      child: SizedBox(
        height: subtitle == null ? 48 : 58,
        width: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: subtitle == null ? 16 : 15,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: CupertinoColors.inactiveGray.resolveFrom(context),
                  ),
                ),
              ],
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: disabled ? const Color(0xFFDCD4CC) : background,
      borderRadius: BorderRadius.circular(16),
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
    this.winRate,
    this.policyProbability,
    this.valueDelta,
    this.scoreLead,
    this.scoreUncertainty,
    this.strategyLabel,
    this.explanationSignals = const [],
    this.source = 'fallback',
  });

  final BoardPosition position;
  final StoneColor color;

  /// Optional win-rate for the player to move ([0.05, 0.95]). When non-null
  /// the painter draws a percentage label inside the dashed circle.
  final double? winRate;
  final double? policyProbability;
  final double? valueDelta;
  final double? scoreLead;
  final double? scoreUncertainty;
  final String? strategyLabel;
  final List<String> explanationSignals;
  final String source;
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

      final labelValue =
          hint.source == 'katago' ? hint.policyProbability : hint.winRate;
      if (labelValue != null) {
        final pct = (labelValue * 100).round();
        final label = '$pct%';
        final fontSize = (cell * 0.26).clamp(8.0, 18.0);
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: hintColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          center - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
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
    required this.coordinateSystem,
    required this.enabled,
    required this.hintMarks,
    required this.showMoveNumbers,
    required this.moveNumberMoves,
    required this.showCaptureWarning,
    required this.onTap,
    this.onDisabledTap,
    this.rippleMove,
    this.rippleAnimation,
  });

  final GameState gameState;
  final BoardCoordinateSystem coordinateSystem;
  final bool enabled;
  final List<_HintMark> hintMarks;
  final bool showMoveNumbers;
  final List<List<int>> moveNumberMoves;
  final bool showCaptureWarning;
  final Future<bool> Function(int row, int col) onTap;
  final VoidCallback? onDisabledTap;
  final List<int>? rippleMove;
  final Animation<double>? rippleAnimation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSizePx = constraints.biggest.shortestSide;
        final showRipple = rippleMove != null && rippleAnimation != null;
        return GestureDetector(
          onTapUp: enabled
              ? (d) => _handleTap(d.localPosition, boardSizePx)
              : (onDisabledTap != null ? (_) => onDisabledTap!() : null),
          child: SizedBox(
            width: boardSizePx,
            height: boardSizePx,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: GoBoardPainter(
                    gameState: gameState,
                    palette: context.appPalette,
                    coordinateSystem: coordinateSystem,
                    showMoveNumbers: showMoveNumbers,
                    moveNumberMoves: moveNumberMoves,
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
                if (showRipple)
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: rippleAnimation!,
                      builder: (_, __) => CustomPaint(
                        painter: _StoneRipplePainter(
                          boardSize: gameState.boardSize,
                          row: rippleMove![0],
                          col: rippleMove![1],
                          progress: rippleAnimation!.value,
                        ),
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
// Stone ripple painter
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// AI training hint session
// ---------------------------------------------------------------------------

/// Manages the background computation loop for AI training partner hints.
///
/// Fires once for the current board position. Entering training mode, playing a
/// move, or changing strategy creates a new session and cancels the old one.
class _TrainingHintSession {
  _TrainingHintSession({
    required this.provider,
    required this.strategy,
    required this.onUpdate,
    required this.onDone,
  });

  final CaptureGameProvider provider;
  final KatagoPolicyPlane strategy;
  final void Function(List<_HintMark>) onUpdate;
  final VoidCallback onDone;

  bool _cancelled = false;
  bool _computing = false;

  void start() {
    _fire();
  }

  void cancel() {
    _cancelled = true;
    provider.cancelTrainingSuggestions();
  }

  Future<void> _fire() async {
    if (_cancelled || _computing) return;
    _computing = true;
    try {
      final suggestions = await provider.suggestMovesWithWinRateAsync(
        count: 3,
        policyPlane: strategy,
      );
      if (_cancelled) return;
      final color = provider.gameState.currentPlayer;
      final marks = suggestions
          .map(
            (s) => _HintMark(
              position: s.position,
              color: color,
              winRate: s.winRate,
              policyProbability: s.policyProbability,
              valueDelta: s.valueDelta,
              scoreLead: s.scoreLead,
              scoreUncertainty: s.scoreUncertainty,
              strategyLabel: s.strategyLabel,
              explanationSignals: s.explanationSignals,
              source: s.source,
            ),
          )
          .toList();
      onUpdate(marks);
    } catch (_) {
      // Silently ignore failures — the board will just show no hints.
    } finally {
      _computing = false;
    }
    if (!_cancelled) onDone();
  }
}

// ---------------------------------------------------------------------------
// Training mode status bar
// ---------------------------------------------------------------------------

enum _TrainingHintUiState {
  idle,
  loading,
  refreshing,
  ready,
  empty,
  finished,
}

class _TrainingModeStatusBar extends StatelessWidget {
  const _TrainingModeStatusBar({
    required this.state,
    required this.hintCount,
    required this.strategy,
    required this.onStrategyTap,
    required this.onDetailsTap,
    required this.onLeave,
  });

  final _TrainingHintUiState state;
  final int hintCount;
  final KatagoPolicyPlane strategy;
  final VoidCallback onStrategyTap;
  final VoidCallback? onDetailsTap;
  final VoidCallback onLeave;

  String get _statusText {
    return switch (state) {
      _TrainingHintUiState.idle => '等待推薦',
      _TrainingHintUiState.loading => '正在思考',
      _TrainingHintUiState.refreshing => '正在更新',
      _TrainingHintUiState.ready => '已推薦 $hintCount 手',
      _TrainingHintUiState.empty => '暫無推薦',
      _TrainingHintUiState.finished => '對局已結束',
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.setupTitleText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (state == _TrainingHintUiState.ready &&
                    onDetailsTap != null) ...[
                  Text(
                    ' · ',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.setupTitleText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    minimumSize: Size.zero,
                    onPressed: onDetailsTap,
                    child: Text(
                      '詳情',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.setupActionText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (state != _TrainingHintUiState.finished)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              onPressed: onStrategyTap,
              child: Text(
                strategy.shortLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: palette.setupActionText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            onPressed: onLeave,
            child: Text(
              '離開陪練',
              style: TextStyle(
                fontSize: 13,
                color: palette.setupActionText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingExplanationPanel extends StatelessWidget {
  const _TrainingExplanationPanel({required this.hints});

  final List<_HintMark> hints;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground
            .resolveFrom(context)
            .withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in _visibleLines())
            SizedBox(
              height: 20,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: palette.setupTitleText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _visibleLines() {
    if (hints.isEmpty) {
      return const ['正在更新推薦', '', ''];
    }
    final lines = hints.take(3).map(_explanationLine).toList();
    while (lines.length < 3) {
      lines.add('');
    }
    return lines;
  }

  String _explanationLine(_HintMark hint) {
    final coord = '${hint.position.col + 1},${hint.position.row + 1}';
    if (hint.explanationSignals.isEmpty) {
      final pct =
          hint.winRate == null ? '' : ' ${(hint.winRate! * 100).round()}%';
      return '$coord$pct';
    }
    return '$coord · ${hint.explanationSignals.take(3).join(' · ')}';
  }
}

/// Draws a water-ripple animation radiating outward from the last-placed stone.
///
/// [progress] runs from 0.0 to 1.0 and covers exactly 1 animation round.
/// Three concentric rings are staggered
/// at 1/3-round intervals so the board always shows rings at different
/// expansion stages, like a water droplet ripple.
///
/// Each ring is rendered as a wide filled annulus (donut) so the wave area is
/// clearly visible. The last-placed stone also brightens as each wave sweeps
/// over it, giving a shockwave highlight effect.
class _StoneRipplePainter extends CustomPainter {
  const _StoneRipplePainter({
    required this.boardSize,
    required this.row,
    required this.col,
    required this.progress,
  });

  final int boardSize;
  final int row;
  final int col;

  /// 0.0 → 1.0 spanning 1 complete round.
  final double progress;

  // Board layout constants — must match GoBoardPainter / _TapBoard.
  static const double _kPadding = 0.5;

  // Stone radius ratio — must match GoBoardPainter._stoneSizeRatio.
  static const double _kStoneRatio = 0.48;

  @override
  void paint(Canvas canvas, Size size) {
    final n = boardSize;
    final cellSize = size.width / (n - 1 + 2 * _kPadding);
    final origin = cellSize * _kPadding;
    final cx = origin + col * cellSize;
    final cy = origin + row * cellSize;
    final center = Offset(cx, cy);

    // Stone radius (matches GoBoardPainter).
    final stoneRadius = cellSize * _kStoneRatio;

    // Maximum ring outer radius: 2.5 cells, capped at half the board.
    final maxRadius = (cellSize * 2.5).clamp(0.0, size.width / 2);

    // Width of each filled annular band — wide enough to be clearly visible.
    final ringWidth = cellSize * 0.55;

    // Derive per-round progress (0–1) that completes twice over the full run.
    final roundT = progress;

    // ---------- filled annular waves ----------
    const ringCount = 3;
    for (int i = 0; i < ringCount; i++) {
      // Each ring starts 1/3 of a round after the previous one.
      final phase = (roundT + i / ringCount) % 1.0;

      final outerR = maxRadius * phase;
      final innerR = (outerR - ringWidth).clamp(0.0, outerR);

      // Opacity: strong at small phase (near stone), fades to 0 at maxRadius.
      final opacity = (1.0 - phase) * 0.70;
      if (opacity <= 0 || outerR <= 0) continue;

      // Draw a filled donut using evenOdd winding so only the band is filled.
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: center, radius: outerR))
        ..addOval(Rect.fromCircle(center: center, radius: innerR));
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFD4A843).withValues(alpha: opacity)
          ..style = PaintingStyle.fill,
      );
    }

    // ---------- stone glow when a wave sweeps over it ----------
    // The stone brightens as each ring's leading edge crosses its circumference.
    // Peak brightness is when outerR ≈ stoneRadius; then fades outward.
    double maxGlow = 0.0;
    for (int i = 0; i < ringCount; i++) {
      final phase = (roundT + i / ringCount) % 1.0;
      final outerR = maxRadius * phase;
      // How close is the leading edge to the stone's circumference?
      final edgeDist = (outerR - stoneRadius).abs();
      final proximity = (1.0 - (edgeDist / (cellSize * 1.2)).clamp(0.0, 1.0));
      final contribution = proximity * (1.0 - phase);
      if (contribution > maxGlow) maxGlow = contribution;
    }

    if (maxGlow > 0.01) {
      // White-golden flash on the stone surface.
      canvas.drawCircle(
        center,
        stoneRadius,
        Paint()
          ..color = const Color(0xFFFFEEAA).withValues(alpha: maxGlow * 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(_StoneRipplePainter old) =>
      old.progress != progress ||
      old.row != row ||
      old.col != col ||
      old.boardSize != boardSize;
}

// ---------------------------------------------------------------------------
// History section
// ---------------------------------------------------------------------------

/// Section card shown on the home screen listing recent games.
class _HistorySectionCard extends StatelessWidget {
  const _HistorySectionCard({
    required this.history,
  });

  final List<GameRecord> history;

  static const _maxVisible = 5;

  @override
  Widget build(BuildContext context) {
    final visible = history.take(_maxVisible).toList();
    final palette = context.appPalette;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '歷史對局',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.setupTitleText,
                  ),
                ),
              ),
              if (history.length > _maxVisible)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  onPressed: () => _showAllHistory(context),
                  child: Text(
                    '全部 ›',
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.setupActionText,
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
      builder: (ctx) => _HistoryDetailSheet(record: record),
    );
  }

  void _showAllHistory(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _FullHistoryScreen(history: history),
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
    GameOutcome.draw: Color(0xFF8C7966),
    GameOutcome.abandoned: Color(0xFF8C7966),
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final date = _formatDate(record.playedAt);
    final boardLabel = '${record.boardSize} 路';
    final diffLabel = record.difficultyLevel.displayName;
    final modeLabel = record.gameMode.historyLabel;
    final outcomeLabel = record.outcome.displayName;
    final outcomeColor = isClassic
        ? switch (record.outcome) {
            GameOutcome.humanWins =>
              CupertinoColors.systemGreen.resolveFrom(context),
            GameOutcome.aiWins =>
              CupertinoColors.systemRed.resolveFrom(context),
            GameOutcome.draw => CupertinoColors.systemGrey.resolveFrom(context),
            GameOutcome.abandoned =>
              CupertinoColors.systemGrey.resolveFrom(context),
          }
        : _outcomeColors[record.outcome] ?? const Color(0xFF8C7966);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Row(
        children: [
          _StoneCircle(
              isBlack: record.humanColorIndex == StoneColor.black.index),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$boardLabel · $modeLabel · $diffLabel · ${record.totalMoves} 手',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.setupValueText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: palette.setupLabelText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          Icon(
            CupertinoIcons.chevron_right,
            color: isClassic
                ? CupertinoColors.tertiaryLabel.resolveFrom(context)
                : const Color(0xFFCBAF8C),
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
    final isClassic = context.isClassicAppTheme;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isBlack
            ? CupertinoColors.label.resolveFrom(context)
            : (isClassic
                ? CupertinoColors.systemBackground.resolveFrom(context)
                : const Color(0xFFF5F0E8)),
        border: Border.all(
          color: isBlack
              ? CupertinoColors.secondaryLabel.resolveFrom(context)
              : (isClassic
                  ? CupertinoColors.separator.resolveFrom(context)
                  : const Color(0xFFBCA88A)),
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
  const _HistoryDetailSheet({required this.record});

  final GameRecord record;

  @override
  Widget build(BuildContext context) {
    final boardState = _buildFinalBoardState(record);
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final coordinateSystem =
        context.select<SettingsProvider, BoardCoordinateSystem>(
            (settings) => settings.boardCoordinateSystem);

    return Container(
      decoration: BoxDecoration(
        color: palette.pageBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                color: palette.setupDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _OutcomeBadge(outcome: record.outcome),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.gameMode == GameMode.territory
                              ? '${record.boardSize} 路 · 圍空 · ${record.difficultyLevel.displayName}'
                              : '${record.boardSize} 路 · 吃${record.captureTarget}子 · ${record.difficultyLevel.displayName}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.setupValueText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFullDate(record.playedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.setupLabelText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '關閉',
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.setupActionText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
                      color: isClassic
                          ? palette.setupPanelBackground
                          : const Color(0xFFF0DFC9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GoBoardWidget(
                        gameState: boardState,
                        coordinateSystem: coordinateSystem,
                        onTap: null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '共 ${record.totalMoves} 手',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.setupLabelText,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (record.moves.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _PrimaryActionButton(
                  title: '瀏覽棋局',
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => _GameBrowseScreen(record: record),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
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
  const _FullHistoryScreen({required this.history});

  final List<GameRecord> history;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kPageBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('歷史對局'),
        previousPageTitle: '围棋谜题',
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
                builder: (_) => _HistoryDetailSheet(record: r),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Game browse screen – move-by-move viewer for a recorded game
// ---------------------------------------------------------------------------

class _GameBrowseScreen extends StatefulWidget {
  const _GameBrowseScreen({required this.record});

  final GameRecord record;

  @override
  State<_GameBrowseScreen> createState() => _GameBrowseScreenState();
}

class _GameBrowseScreenState extends State<_GameBrowseScreen> {
  late final List<GameState> _states;
  int _index = 0;
  bool _onlyMarked = false;

  @override
  void initState() {
    super.initState();
    _states = _buildStates(widget.record);
  }

  /// Replays every move in [record] and returns the ordered list of
  /// board states: index 0 = initial board, index N = after move N.
  static List<GameState> _buildStates(GameRecord record) {
    // Build initial board.
    final emptyBoard = List.generate(
      record.boardSize,
      (_) => List<StoneColor>.filled(record.boardSize, StoneColor.empty),
    );

    if (record.initialBoardCells != null) {
      final cells = record.initialBoardCells!;
      for (int r = 0; r < record.boardSize; r++) {
        for (int c = 0; c < record.boardSize; c++) {
          if (r < cells.length && c < cells[r].length) {
            emptyBoard[r][c] = StoneColor
                .values[cells[r][c].clamp(0, StoneColor.values.length - 1)];
          }
        }
      }
    } else {
      final initialMode = captureInitialModeFromStorageKey(
        record.initialMode,
        fallback: CaptureInitialMode.empty,
      );
      applyCaptureInitialLayout(emptyBoard, initialMode);
    }

    var state = GameState(
      boardSize: record.boardSize,
      board: emptyBoard,
      currentPlayer: record.initialFirstPlayer,
    );

    final states = <GameState>[state];
    for (final move in record.moves) {
      if (move.length < 2) break;
      final next = GoEngine.placeStone(state, move[0], move[1]);
      if (next == null) break;
      state = next;
      states.add(state);
    }
    return states;
  }

  int get _totalMoves => _states.length - 1;
  Set<int> get _markedMoves => widget.record.markedMoveNumbers.toSet();
  List<int> get _sortedMarkedMoves => _markedMoves.toList()..sort();

  String _moveCoordinate(int moveNo, BoardCoordinateSystem coordinateSystem) {
    if (moveNo <= 0 || moveNo > widget.record.moves.length) return '-';
    return _formatBoardCoordinate(
      widget.record.moves[moveNo - 1],
      widget.record.boardSize,
      coordinateSystem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coordinateSystem =
        context.select<SettingsProvider, BoardCoordinateSystem>(
            (settings) => settings.boardCoordinateSystem);
    final markedMoves = _sortedMarkedMoves;
    final hasMarkedMoves = markedMoves.isNotEmpty;
    final markedStart = hasMarkedMoves ? markedMoves.first : 0;
    final markedEnd = hasMarkedMoves ? markedMoves.last : _totalMoves;
    final isAtStart =
        _onlyMarked && hasMarkedMoves ? _index <= markedStart : _index == 0;
    final isAtEnd = _onlyMarked && hasMarkedMoves
        ? _index >= markedEnd
        : _index == _totalMoves;
    final current = _states[_index];

    return CupertinoPageScaffold(
      backgroundColor: kPageBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('棋局瀏覽'),
        previousPageTitle: '歷史對局',
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                          gameState: current,
                          coordinateSystem: coordinateSystem,
                          onTap: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Text(
                    _index == 0
                        ? '初始局面'
                        : '第 $_index 手 / 共 $_totalMoves 手 · 座標 ${_moveCoordinate(_index, coordinateSystem)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8C7966),
                    ),
                  ),
                  if (_index > 0 && _markedMoves.contains(_index))
                    const Text(
                      '⭐ 已標記手',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB68454)),
                    ),
                ],
              ),
            ),
            if (hasMarkedMoves)
              SizedBox(
                height: 40,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: () =>
                          setState(() => _onlyMarked = !_onlyMarked),
                      child: Text(_onlyMarked ? '只看標記：開' : '只看標記：關'),
                    ),
                    for (final move in markedMoves)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          color: _index == move
                              ? const Color(0xFFB68454)
                              : const Color(0x1AB68454),
                          onPressed: () => setState(
                              () => _index = move.clamp(0, _totalMoves)),
                          child: Text(
                            '第$move手 ${_moveCoordinate(move, coordinateSystem)}',
                            style: TextStyle(
                              color: _index == move
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF7A5A3A),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                children: [
                  _NavIconButton(
                    icon: CupertinoIcons.backward_end_fill,
                    enabled: !isAtStart,
                    onPressed: () => setState(() => _index =
                        (_onlyMarked && hasMarkedMoves) ? markedStart : 0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DecoratedActionButton(
                      text: '上一手',
                      filled: false,
                      onPressed: isAtStart
                          ? null
                          : () => setState(() {
                                if (_onlyMarked) {
                                  final prev = markedMoves
                                      .where((m) => m < _index)
                                      .toList();
                                  if (prev.isNotEmpty) {
                                    _index = prev.last;
                                  }
                                } else {
                                  _index--;
                                }
                              }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DecoratedActionButton(
                      text: '下一手',
                      filled: true,
                      onPressed: isAtEnd
                          ? null
                          : () => setState(() {
                                if (_onlyMarked) {
                                  final next = markedMoves
                                      .where((m) => m > _index)
                                      .toList();
                                  if (next.isNotEmpty) {
                                    _index = next.first;
                                  }
                                } else {
                                  _index++;
                                }
                              }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _NavIconButton(
                    icon: CupertinoIcons.forward_end_fill,
                    enabled: !isAtEnd,
                    onPressed: () => setState(() => _index =
                        (_onlyMarked && hasMarkedMoves)
                            ? markedEnd
                            : _totalMoves),
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

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: enabled ? onPressed : null,
      child: Icon(
        icon,
        size: 22,
        color: enabled
            ? const Color(0xFFB68454)
            : const Color(0xFFB68454).withValues(alpha: 0.35),
      ),
    );
  }
}

enum _ResultDialogState { victory, draw, notWin }

class _GameResultDialog extends StatelessWidget {
  const _GameResultDialog({
    required this.state,
    required this.onPlayAgain,
    required this.onReview,
    required this.onLeave,
  });

  final _ResultDialogState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onReview;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final (title, icon, accentColor) = switch (state) {
      _ResultDialogState.victory => (
          '勝利',
          CupertinoIcons.star_fill,
          isClassic
              ? CupertinoColors.systemGreen.resolveFrom(context)
              : const Color(0xFFE4A64F),
        ),
      _ResultDialogState.draw => (
          '和棋',
          CupertinoIcons.equal_circle_fill,
          isClassic
              ? CupertinoColors.systemGrey.resolveFrom(context)
              : const Color(0xFFC6A77F),
        ),
      _ResultDialogState.notWin => (
          '未獲勝',
          CupertinoIcons.flag_fill,
          isClassic
              ? CupertinoColors.systemRed.resolveFrom(context)
              : const Color(0xFFC57A5E),
        ),
    };
    final titleColor =
        isClassic ? palette.setupTitleText : const Color(0xFF2E2620);
    final cardGradient = isClassic
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.setupPanelBackground,
              palette.setupPanelBackground
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFCF7), Color(0xFFFFF4E7)],
          );
    final secondaryButtonColor =
        isClassic ? const Color(0xFFF2F2F7) : const Color(0xFFF7EFE6);
    final secondaryTextColor =
        isClassic ? const Color(0xFF007AFF) : const Color(0xFF9B6C3D);

    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.76,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(isClassic ? 24 : 30),
            border: Border.all(
              color:
                  isClassic ? const Color(0x1F000000) : const Color(0x22C59A6D),
              width: 0.7,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ResultMedallion(
                  icon: icon,
                  accentColor: accentColor,
                  classic: isClassic,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 32),
                _ResultActionButton(
                  text: '再來一局',
                  primary: true,
                  color: palette.primary,
                  textColor: CupertinoColors.white,
                  onPressed: onPlayAgain,
                ),
                const SizedBox(height: 14),
                _ResultActionButton(
                  text: '復盤',
                  primary: false,
                  color: secondaryButtonColor,
                  textColor: secondaryTextColor,
                  onPressed: onReview,
                ),
                const SizedBox(height: 14),
                _ResultActionButton(
                  text: '離開',
                  primary: false,
                  color: secondaryButtonColor,
                  textColor: secondaryTextColor,
                  onPressed: onLeave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultMedallion extends StatelessWidget {
  const _ResultMedallion({
    required this.icon,
    required this.accentColor,
    required this.classic,
  });

  final IconData icon;
  final Color accentColor;
  final bool classic;

  @override
  Widget build(BuildContext context) {
    final haloColor = accentColor.withValues(alpha: classic ? 0.12 : 0.18);
    return SizedBox(
      width: 112,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 44,
            decoration: BoxDecoration(
              color: haloColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: classic
                    ? [
                        accentColor.withValues(alpha: 0.94),
                        Color.lerp(accentColor, CupertinoColors.black, 0.12)!,
                      ]
                    : const [
                        Color(0xFFFFD68A),
                        Color(0xFFE5A34C),
                      ],
              ),
              border: Border.all(
                color: classic
                    ? CupertinoColors.white.withValues(alpha: 0.62)
                    : const Color(0xFFFFE6B7),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: CupertinoColors.white,
              size: 36,
            ),
          ),
          if (!classic) ...const [
            Positioned(
              left: 10,
              top: 20,
              child: Icon(
                CupertinoIcons.sparkles,
                size: 18,
                color: Color(0xFFFFDFA8),
              ),
            ),
            Positioned(
              right: 10,
              top: 26,
              child: Icon(
                CupertinoIcons.sparkles,
                size: 14,
                color: Color(0xFFFFDFA8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultActionButton extends StatelessWidget {
  const _ResultActionButton({
    required this.text,
    required this.primary,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  final String text;
  final bool primary;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: color,
        borderRadius: BorderRadius.circular(17),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 21,
            fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
            color: textColor,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
