import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:three_js/three_js.dart' as three;

enum GoThreeStoneColor { black, white }

const kGoThreeDemoStones = <GoThreeBoardStone>[
  GoThreeBoardStone(row: 5, col: 8, color: GoThreeStoneColor.black),
  GoThreeBoardStone(row: 6, col: 10, color: GoThreeStoneColor.white),
  GoThreeBoardStone(row: 7, col: 12, color: GoThreeStoneColor.black),
  GoThreeBoardStone(row: 10, col: 13, color: GoThreeStoneColor.white),
  GoThreeBoardStone(row: 11, col: 10, color: GoThreeStoneColor.black),
  GoThreeBoardStone(row: 13, col: 12, color: GoThreeStoneColor.white),
  GoThreeBoardStone(row: 14, col: 9, color: GoThreeStoneColor.black),
  GoThreeBoardStone(row: 15, col: 14, color: GoThreeStoneColor.white),
];

class GoThreeBoardStone {
  const GoThreeBoardStone({
    required this.row,
    required this.col,
    required this.color,
  });

  final int row;
  final int col;
  final GoThreeStoneColor color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoThreeBoardStone &&
          row == other.row &&
          col == other.col &&
          color == other.color;

  @override
  int get hashCode => Object.hash(row, col, color);
}

class GoThreeBoardBackground extends StatefulWidget {
  const GoThreeBoardBackground({
    super.key,
    this.boardSize = 19,
    this.stones = const [],
    this.animate = true,
    this.particles = true,
    this.cinematicFrame = true,
    this.sceneScale = 1.0,
    this.cameraLift = 0.0,
    this.cameraDepth,
    this.targetZOffset = 0.0,
    this.leafShadowOpacity = 0.16,
    this.stoneExtraOverlayEnabled = true,
    this.boardTopBrightness = 1.0,
    this.showDebugGuides = false,
    this.keyLightPosition = const Offset3(5.8, 5.6, -3.8),
    this.fillLightPosition = const Offset3(-4.8, 2.6, 3.2),
    this.keyLightIntensity = 0.92,
    this.fillLightIntensity = 0.14,
    this.ambientLightIntensity = 0.19,
    this.sheenLightIntensity = 0.20,
    this.keyLightColor = 0xfff0d2,
    this.fillLightColor = 0xf4e8d8,
    this.ambientLightColor = 0xffeddc,
    this.sheenLightColor = 0xfffaed,
  });

  final int boardSize;
  final List<GoThreeBoardStone> stones;
  final bool animate;
  final bool particles;
  final bool cinematicFrame;
  final double sceneScale;
  final double cameraLift;
  final double? cameraDepth;
  final double targetZOffset;
  final double leafShadowOpacity;
  final bool stoneExtraOverlayEnabled;
  final double boardTopBrightness;
  final bool showDebugGuides;
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

  @override
  State<GoThreeBoardBackground> createState() => _GoThreeBoardBackgroundState();
}

class _GoThreeBoardBackgroundState extends State<GoThreeBoardBackground> {
  static const String _boardTopAlbedoAsset =
      'assets/textures/board_top_albedo_v2_1024.png';
  static const bool _enableAdditiveBoardHighlights = false;
  static const bool _enableLeafShadowCaustics = false;
  static const double _boardWidth = 8.0;
  static const double _boardTop = 0.0;
  static const double _boardThickness = 1.02;
  static const double _cornerRadius = 0.34;
  static const double _gridSpan = 7.24;

  late final three.ThreeJS _threeJs;
  final three.Group _root = three.Group();
  final three.Group _stoneGroup = three.Group();
  final three.Group _particleGroup = three.Group();
  final three.Group _leafShadowGroup = three.Group();
  final three.Group _debugGuideGroup = three.Group();
  three.AmbientLight? _ambientLight;
  three.DirectionalLight? _keyLight;
  three.DirectionalLight? _fillLight;
  three.SpotLight? _sheenLight;
  three.MeshStandardMaterial? _boardTopMaterial;
  three.MeshBasicMaterial? _reflectionMaterial;
  three.MeshBasicMaterial? _shaftMaterial;
  three.MeshBasicMaterial? _frontGlowMaterial;
  double _elapsed = 0;
  bool _sceneInitialized = false;

  /// Set to true when the OpenGL/flutter_angle plugin is not available on this
  /// platform (e.g. headless test environments). The widget then renders as an
  /// invisible SizedBox.expand so that the rest of the UI is unaffected.
  bool _pluginUnavailable = false;

  /// Saved FlutterError.onError handler, restored once the plugin check
  /// completes (either on first successful frame or on plugin error).
  FlutterExceptionHandler? _prevErrorHandler;

  @override
  void initState() {
    super.initState();
    if (_isFlutterWidgetTest) {
      _pluginUnavailable = true;
      return;
    }

    // Install a temporary error handler to catch MissingPluginException that
    // flutter_angle throws in test environments or other platforms where the
    // native plugin is not registered. The handler restores itself after the
    // first error or after the scene is successfully initialized.
    _prevErrorHandler = FlutterError.onError;
    FlutterError.onError = _pluginErrorGuard;

    _threeJs = three.ThreeJS(
      settings: three.Settings(
        alpha: true,
        antialias: true,
        clearAlpha: 0,
        clearColor: 0x000000,
        screenResolution: 1.0,
        toneMappingExposure: 0.50,
      ),
      onSetupComplete: () {
        // Scene initialized successfully – restore the original handler.
        _restorePrevErrorHandler();
        if (mounted) setState(() {});
      },
      setup: _setup,
    );
  }

  void _pluginErrorGuard(FlutterErrorDetails details) {
    if (!_sceneInitialized && details.exception is MissingPluginException) {
      // flutter_angle is not available on this platform; fall back gracefully.
      _restorePrevErrorHandler();
      if (mounted) setState(() => _pluginUnavailable = true);
      return;
    }
    _prevErrorHandler?.call(details);
  }

  void _restorePrevErrorHandler() {
    if (FlutterError.onError == _pluginErrorGuard) {
      FlutterError.onError = _prevErrorHandler;
    }
  }

  @override
  void didUpdateWidget(covariant GoThreeBoardBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pluginUnavailable) return;
    if (oldWidget.boardSize != widget.boardSize ||
        !_listEquals(oldWidget.stones, widget.stones)) {
      _rebuildStones();
    }
    if (oldWidget.sceneScale != widget.sceneScale) {
      _setCamera(_elapsed);
    }
    if (oldWidget.cameraLift != widget.cameraLift ||
        oldWidget.cameraDepth != widget.cameraDepth ||
        oldWidget.targetZOffset != widget.targetZOffset) {
      _setCamera(_elapsed);
    }
    if (oldWidget.leafShadowOpacity != widget.leafShadowOpacity) {
      _buildLeafShadowCaustics();
    }
    if (oldWidget.showDebugGuides != widget.showDebugGuides) {
      _debugGuideGroup.visible = widget.showDebugGuides;
    }
    if (oldWidget.stoneExtraOverlayEnabled != widget.stoneExtraOverlayEnabled) {
      _rebuildStones();
    }
    if (oldWidget.boardTopBrightness != widget.boardTopBrightness) {
      _updateBoardBrightness();
    }
    if (oldWidget.keyLightPosition != widget.keyLightPosition ||
        oldWidget.fillLightPosition != widget.fillLightPosition ||
        oldWidget.keyLightIntensity != widget.keyLightIntensity ||
        oldWidget.fillLightIntensity != widget.fillLightIntensity ||
        oldWidget.ambientLightIntensity != widget.ambientLightIntensity ||
        oldWidget.sheenLightIntensity != widget.sheenLightIntensity ||
        oldWidget.keyLightColor != widget.keyLightColor ||
        oldWidget.fillLightColor != widget.fillLightColor ||
        oldWidget.ambientLightColor != widget.ambientLightColor ||
        oldWidget.sheenLightColor != widget.sheenLightColor) {
      _updateLightsFromWidget();
    }
    _particleGroup.visible = widget.particles;
  }

  @override
  void dispose() {
    _restorePrevErrorHandler();
    if (_sceneInitialized) {
      _threeJs.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pluginUnavailable) return const SizedBox.expand();
    return SizedBox.expand(child: _threeJs.build());
  }

  bool get _isFlutterWidgetTest {
    var isTestBinding = false;
    assert(() {
      isTestBinding = WidgetsBinding.instance.runtimeType
          .toString()
          .contains('TestWidgetsFlutterBinding');
      return true;
    }());
    return isTestBinding;
  }

  Future<void> _setup() async {
    _threeJs.scene = three.Scene();
    _sceneInitialized = true;
    _root
      ..position.setValues(0, widget.cinematicFrame ? -1.50 : 0, 0)
      ..rotation.y = widget.cinematicFrame ? 0.03 : 0;
    _threeJs.camera = three.PerspectiveCamera(
      widget.cinematicFrame ? 24 : 28,
      _threeJs.width / _threeJs.height,
      0.1,
      100,
    );
    _setCamera(0);

    _threeJs.scene.add(_root);
    _buildLights();
    await _buildBoard();
    _buildSideWoodDetail();
    _buildGrid();
    _buildLeafShadowCaustics();
    _buildDebugGuides();
    _buildParticles();
    _rebuildStones();

    _threeJs.addAnimationEvent((dt) {
      if (!mounted) return;
      _elapsed += dt;
      if (widget.animate) {
        _setCamera(_elapsed);
      }
      if (widget.particles) {
        _particleGroup.rotation.y += dt * 0.045;
        _particleGroup.position.y = 0.12 + math.sin(_elapsed * 0.7) * 0.025;
      }
    });
  }

  void _buildDebugGuides() {
    _debugGuideGroup.clear();
    _debugGuideGroup.visible = widget.showDebugGuides;

    final xAxis = three.Mesh(
      three.BoxGeometry(1.2, 0.015, 0.015),
      three.MeshBasicMaterial({three.MaterialProperty.color: 0xff4a4a}),
    )..position.setValues(0.6, _boardTop + 0.05, 0);
    final yAxis = three.Mesh(
      three.BoxGeometry(0.015, 1.2, 0.015),
      three.MeshBasicMaterial({three.MaterialProperty.color: 0x4aff4a}),
    )..position.setValues(0, _boardTop + 0.65, 0);
    final zAxis = three.Mesh(
      three.BoxGeometry(0.015, 0.015, 1.2),
      three.MeshBasicMaterial({three.MaterialProperty.color: 0x4a6fff}),
    )..position.setValues(0, _boardTop + 0.05, 0.6);
    _debugGuideGroup
      ..add(xAxis)
      ..add(yAxis)
      ..add(zAxis);

    _root.add(_debugGuideGroup);
    _updateDebugGuides();
  }

  void _setCamera(double t) {
    final drift = widget.animate ? math.sin(t * 0.32) : 0.0;
    final lift = widget.animate ? math.sin(t * 0.21 + 0.8) : 0.0;
    final viewScale = widget.sceneScale.clamp(0.10, 1.80);
    if (widget.cinematicFrame) {
      final target = three.Vector3(
        0,
        _root.position.y + _boardTop + 0.02,
        widget.targetZOffset,
      );
      final basePosition = three.Vector3(
        -3.45 + drift * 0.10,
        _root.position.y + 2.20 + widget.cameraLift + lift * 0.045,
        (widget.cameraDepth ?? 6.55) + drift * 0.06,
      );
      _threeJs.camera.position.setValues(
        target.x + (basePosition.x - target.x) / viewScale,
        target.y + (basePosition.y - target.y) / viewScale,
        target.z + (basePosition.z - target.z) / viewScale,
      );
      _threeJs.camera.lookAt(target);
    } else {
      final target =
          three.Vector3(0, _root.position.y + _boardTop, widget.targetZOffset);
      final basePosition = three.Vector3(
        -5.35 + drift * 0.16,
        _root.position.y + 3.85 + widget.cameraLift + lift * 0.07,
        (widget.cameraDepth ?? 7.15) + drift * 0.10,
      );
      _threeJs.camera.position.setValues(
        target.x + (basePosition.x - target.x) / viewScale,
        target.y + (basePosition.y - target.y) / viewScale,
        target.z + (basePosition.z - target.z) / viewScale,
      );
      _threeJs.camera.lookAt(target);
    }
  }

  void _buildLights() {
    _ambientLight = three.AmbientLight(
        widget.ambientLightColor, widget.ambientLightIntensity);
    _threeJs.scene.add(_ambientLight!);

    final key =
        three.DirectionalLight(widget.keyLightColor, widget.keyLightIntensity);
    key.position.setValues(
      widget.keyLightPosition.x,
      widget.keyLightPosition.y,
      widget.keyLightPosition.z,
    );
    key.castShadow = true;
    key.target?.position.setValues(0.3, -0.08, 0.05);
    key.shadow?.mapSize.width = 2048;
    key.shadow?.mapSize.height = 2048;
    key.shadow?.bias = -0.0008;
    _threeJs.scene.add(key);
    if (key.target != null) {
      _threeJs.scene.add(key.target);
    }
    _keyLight = key;

    final fill = three.DirectionalLight(
        widget.fillLightColor, widget.fillLightIntensity);
    fill.position.setValues(
      widget.fillLightPosition.x,
      widget.fillLightPosition.y,
      widget.fillLightPosition.z,
    );
    _threeJs.scene.add(fill);
    _fillLight = fill;

    final sheen = three.SpotLight(
      widget.sheenLightColor,
      widget.sheenLightIntensity,
      20,
      math.pi / 5,
      0.82,
      1.18,
    );
    sheen.position.setValues(
      widget.keyLightPosition.x + 0.4,
      widget.keyLightPosition.y + 0.3,
      widget.keyLightPosition.z - 0.1,
    );
    sheen.castShadow = true;
    sheen.target?.position.setValues(0.4, -0.05, 0.08);
    sheen.shadow?.mapSize.width = 2048;
    sheen.shadow?.mapSize.height = 2048;
    sheen.shadow?.bias = -0.0009;
    _threeJs.scene.add(sheen);
    if (sheen.target != null) {
      _threeJs.scene.add(sheen.target);
    }
    _sheenLight = sheen;
  }

  Future<void> _buildBoard() async {
    final sideMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xa06a35,
      three.MaterialProperty.roughness: 0.78,
      three.MaterialProperty.metalness: 0.0,
    });
    final boardTopAlbedo =
        await three.TextureLoader(flipY: false).fromAsset(_boardTopAlbedoAsset);
    if (boardTopAlbedo != null) {
      boardTopAlbedo
        ..colorSpace = three.SRGBColorSpace
        ..wrapS = three.ClampToEdgeWrapping
        ..wrapT = three.ClampToEdgeWrapping
        ..needsUpdate = true;
    }
    final topMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xdab074,
      if (boardTopAlbedo != null) three.MaterialProperty.map: boardTopAlbedo,
      three.MaterialProperty.roughness: 0.36,
      three.MaterialProperty.metalness: 0.03,
      three.MaterialProperty.emissive: 0x000000,
    });
    _boardTopMaterial = topMaterial;

    const straightWidth = _boardWidth - _cornerRadius * 2;
    _addBoardBox(
      width: straightWidth,
      height: _boardThickness,
      depth: _boardWidth,
      y: -_boardThickness / 2,
      material: sideMaterial,
    );
    _addBoardBox(
      width: _boardWidth,
      height: _boardThickness,
      depth: straightWidth,
      y: -_boardThickness / 2,
      material: sideMaterial,
    );

    for (final xSign in [-1.0, 1.0]) {
      for (final zSign in [-1.0, 1.0]) {
        final corner = three.Mesh(
          three.CylinderGeometry(
            _cornerRadius,
            _cornerRadius,
            _boardThickness,
            32,
          ),
          sideMaterial,
        )
          ..position.setValues(
            xSign * (_boardWidth / 2 - _cornerRadius),
            -_boardThickness / 2,
            zSign * (_boardWidth / 2 - _cornerRadius),
          )
          ..receiveShadow = true;
        _root.add(corner);
      }
    }

    final topSkin = three.Mesh(_buildRoundedBoardTopGeometry(), topMaterial)
      ..position.setValues(-_boardWidth / 2, _boardTop + 0.034, _boardWidth / 2)
      ..rotation.x = -math.pi / 2
      ..scale.setValues(_boardWidth, _boardWidth, 1)
      ..receiveShadow = true;
    _root.add(topSkin);

    if (!_enableAdditiveBoardHighlights) {
      _updateBoardBrightness();
      return;
    }
    _frontGlowMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0xffc179,
      three.MaterialProperty.opacity: 0.14,
      three.MaterialProperty.transparent: true,
    });
    final frontGlow = three.Mesh(
      three.BoxGeometry(_boardWidth - _cornerRadius, 0.018, 0.020),
      _frontGlowMaterial,
    )..position.setValues(0, _boardTop + 0.030, _boardWidth / 2 + 0.014);
    _root.add(frontGlow);

    final reflectionMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0xfff3dd,
      three.MaterialProperty.opacity: 0.024,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.blending: three.AdditiveBlending,
      three.MaterialProperty.depthWrite: false,
    });
    _reflectionMaterial = reflectionMaterial;
    for (int i = 0; i < 3; i++) {
      final t = i / 2;
      final glow = three.Mesh(
        three.CircleGeometry(radius: 0.20 + _noise(820 + i * 17) * 0.22),
        reflectionMaterial,
      )
        ..position.setValues(
          1.85 + t * 1.70 + (_noise(830 + i * 13) - 0.5) * 0.14,
          _boardTop + 0.046 + i * 0.0004,
          -2.45 + t * 0.68 + (_noise(840 + i * 19) - 0.5) * 0.16,
        )
        ..rotation.x = -math.pi / 2
        ..rotation.z = -0.46 + (_noise(850 + i * 23) - 0.5) * 0.22
        ..scale.x = 1.35 + _noise(860 + i * 29) * 0.80
        ..scale.y = 0.48 + _noise(870 + i * 31) * 0.18;
      _root.add(glow);
    }

    final shaftMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0xfff6e5,
      three.MaterialProperty.opacity: 0.012,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.blending: three.AdditiveBlending,
      three.MaterialProperty.depthWrite: false,
    });
    _shaftMaterial = shaftMaterial;
    for (int i = 0; i < 2; i++) {
      final shaft = three.Mesh(
        three.PlaneGeometry(0.20 + i * 0.04, 1.85 - i * 0.24),
        shaftMaterial,
      )
        ..position.setValues(2.95 + i * 0.32, 1.02 + i * 0.05, -2.85 + i * 0.18)
        ..rotation.y = -0.72
        ..rotation.z = 0.18 + i * 0.04;
      _root.add(shaft);
    }

    _updateBoardBrightness();
  }

  void _updateBoardBrightness() {
    final b = widget.boardTopBrightness.clamp(0.4, 2.4);
    final top = _boardTopMaterial;
    if (top != null) {
      top.color.setFromHex32(_lerpColorHex(
        0xffffff,
        0xfff2cb,
        (b - 1.0).clamp(0.0, 1.0),
      ));
      top.emissive?.setFromHex32(0x000000);
      top.needsUpdate = true;
    }
    final reflection = _reflectionMaterial;
    if (reflection != null) {
      reflection.opacity = 0.024 * b.clamp(0.4, 1.4);
      reflection.needsUpdate = true;
    }
    final shaft = _shaftMaterial;
    if (shaft != null) {
      shaft.opacity = 0.012 * b.clamp(0.5, 1.4);
      shaft.needsUpdate = true;
    }
    final frontGlow = _frontGlowMaterial;
    if (frontGlow != null) {
      frontGlow.opacity = 0.14 * b.clamp(0.4, 1.4);
      frontGlow.needsUpdate = true;
    }
  }

  void _updateLightsFromWidget() {
    final ambient = _ambientLight;
    if (ambient != null) {
      ambient.color?.setFromHex32(widget.ambientLightColor);
      ambient.intensity = widget.ambientLightIntensity;
    }
    final key = _keyLight;
    if (key != null) {
      key.color?.setFromHex32(widget.keyLightColor);
      key.intensity = widget.keyLightIntensity;
      key.position.setValues(
        widget.keyLightPosition.x,
        widget.keyLightPosition.y,
        widget.keyLightPosition.z,
      );
    }
    final fill = _fillLight;
    if (fill != null) {
      fill.color?.setFromHex32(widget.fillLightColor);
      fill.intensity = widget.fillLightIntensity;
      fill.position.setValues(
        widget.fillLightPosition.x,
        widget.fillLightPosition.y,
        widget.fillLightPosition.z,
      );
    }
    final sheen = _sheenLight;
    if (sheen != null) {
      sheen.color?.setFromHex32(widget.sheenLightColor);
      sheen.intensity = widget.sheenLightIntensity;
      sheen.position.setValues(
        widget.keyLightPosition.x + 0.4,
        widget.keyLightPosition.y + 0.3,
        widget.keyLightPosition.z - 0.1,
      );
    }
    _updateDebugGuides();
  }

  void _updateDebugGuides() {
    if (_debugGuideGroup.children.length > 3) {
      final keep = _debugGuideGroup.children.take(3).toList();
      _debugGuideGroup
        ..clear()
        ..add(keep[0])
        ..add(keep[1])
        ..add(keep[2]);
    }

    final lightPosition = widget.keyLightPosition;
    const target = Offset3(0.3, -0.08, 0.05);
    final src = three.Mesh(
      three.SphereGeometry(0.08, 18, 10),
      three.MeshBasicMaterial({three.MaterialProperty.color: 0xffe061}),
    )..position.setValues(lightPosition.x, lightPosition.y, lightPosition.z);
    final dst = three.Mesh(
      three.SphereGeometry(0.05, 16, 10),
      three.MeshBasicMaterial({three.MaterialProperty.color: 0x6ee8ff}),
    )..position.setValues(target.x, target.y, target.z);
    _debugGuideGroup
      ..add(src)
      ..add(dst);

    const dots = 14;
    for (int i = 1; i < dots; i++) {
      final t = i / dots;
      final dot = three.Mesh(
        three.SphereGeometry(0.022, 10, 8),
        three.MeshBasicMaterial({three.MaterialProperty.color: 0xffd27a}),
      )..position.setValues(
          lightPosition.x + (target.x - lightPosition.x) * t,
          lightPosition.y + (target.y - lightPosition.y) * t,
          lightPosition.z + (target.z - lightPosition.z) * t,
        );
      _debugGuideGroup.add(dot);
    }
  }

  void _addBoardBox({
    required double width,
    required double height,
    required double depth,
    required double y,
    required three.Material material,
  }) {
    final mesh = three.Mesh(
      three.BoxGeometry(width, height, depth, 1, 1, 1),
      material,
    )
      ..position.setValues(0, y, 0)
      ..receiveShadow = true;
    _root.add(mesh);
  }

  void _buildSideWoodDetail() {
    final material = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x704019,
      three.MaterialProperty.opacity: 0.24,
      three.MaterialProperty.transparent: true,
    });
    const frontZ = _boardWidth / 2 + 0.016;
    for (int i = 0; i < 42; i++) {
      final y = -_boardThickness * (0.14 + 0.72 * i / 41);
      final length = _boardWidth * (0.42 + 0.46 * _noise(i * 31));
      final x = (_noise(i * 13) - 0.5) * (_boardWidth - length * 0.68);
      final line = three.Mesh(
        three.BoxGeometry(length, 0.010, 0.010),
        material,
      )
        ..position.setValues(x, y, frontZ)
        ..rotation.z = (_noise(i * 19) - 0.5) * 0.018;
      _root.add(line);
    }

    final edgeMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0xffd08b,
      three.MaterialProperty.opacity: 0.26,
      three.MaterialProperty.transparent: true,
    });
    final frontEdge = three.Mesh(
      three.BoxGeometry(_boardWidth + 0.04, 0.018, 0.014),
      edgeMaterial,
    )..position.setValues(0, _boardTop + 0.020, frontZ + 0.006);
    _root.add(frontEdge);
  }

  void _buildGrid() {
    final n = widget.boardSize;
    if (n < 2) return;
    final step = _gridSpan / (n - 1);
    const start = -_gridSpan / 2;
    final lineMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x6b5237,
      three.MaterialProperty.opacity: 0.26,
      three.MaterialProperty.transparent: true,
    });
    for (int i = 0; i < n; i++) {
      final p = start + i * step;
      final horizontal = three.Mesh(
        three.BoxGeometry(_gridSpan, 0.010, 0.010),
        lineMaterial,
      )..position.setValues(0, _boardTop + 0.034, p);
      final vertical = three.Mesh(
        three.BoxGeometry(0.010, 0.010, _gridSpan),
        lineMaterial,
      )..position.setValues(p, _boardTop + 0.035, 0);
      _root
        ..add(horizontal)
        ..add(vertical);
    }
  }

  void _buildParticles() {
    final positions = <double>[];
    for (int i = 0; i < 120; i++) {
      final x = (_noise(i * 11) - 0.5) * 6.4;
      final y = 0.38 + _noise(i * 19) * 1.55;
      final z = (_noise(i * 23) - 0.5) * 5.8;
      positions.addAll([x, y, z]);
    }
    final geometry = three.BufferGeometry()
      ..setAttribute(
        three.Attribute.position,
        three.Float32BufferAttribute.fromList(positions, 3, false),
      );
    final material = three.PointsMaterial({
      three.MaterialProperty.color: 0xffd8a3,
      three.MaterialProperty.size: 0.028,
      three.MaterialProperty.opacity: 0.06,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.blending: three.AdditiveBlending,
    });
    final points = three.Points(geometry, material);
    _particleGroup
      ..visible = widget.particles
      ..add(points);
    _root.add(_particleGroup);
  }

  void _buildLeafShadowCaustics() {
    _leafShadowGroup.clear();
    if (!_enableLeafShadowCaustics) return;

    final opacity = widget.leafShadowOpacity.clamp(0.02, 0.18);
    final coreMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x6b563b,
      three.MaterialProperty.opacity: opacity * 0.38,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.depthWrite: false,
    });
    final penumbraMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x8a6a47,
      three.MaterialProperty.opacity: opacity * 0.16,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.depthWrite: false,
    });

    const centerX = 2.15;
    const centerZ = -1.95;
    for (int i = 0; i < 10; i++) {
      final ring = 0.70 + _noise(210 + i * 31) * 1.70;
      final angle = -1.05 + _noise(310 + i * 19) * 1.05;
      final baseX = centerX + math.cos(angle) * ring;
      final baseZ = centerZ + math.sin(angle) * ring * 0.78;
      final radius = 0.12 + _noise(410 + i * 7) * 0.14;

      final core = three.Mesh(
        three.CircleGeometry(radius: radius, segments: 26),
        coreMaterial,
      )
        ..position.setValues(baseX, _boardTop + 0.0385, baseZ)
        ..rotation.x = -math.pi / 2
        ..rotation.z = (_noise(710 + i * 29) - 0.5) * 1.05
        ..scale.x = 1.45 + _noise(915 + i * 7) * 0.45;
      final penumbra = three.Mesh(
        three.CircleGeometry(radius: radius * 2.2, segments: 30),
        penumbraMaterial,
      )
        ..position.setValues(baseX, _boardTop + 0.0380, baseZ)
        ..rotation.x = -math.pi / 2
        ..rotation.z = core.rotation.z
        ..scale.x = core.scale.x * 1.18;
      _leafShadowGroup
        ..add(penumbra)
        ..add(core);
    }

    _root.add(_leafShadowGroup);
  }

  void _rebuildStones() {
    _stoneGroup.clear();
    final n = widget.boardSize;
    if (n < 2) return;

    final step = _gridSpan / (n - 1);
    const start = -_gridSpan / 2;
    final blackMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0x17110f,
      three.MaterialProperty.roughness: 0.20,
      three.MaterialProperty.metalness: 0.06,
    });
    final whiteMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xf1e8db,
      three.MaterialProperty.roughness: 0.46,
      three.MaterialProperty.metalness: 0.02,
    });
    final shadowMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x3f2815,
      three.MaterialProperty.opacity: 0.22,
      three.MaterialProperty.transparent: true,
    });
    final softShadowMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x7a5a37,
      three.MaterialProperty.opacity: 0.08,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.depthWrite: false,
    });
    final radius = step * 0.46;

    for (final stone in widget.stones) {
      final row = stone.row.clamp(0, n - 1);
      final col = stone.col.clamp(0, n - 1);
      final material = stone.color == GoThreeStoneColor.black
          ? blackMaterial
          : whiteMaterial;
      final x = start + col * step;
      final z = start + row * step;
      if (widget.stoneExtraOverlayEnabled) {
        final shadow = three.Mesh(
          three.CylinderGeometry(radius * 1.08, radius * 1.08, 0.006, 40),
          shadowMaterial,
        )
          ..position.setValues(
            x - radius * 0.10,
            _boardTop + 0.049,
            z + radius * 0.07,
          )
          ..scale.x = 1.14
          ..scale.z = 0.88;
        _stoneGroup.add(shadow);
        final softShadow = three.Mesh(
          three.CylinderGeometry(radius * 1.55, radius * 1.55, 0.004, 40),
          softShadowMaterial,
        )
          ..position.setValues(
            x - radius * 0.15,
            _boardTop + 0.046,
            z + radius * 0.12,
          )
          ..scale.x = 1.18
          ..scale.z = 0.84;
        _stoneGroup.add(softShadow);
      }

      final mesh = three.Mesh(
        three.SphereGeometry(radius, 48, 18),
        material,
      )
        ..position.setValues(
          x,
          _boardTop + radius * 0.34,
          z,
        )
        ..scale.y = 0.34
        ..castShadow = true
        ..receiveShadow = true;
      _stoneGroup.add(mesh);
    }

    if (_stoneGroup.parent == null) {
      _root.add(_stoneGroup);
    }
  }

  static double _noise(int seed) {
    final v = math.sin(seed * 127.1 + seed * 311.7) * 43758.5453;
    return v - v.floor();
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  three.ShapeGeometry _buildRoundedBoardTopGeometry() {
    const r = _cornerRadius / _boardWidth;
    final shape = three.Shape()
      ..moveTo(r, 0)
      ..lineTo(1 - r, 0)
      ..quadraticCurveTo(1, 0, 1, r)
      ..lineTo(1, 1 - r)
      ..quadraticCurveTo(1, 1, 1 - r, 1)
      ..lineTo(r, 1)
      ..quadraticCurveTo(0, 1, 0, 1 - r)
      ..lineTo(0, r)
      ..quadraticCurveTo(0, 0, r, 0);
    return three.ShapeGeometry([shape], curveSegments: 12);
  }
}

class Offset3 {
  const Offset3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Offset3 && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

int _lerpColorHex(int a, int b, double t) {
  final clamped = t.clamp(0.0, 1.0);
  final ar = (a >> 16) & 0xFF;
  final ag = (a >> 8) & 0xFF;
  final ab = a & 0xFF;
  final br = (b >> 16) & 0xFF;
  final bg = (b >> 8) & 0xFF;
  final bb = b & 0xFF;
  final r = (ar + (br - ar) * clamped).round();
  final g = (ag + (bg - ag) * clamped).round();
  final c = (ab + (bb - ab) * clamped).round();
  return (r << 16) | (g << 8) | c;
}
