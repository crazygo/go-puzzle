import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/board_image_recognizer.dart';
import '../game/capture_ai.dart';
import '../game/ai_rank_level.dart';
import '../game/game_mode.dart';
import '../game/go_engine.dart';
import '../models/board_position.dart';
import '../models/game_record.dart';
import '../models/game_state.dart';
import '../providers/capture_game_provider.dart';
import '../providers/settings_provider.dart';
import '../services/game_history_repository.dart';
import '../services/player_rank_repository.dart';
import '../theme/app_theme.dart';
import '../theme/theme_context.dart';
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
  static const _aiStyleKey = 'capture_setup.ai_style';
  static const _playModeKey = 'capture_setup.play_mode';
  // ─────────────────────────────────────────────────────────────────────────────
  static const _captureTarget = 5;

  static const _modeCapture = 'capture';
  static const _modeTerritory = 'territory';

  /// 'auto' = system matches rank from history; 'manual' = player picks rank.
  String _difficultyMode = 'auto';

  /// Selected rank when [_difficultyMode] == 'manual'.
  int _manualRank = AiRankLevel.defaultRank;

  /// AI style choice: one of the [CaptureAiStyle.name] values.
  String _aiStyleChoice = CaptureAiStyle.adaptive.name;

  /// Rank computed from recent history; refreshed on [_restoreSelection].
  int _computedRank = AiRankLevel.defaultRank;
  int _boardSize = 9;
  String _playMode = _modeCapture;
  CaptureInitialMode _initialMode = CaptureInitialMode.cross;
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
    _restoreSelection();
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final developerMode = context.select<SettingsProvider?, bool>(
      (settings) => settings?.developerMode ?? false,
    );

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const cardTop = (kPageHeroContentOffset + 8) * 2;
            final heroTitleTop = MediaQuery.of(context).padding.top + 36;
            // Let the scrollable content cover the hero title while scrolling.
            // The spacer preserves the first card's resting position.
            final adjustedCardTop =
                cardTop + MediaQuery.of(context).padding.top;

            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: PageHeroBanner(
                    title: _CaptureCopy.pageTitle,
                    titleWidget: const SizedBox.shrink(),
                    showOrbitalArt: false,
                  ),
                ),
                Positioned(
                  top: heroTitleTop,
                  left: 24,
                  right: 16,
                  child: _MotivationHeroTitle(
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
                                  title: '下一盘',
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
                                              label: '指定等级',
                                            ),
                                          ],
                                          onChanged: (value) =>
                                              _updateSelection(
                                                  difficultyMode: value),
                                        ),
                                        if (_difficultyMode == 'manual') ...[
                                          const SizedBox(height: 8),
                                          _RankPicker(
                                            selectedRank: _manualRank,
                                            onChanged: (rank) =>
                                                _updateSelection(
                                                    manualRank: rank),
                                          ),
                                        ],
                                        const SizedBox(height: 20),
                                        const _SectionLabel(title: 'AI 风格'),
                                        const SizedBox(height: 8),
                                        if (_playMode == _modeTerritory)
                                          _ModeHintText(
                                            text: kIsWeb
                                                ? '围空模式在 Web 端不生效；请在 iPhone 或 iPad 上使用。'
                                                : '围空模式固定使用围空引擎，风格选项不生效；仅难度生效。',
                                          )
                                        else
                                          _AiStyleTile(
                                            selectedStyleName: _aiStyleChoice,
                                            onChanged: (name) =>
                                                _updateSelection(
                                              aiStyleChoice: name,
                                            ),
                                          ),
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
                                              label: '摆棋',
                                            ),
                                          ],
                                          onChanged: (value) =>
                                              _updateSelection(
                                                  initialMode: value),
                                        ),
                                        const SizedBox(height: 20),
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
                                              label: '围空',
                                            ),
                                          ],
                                          onChanged: (value) =>
                                              _updateSelection(playMode: value),
                                        ),
                                        const SizedBox(height: 8),
                                        _ModeHintText(
                                          text: _playMode == _modeTerritory
                                              ? '围空模式为真实数子对局：双方连续停一手后按地盘结算。'
                                              : '吃子模式仍为先吃 $_captureTarget 子取胜。',
                                        ),
                                        const SizedBox(height: 20),
                                        const _SectionLabel(title: '棋盘'),
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
                                          manualRank: _manualRank,
                                          computedRank: _computedRank,
                                          aiStyleChoice: _aiStyleChoice,
                                          isTerritoryMode: _isTerritoryMode,
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
                                          title:
                                              _CaptureCopy.startAsBlackButton,
                                          onPressed: () => _startGame(
                                              humanColor: StoneColor.black),
                                        ),
                                        const SizedBox(height: 10),
                                        _SecondaryActionButton(
                                          title:
                                              _CaptureCopy.startAsWhiteButton,
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
      return '围空 · $boardSizeLabel · ${_initialMode.label}';
    }
    return '吃 $_captureTarget 子取胜 · $boardSizeLabel · ${_initialMode.label}';
  }

  String get _captureModeSegmentLabel => '吃 $_captureTarget 子取胜';
  bool get _isTerritoryMode => _playMode == _modeTerritory;
  GameMode get _selectedGameMode =>
      _isTerritoryMode ? GameMode.territory : GameMode.capture;

  Future<void> _restoreSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedBoardSize = prefs.getInt(_boardSizeKey);
    final savedInitialMode = prefs.getString(_initialModeKey);

    // Read new difficulty keys; normalize unknown stored values to 'auto'.
    final rawDifficultyMode = prefs.getString(_difficultyModeKey) ?? 'auto';
    String difficultyMode =
        (rawDifficultyMode == 'auto' || rawDifficultyMode == 'manual')
            ? rawDifficultyMode
            : 'auto';
    int manualRank = prefs.getInt(_manualRankKey) ?? AiRankLevel.defaultRank;

    // Migrate from legacy difficulty key if new keys haven't been set yet.
    if (!prefs.containsKey(_difficultyModeKey)) {
      final legacy = prefs.getString(_legacyDifficultyKey);
      if (legacy != null) {
        difficultyMode = 'manual';
        manualRank = switch (legacy) {
          'beginner' => 4,
          'advanced' => 20,
          _ => 12, // intermediate
        };
      }
    }

    // Clamp manual rank to valid range.
    manualRank = manualRank.clamp(AiRankLevel.min, AiRankLevel.max).toInt();

    final savedAiStyle = prefs.getString(_aiStyleKey);
    final savedPlayMode = prefs.getString(_playModeKey);

    // Compute rank from history for 'auto' mode.
    final history = await GameHistoryRepository().loadAllChronological();
    final computedRank = PlayerRankRepository.computeCurrentRank(history);

    if (!mounted) return;
    setState(() {
      _difficultyMode = difficultyMode;
      _manualRank = manualRank;
      _computedRank = computedRank;
      if (savedAiStyle != null &&
          CaptureAiStyle.values.any((s) => s.name == savedAiStyle)) {
        _aiStyleChoice = savedAiStyle;
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
    int? manualRank,
    String? aiStyleChoice,
    int? boardSize,
    CaptureInitialMode? initialMode,
    String? playMode,
  }) {
    setState(() {
      if (difficultyMode != null) _difficultyMode = difficultyMode;
      if (manualRank != null) _manualRank = manualRank;
      if (aiStyleChoice != null) _aiStyleChoice = aiStyleChoice;
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
      prefs.setInt(_manualRankKey, _manualRank),
      prefs.setString(_aiStyleKey, _aiStyleChoice),
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
    if (kIsWeb && _isTerritoryMode) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Web 暂不支持'),
          content: const Text('围空模式当前仅支持原生端运行，Web 端此选项不生效。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    _saveSelection();

    final effectiveRank =
        _difficultyMode == 'auto' ? _computedRank : _manualRank;
    final effectiveDifficulty = AiRankLevel.difficultyZone(effectiveRank);

    Navigator.of(context, rootNavigator: true)
        .push(
          CupertinoPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => CaptureGameProvider(
                boardSize: _boardSize,
                captureTarget: _captureTarget,
                difficulty: effectiveDifficulty,
                gameMode: _selectedGameMode,
                humanColor: humanColor,
                initialMode:
                    forceSetup ? CaptureInitialMode.setup : _initialMode,
                initialBoardOverride: initialBoard,
              )..setAiStyle(
                  CaptureAiStyle.values.firstWhere(
                    (s) => s.name == _aiStyleChoice,
                    orElse: () => CaptureAiStyle.adaptive,
                  ),
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
        .then((_) => _loadHistory());
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
    '基础',
    '构图',
    '主光',
    '补光',
    '环境',
    '格子',
    '动画',
  ];
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
        _RgbEditor(
          title: '棋盘本色',
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
          label: '窗光平台',
          value: widget.windowPlateau,
          min: 0.00,
          max: 0.95,
          onChanged: widget.onWindowPlateauChanged,
        ),
        _TuningSlider(
          label: '窗光衰减',
          value: widget.windowFalloff,
          min: 0.05,
          max: 1.50,
          onChanged: widget.onWindowFalloffChanged,
        ),
        _TuningSlider(
          label: '窗光旋转',
          value: widget.windowRotation,
          min: -3.14,
          max: 3.14,
          onChanged: widget.onWindowRotationChanged,
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
        _TuningSlider(
          label: 'lightMap 地板',
          value: widget.lightMapFloor,
          min: 0.00,
          max: 0.90,
          onChanged: widget.onLightMapFloorChanged,
        ),
        _TuningSlider(
          label: 'lightMap 强度',
          value: widget.lightMapIntensity,
          min: 0.50,
          max: 4.00,
          onChanged: widget.onLightMapIntensityChanged,
        ),
      ],
      [
        const _TuningGroupTitle('桂花树影'),
        _TuningSwitchRow(
          title: '启用树影',
          value: widget.leafShadowEnabled,
          onChanged: widget.onLeafShadowEnabledChanged,
        ),
        _TuningSlider(
          label: '叶影强度',
          value: widget.shadowOpacity,
          min: 0.04,
          max: 0.42,
          onChanged: widget.onShadowOpacityChanged,
        ),
        _TuningSlider(
          label: '叶影速度',
          value: widget.leafShadowSpeed,
          min: 0.00,
          max: 0.60,
          onChanged: widget.onLeafShadowSpeedChanged,
        ),
        _TuningSlider(
          label: '叶影摆幅',
          value: widget.leafShadowDrift,
          min: 0.00,
          max: 0.18,
          onChanged: widget.onLeafShadowDriftChanged,
        ),
        _TuningSlider(
          label: '叶影旋转',
          value: widget.leafShadowRotation,
          min: -3.14,
          max: 3.14,
          onChanged: widget.onLeafShadowRotationChanged,
        ),
        _TuningSlider(
          label: '叶影缩放',
          value: widget.leafShadowScale,
          min: 0.05,
          max: 2.40,
          onChanged: widget.onLeafShadowScaleChanged,
        ),
        _TuningSlider(
          label: '叶影位置 X',
          value: widget.leafShadowOffsetX,
          min: -2.00,
          max: 2.00,
          onChanged: widget.onLeafShadowOffsetXChanged,
        ),
        _TuningSlider(
          label: '叶影位置 Z',
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

  static const _motivations = [
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

  static const startAsBlackButton = '执黑先行';
  static const startAsWhiteButton = '执白后行';
  static const startSetupButton = '开始';
}

class _MotivationHeroTitle extends StatefulWidget {
  const _MotivationHeroTitle({
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
    final palette = context.appPalette;
    final isClassic = identical(palette, AppThemePalette.classic);
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
    final isClassic = identical(palette, AppThemePalette.classic);
    final secondaryFill = isClassic
        ? CupertinoColors.systemGrey5.resolveFrom(context)
        : palette.primary.withValues(alpha: 0.10);
    final secondaryText = isClassic
        ? CupertinoColors.systemBlue.resolveFrom(context)
        : Color.lerp(palette.primary, CupertinoColors.black, 0.18);

    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        borderRadius: BorderRadius.circular(14),
        color: secondaryFill,
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
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isClassic = identical(palette, AppThemePalette.classic);
    final cardBackground = isClassic
        ? CupertinoColors.systemBackground.resolveFrom(context)
        : const Color(0xF7FFFDF9);
    final cardBorder = isClassic
        ? CupertinoColors.systemGrey5.resolveFrom(context)
        : const Color(0x26D8C1A4);

    return Container(
      padding: kPageSectionCardPadding,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(kPageSectionCardRadius),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: isClassic ? 12 : 24,
            offset: Offset(0, isClassic ? 4 : 10),
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
            isAdjusting ? '完成' : '调整 ›',
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

class _ConfigPreview extends StatelessWidget {
  const _ConfigPreview({
    required this.difficultyMode,
    required this.manualRank,
    required this.computedRank,
    required this.aiStyleChoice,
    required this.isTerritoryMode,
  });

  final String difficultyMode;
  final int manualRank;
  final int computedRank;
  final String aiStyleChoice;
  final bool isTerritoryMode;

  String get _difficultyLabel {
    if (difficultyMode == 'manual') {
      return '指定·${AiRankLevel.displayName(manualRank)}';
    }
    return '不分伯仲·约${AiRankLevel.displayName(computedRank)}';
  }

  String get _aiStyleLabel {
    if (isTerritoryMode) return '固定围空引擎';
    return CaptureAiStyle.values
        .firstWhere(
          (s) => s.name == aiStyleChoice,
          orElse: () => CaptureAiStyle.adaptive,
        )
        .label;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
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
              title: 'AI 风格',
              value: _aiStyleLabel,
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
  const _AiStyleTile({
    required this.selectedStyleName,
    required this.onChanged,
  });

  final String selectedStyleName;
  final ValueChanged<String> onChanged;

  CaptureAiStyle get _selectedStyle => CaptureAiStyle.values.firstWhere(
        (s) => s.name == selectedStyleName,
        orElse: () => CaptureAiStyle.adaptive,
      );

  void _showPicker(BuildContext context) {
    final style = _selectedStyle;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择 AI 风格'),
        message: Text('${style.label}：${style.summary}'),
        actions: [
          for (final s in CaptureAiStyle.values)
            CupertinoActionSheetAction(
              onPressed: () {
                onChanged(s.name);
                Navigator.of(ctx).pop();
              },
              child: Text(
                s == style ? '${s.label} · 当前' : '${s.label}  ${s.summary}',
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
    final style = _selectedStyle;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => _showPicker(context),
      child: Container(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    style: const TextStyle(
                      fontSize: 16.5,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF36271E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    style.summary,
                    style: const TextStyle(
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
      ),
    );
  }
}

/// A compact inline rank picker showing all 28 ranks as a drum-roll picker.
class _RankPicker extends StatefulWidget {
  const _RankPicker({
    required this.selectedRank,
    required this.onChanged,
  });

  final int selectedRank;
  final ValueChanged<int> onChanged;

  @override
  State<_RankPicker> createState() => _RankPickerState();
}

class _RankPickerState extends State<_RankPicker> {
  late final FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(
      initialItem: widget.selectedRank - AiRankLevel.min,
    );
  }

  @override
  void didUpdateWidget(_RankPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jump to the new rank when the parent drives a programmatic change (e.g.
    // legacy migration sets an initial value before the picker is touched).
    if (oldWidget.selectedRank != widget.selectedRank) {
      final targetItem = widget.selectedRank - AiRankLevel.min;
      if (_scrollController.hasClients &&
          _scrollController.selectedItem != targetItem) {
        _scrollController.jumpToItem(targetItem);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF4EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22D2B28E)),
      ),
      child: CupertinoPicker(
        scrollController: _scrollController,
        itemExtent: 36,
        onSelectedItemChanged: (index) {
          widget.onChanged(AiRankLevel.min + index);
        },
        children: [
          for (int rank = AiRankLevel.min; rank <= AiRankLevel.max; rank++)
            Center(
              child: Text(
                AiRankLevel.displayName(rank),
                style: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF36271E),
                ),
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
    final palette = context.appPalette;
    final isClassic = identical(palette, AppThemePalette.classic);
    final iconContainerColor = isClassic
        ? CupertinoColors.systemIndigo
            .resolveFrom(context)
            .withValues(alpha: 0.16)
        : palette.primary.withValues(alpha: 0.16);
    final iconColor = isClassic
        ? CupertinoColors.systemIndigo.resolveFrom(context)
        : palette.primary;
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
                    isLoading ? '识别中...' : '导入截屏摆棋',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '自动识别棋盘和棋子，预览后微调进入摆棋',
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
    required this.aiRank,
    required this.captureTarget,
    required this.gameMode,
    this.humanColor = StoneColor.black,
    this.initialMode = CaptureInitialMode.cross,
    this.initialBoardOverride,
  });

  final int aiRank;
  final int captureTarget;
  final GameMode gameMode;
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
  bool _resultDialogShown = false;
  bool _moveLogVisible = false;
  final Set<int> _markedMoveNumbers = <int>{};
  final GlobalKey _operationButtonKey = GlobalKey();

  final _historyRepo = GameHistoryRepository();

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
          }
          if (!provider.isPlacementMode && isFinished && !_resultDialogShown) {
            _resultDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _showGameResultDialog(context, provider);
            });
          }
          final settings = context.watch<SettingsProvider?>();
          final showCaptureWarning = settings?.showCaptureWarning ?? true;
          final palette = settings?.appTheme.palette ?? context.appPalette;

          return CupertinoPageScaffold(
            backgroundColor: const Color(0xFFF3F0ED),
            navigationBar: CupertinoNavigationBar(
              backgroundColor: const Color(0xFFF3F0ED),
              border: null,
              previousPageTitle: _CaptureCopy.pageTitle,
              middle: Text(
                _buildGameTitle(provider, widget.humanColor),
                style: const TextStyle(
                  color: Color(0xFF2E2620),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: CupertinoButton(
                key: _operationButtonKey,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => _showOperationMenu(
                  context: context,
                  provider: provider,
                  settings: settings,
                ),
                child: Text(
                  '操作',
                  style: TextStyle(
                    color: Color(0xFFC3996E),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _moveLogVisible
                        ? _MoveLogStrip(
                            moves: provider.moveLog,
                            boardSize: provider.boardSize,
                            currentPlayer: provider.gameState.currentPlayer,
                            markedMoveNumbers: _markedMoveNumbers,
                            palette: palette,
                            onHide: () => setState(() {
                              _moveLogVisible = false;
                            }),
                          )
                        : const SizedBox(height: 45),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: _CaptureBoardArea(
                        gameMode: widget.gameMode,
                          gameState: provider.gameState,
                          enabled: !aiThinking && !isFinished,
                          hintMarks: _hintMarks,
                          showCaptureWarning: showCaptureWarning,
                          captureTarget: widget.captureTarget,
                          blackCaptured: blackCaptured,
                          whiteCaptured: whiteCaptured,
                          territoryScore: territoryScore,
                          humanColor: widget.humanColor,
                        onTap: (row, col) => _handleBoardTap(
                          provider: provider,
                          row: row,
                          col: col,
                        ),
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

  void _showOperationMenu({
    required BuildContext context,
    required CaptureGameProvider provider,
    required SettingsProvider? settings,
  }) {
    final canUndo = provider.canUndo;
    final canHint = !_isLoadingHints;
    final canMarkMove = provider.moveLog.isNotEmpty;
    final canPass = provider.isTerritoryMode &&
        !provider.isAiThinking &&
        provider.result == CaptureGameResult.none &&
        provider.gameState.currentPlayer == widget.humanColor;
    final currentMoveMarked =
        _markedMoveNumbers.contains(provider.moveLog.length);
    final showCaptureWarning = settings?.showCaptureWarning ?? true;
    final buttonContext = _operationButtonKey.currentContext ?? context;
    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return;

    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final buttonRect = buttonTopLeft & buttonBox.size;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭操作菜单',
      barrierColor: CupertinoColors.black.withValues(alpha: 0.02),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (menuContext, _, __) {
        const menuWidth = 178.0;
        const menuHeight = 336.0;
        const edgePadding = 12.0;
        final media = MediaQuery.of(menuContext);
        final maxLeft = media.size.width - menuWidth - edgePadding;
        final left = (buttonRect.right - menuWidth).clamp(edgePadding, maxLeft);
        var top = buttonRect.top - menuHeight - 8;
        final minTop = media.padding.top + edgePadding;
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
                aiStyleLabel:
                    provider.isTerritoryMode ? '固定围空引擎' : provider.aiStyle.label,
                canChangeAiStyle: !provider.isTerritoryMode,
                captureWarningEnabled: showCaptureWarning,
                moveLogVisible: _moveLogVisible,
                currentMoveMarked: currentMoveMarked,
                canUndo: canUndo,
                canHint: canHint,
                canMarkMove: canMarkMove,
                canPass: canPass,
                canToggleCaptureWarning: settings != null,
                onAiStyle: () {
                  Navigator.of(menuContext).pop();
                  if (!provider.isTerritoryMode) {
                    _showStylePicker(context, provider);
                  }
                },
                onToggleCaptureWarning: () {
                  Navigator.of(menuContext).pop();
                  settings?.setShowCaptureWarning(!showCaptureWarning);
                },
                onToggleMoveLog: () {
                  Navigator.of(menuContext).pop();
                  setState(() {
                    _moveLogVisible = !_moveLogVisible;
                  });
                },
                onToggleMarkMove: () {
                  Navigator.of(menuContext).pop();
                  if (!canMarkMove) return;
                  setState(() {
                    final moveNo = provider.moveLog.length;
                    if (!_markedMoveNumbers.add(moveNo)) {
                      _markedMoveNumbers.remove(moveNo);
                    }
                  });
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
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            alignment: Alignment.bottomRight,
            child: child,
          ),
        );
      },
    );
  }

  String _buildGameTitle(CaptureGameProvider provider, StoneColor humanColor) {
    if (provider.result == CaptureGameResult.blackWins) return '对局结束';
    if (provider.result == CaptureGameResult.whiteWins) return '对局结束';
    if (provider.result == CaptureGameResult.draw) return '对局结束';
    final colorName =
        provider.gameState.currentPlayer == StoneColor.black ? '黑棋' : '白棋';
    if (provider.isAiThinking ||
        (!provider.isPlacementMode &&
            provider.gameState.currentPlayer != humanColor)) {
      return 'AI（$colorName）正在思考';
    }
    return '轮到你（$colorName）落子';
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
          onReview: () => Navigator.of(dialogContext).pop(),
          onLeave: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).maybePop();
          },
        );
      },
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

class _CaptureBoardArea extends StatelessWidget {
  const _CaptureBoardArea({
    required this.gameMode,
    required this.gameState,
    required this.enabled,
    required this.hintMarks,
    required this.showCaptureWarning,
    required this.captureTarget,
    required this.blackCaptured,
    required this.whiteCaptured,
    required this.territoryScore,
    required this.humanColor,
    required this.onTap,
  });

  final GameMode gameMode;
  final GameState gameState;
  final bool enabled;
  final List<_HintMark> hintMarks;
  final bool showCaptureWarning;
  final int captureTarget;
  final int blackCaptured;
  final int whiteCaptured;
  final TerritoryScore territoryScore;
  final StoneColor humanColor;
  final Future<bool> Function(int row, int col) onTap;

  @override
  Widget build(BuildContext context) {
    final aiColor = humanColor.opponent;
    final humanCapturedAiCount =
        humanColor == StoneColor.black ? blackCaptured : whiteCaptured;
    final aiCapturedHumanCount =
        aiColor == StoneColor.black ? blackCaptured : whiteCaptured;
    final humanArea =
        humanColor == StoneColor.black ? territoryScore.blackArea : territoryScore.whiteArea;
    final aiArea =
        aiColor == StoneColor.black ? territoryScore.blackArea : territoryScore.whiteArea;

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
                        enabled: enabled,
                        hintMarks: hintMarks,
                        showCaptureWarning: showCaptureWarning,
                        onTap: onTap,
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
    final background = isBlack ? const Color(0xFF2A2A2A) : const Color(0xFFF7F2EA);
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

String _formatBoardCoordinate(List<int> move, int boardSize) {
  if (move.length < 2) return '-';
  const columns = 'ABCDEFGHJKLMNOPQRST';
  final row = move[0];
  final col = move[1];
  if (row == -1 && col == -1) return '停一手';
  if (col < 0 ||
      col >= boardSize ||
      col >= columns.length ||
      row < 0 ||
      row >= boardSize) {
    return '-';
  }
  return '${columns[col]}${boardSize - row}';
}

class _MoveLogStrip extends StatefulWidget {
  const _MoveLogStrip({
    required this.moves,
    required this.boardSize,
    required this.currentPlayer,
    required this.markedMoveNumbers,
    required this.palette,
    required this.onHide,
  });

  final List<List<int>> moves;
  final int boardSize;
  final StoneColor currentPlayer;
  final Set<int> markedMoveNumbers;
  final AppThemePalette palette;
  final VoidCallback onHide;

  @override
  State<_MoveLogStrip> createState() => _MoveLogStripState();
}

class _MoveLogStripState extends State<_MoveLogStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _MoveLogStrip oldWidget) {
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
                    for (var index = 0;
                        index < widget.moves.length;
                        index++) ...[
                      _MoveLogChip(
                        moveNumber: index + 1,
                        coordinate: _formatBoardCoordinate(
                          widget.moves[index],
                          widget.boardSize,
                        ),
                        marked: widget.markedMoveNumbers.contains(index + 1),
                        palette: widget.palette,
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
    required this.marked,
    required this.palette,
  });

  final int moveNumber;
  final String coordinate;
  final bool marked;
  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final background = marked
        ? palette.primary.withValues(alpha: 0.16)
        : palette.segmentTrack.withValues(alpha: 0.82);
    final borderColor = marked
        ? palette.primary.withValues(alpha: 0.72)
        : palette.primary.withValues(alpha: 0.16);
    final textColor = marked
        ? Color.lerp(palette.primary, CupertinoColors.black, 0.16)!
        : palette.segmentText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor, width: marked ? 1.1 : 0.7),
      ),
      child: Text(
        '$moveNumber $coordinate',
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 12,
          height: 1,
          color: textColor,
          fontWeight: marked ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _OperationContextMenu extends StatelessWidget {
  const _OperationContextMenu({
    required this.aiStyleLabel,
    required this.canChangeAiStyle,
    required this.captureWarningEnabled,
    required this.moveLogVisible,
    required this.currentMoveMarked,
    required this.canUndo,
    required this.canHint,
    required this.canMarkMove,
    required this.canPass,
    required this.canToggleCaptureWarning,
    required this.onAiStyle,
    required this.onToggleCaptureWarning,
    required this.onToggleMoveLog,
    required this.onToggleMarkMove,
    required this.onUndo,
    required this.onHint,
    required this.onPass,
  });

  final String aiStyleLabel;
  final bool canChangeAiStyle;
  final bool captureWarningEnabled;
  final bool moveLogVisible;
  final bool currentMoveMarked;
  final bool canUndo;
  final bool canHint;
  final bool canMarkMove;
  final bool canPass;
  final bool canToggleCaptureWarning;
  final VoidCallback onAiStyle;
  final VoidCallback onToggleCaptureWarning;
  final VoidCallback onToggleMoveLog;
  final VoidCallback onToggleMarkMove;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onPass;

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
              text: 'AI 风格：$aiStyleLabel',
              enabled: canChangeAiStyle,
              onPressed: onAiStyle,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: captureWarningEnabled ? '吃子预警：开' : '吃子预警：关',
              enabled: canToggleCaptureWarning,
              onPressed: onToggleCaptureWarning,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: moveLogVisible ? '隐藏棋谱' : '显示棋谱',
              enabled: true,
              onPressed: onToggleMoveLog,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: currentMoveMarked ? '取消打标此手' : '打标此手',
              enabled: canMarkMove,
              onPressed: onToggleMarkMove,
            ),
            _OperationMenuDivider(),
            _OperationMenuItem(
              text: '后退一手',
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
    required this.enabled,
    required this.onPressed,
  });

  final String text;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: enabled ? onPressed : null,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: Align(
          alignment: Alignment.center,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: enabled
                  ? CupertinoColors.label.resolveFrom(context)
                  : CupertinoColors.inactiveGray.resolveFrom(context),
            ),
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
                    palette: context.appPalette,
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
  });

  final List<GameRecord> history;

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
    final date = _formatDate(record.playedAt);
    final boardLabel = '${record.boardSize} 路';
    final diffLabel = record.difficultyLevel.displayName;
    final modeLabel = record.gameMode.historyLabel;
    final outcomeLabel = record.outcome.displayName;
    final outcomeColor =
        _outcomeColors[record.outcome] ?? const Color(0xFF8C7966);

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
  const _HistoryDetailSheet({required this.record});

  final GameRecord record;

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
                  _OutcomeBadge(outcome: record.outcome),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.gameMode == GameMode.territory
                              ? '${record.boardSize} 路 · 围空 · ${record.difficultyLevel.displayName}'
                              : '${record.boardSize} 路 · 吃${record.captureTarget}子 · ${record.difficultyLevel.displayName}',
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
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '关闭',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8C7966),
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
            if (record.moves.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _PrimaryActionButton(
                  title: '浏览棋局',
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
      currentPlayer: StoneColor.black,
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

  String _moveCoordinate(int moveNo) {
    if (moveNo <= 0 || moveNo > widget.record.moves.length) return '-';
    return _formatBoardCoordinate(
      widget.record.moves[moveNo - 1],
      widget.record.boardSize,
    );
  }

  @override
  Widget build(BuildContext context) {
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
        middle: Text('棋局浏览'),
        previousPageTitle: '历史对局',
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
                        : '第 $_index 手 / 共 $_totalMoves 手 · 坐标 ${_moveCoordinate(_index)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8C7966),
                    ),
                  ),
                  if (_index > 0 && _markedMoves.contains(_index))
                    const Text(
                      '⭐ 已打标手',
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
                      child: Text(_onlyMarked ? '只看打标：开' : '只看打标：关'),
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
                            '第$move手 ${_moveCoordinate(move)}',
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
    final isClassic = identical(palette, AppThemePalette.classic);
    final (title, icon, accentColor) = switch (state) {
      _ResultDialogState.victory => (
          '胜利',
          CupertinoIcons.star_fill,
          isClassic ? const Color(0xFF34C759) : const Color(0xFFE4A64F),
        ),
      _ResultDialogState.draw => (
          '和棋',
          CupertinoIcons.equal_circle_fill,
          isClassic ? const Color(0xFF8E8E93) : const Color(0xFFC6A77F),
        ),
      _ResultDialogState.notWin => (
          '没赢',
          CupertinoIcons.flag_fill,
          isClassic ? const Color(0xFFFF3B30) : const Color(0xFFC57A5E),
        ),
    };
    final titleColor =
        isClassic ? const Color(0xFF111827) : const Color(0xFF2E2620);
    final cardGradient = isClassic
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF9FAFB)],
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
                  text: '再来一局',
                  primary: true,
                  color: palette.primary,
                  textColor: CupertinoColors.white,
                  onPressed: onPlayAgain,
                ),
                const SizedBox(height: 14),
                _ResultActionButton(
                  text: '复盘',
                  primary: false,
                  color: secondaryButtonColor,
                  textColor: secondaryTextColor,
                  onPressed: onReview,
                ),
                const SizedBox(height: 14),
                _ResultActionButton(
                  text: '离开',
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
