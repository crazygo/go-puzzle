import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
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
    this.animate = false,
    this.particles = false,
    this.cinematicFrame = true,
    this.cinematicFov = 26,
    this.sceneScale = 1.0,
    this.cameraLift = 0.0,
    this.cameraDepth,
    this.targetZOffset = 0.0,
    this.boardRotationY = 0.03,
    this.leafShadowOpacity = 0.16,
    this.stoneExtraOverlayEnabled = true,
    this.boardTopBrightness = 1.0,
    this.toneMappingExposure = 0.44,
    this.showDebugGuides = false,
    this.showCornerLabels = true,
    this.keyLightPosition = const Offset3(5.5, 5.5, 5.5),
    this.fillLightPosition = const Offset3(-4.8, 2.6, 3.2),
    this.keyLightIntensity = 1.18,
    this.fillLightIntensity = 0.07,
    this.ambientLightIntensity = 0.12,
    this.sheenLightIntensity = 0.20,
    this.keyLightColor = 0xffdfb8,
    this.fillLightColor = 0xf4e8d8,
    this.ambientLightColor = 0xffeddc,
    this.sheenLightColor = 0xfffaed,
    this.windowCenterU = 0.88,
    this.windowCenterV = 0.05,
    this.windowSpreadU = 1.80,
    this.windowSpreadV = 1.60,
    this.gridBaseOpacity = 0.62,
    this.gridFadeMult = 0.95,
    this.gridFadePower = 0.66,
    this.gridFadeMin = 0.00,
  });

  final int boardSize;
  final List<GoThreeBoardStone> stones;
  final bool animate;
  final bool particles;
  final bool cinematicFrame;
  final double cinematicFov;
  final double sceneScale;
  final double cameraLift;
  final double? cameraDepth;
  final double targetZOffset;
  final double boardRotationY;
  final double leafShadowOpacity;
  final bool stoneExtraOverlayEnabled;
  final double boardTopBrightness;
  final double toneMappingExposure;
  final bool showDebugGuides;
  final bool showCornerLabels;
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
  // Window irradiance Gaussian controls (rebuild textures + grid on change).
  final double windowCenterU;
  final double windowCenterV;
  final double windowSpreadU;
  final double windowSpreadV;
  // Grid dissolution controls (rebuild grid only on change).
  final double gridBaseOpacity;
  final double gridFadeMult;
  final double gridFadePower;
  final double gridFadeMin;

  @override
  State<GoThreeBoardBackground> createState() => _GoThreeBoardBackgroundState();
}

class _GoThreeBoardBackgroundState extends State<GoThreeBoardBackground> {
  static const String _boardTopAlbedoAsset =
      'assets/textures/board_top_albedo_v2_1024.png';
  static const bool _enableAdditiveBoardHighlights = false;
  static const bool _enableLeafShadowCaustics = false;
  static const double _surfaceSheenOpacity = 0.18;
  static const Offset3 _keyLightTarget = Offset3(0.20, -0.10, 0.12);
  static const Offset3 _sheenLightPosition = Offset3(6.8, 6.8, 6.2);
  static const Offset3 _sheenLightTarget = Offset3(0.15, -0.05, 0.08);
  static const double _cinematicViewZOffset = 1.32;
  static const double _boardWidth = 8.0;
  static const double _boardTop = 0.0;
  static const double _boardThickness = 0.51;
  static const double _cornerRadius = 0.34;
  static const double _gridSpan = 7.24;

  late final three.ThreeJS _threeJs;
  final three.Group _root = three.Group();
  final three.Group _stoneGroup = three.Group();
  final three.Group _particleGroup = three.Group();
  final three.Group _leafShadowGroup = three.Group();
  final three.Group _debugGuideGroup = three.Group();
  final three.Group _cornerLabelGroup = three.Group();
  three.AmbientLight? _ambientLight;
  three.DirectionalLight? _keyLight;
  three.DirectionalLight? _fillLight;
  three.RectAreaLight? _sheenLight;
  three.MeshStandardMaterial? _boardTopMaterial;
  final List<three.MeshBasicMaterial> _surfaceSheenMaterials = [];
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
        screenResolution: 2.0,
        toneMappingExposure: widget.toneMappingExposure,
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
    if (oldWidget.boardRotationY != widget.boardRotationY) {
      _root.rotation.y = widget.boardRotationY;
    }
    if (oldWidget.cinematicFov != widget.cinematicFov) {
      _threeJs.camera.fov = widget.cinematicFrame ? widget.cinematicFov : 28;
      _threeJs.camera.updateProjectionMatrix();
    }
    if (oldWidget.leafShadowOpacity != widget.leafShadowOpacity) {
      _buildLeafShadowCaustics();
    }
    if (oldWidget.showDebugGuides != widget.showDebugGuides) {
      _debugGuideGroup.visible = widget.showDebugGuides;
    }
    if (oldWidget.showCornerLabels != widget.showCornerLabels) {
      _cornerLabelGroup.visible = widget.showCornerLabels;
    }
    if (oldWidget.stoneExtraOverlayEnabled != widget.stoneExtraOverlayEnabled) {
      _rebuildStones();
    }
    if (oldWidget.boardTopBrightness != widget.boardTopBrightness) {
      _updateBoardBrightness();
    }
    if (oldWidget.toneMappingExposure != widget.toneMappingExposure) {
      _updateToneMappingExposure();
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
    if (oldWidget.windowCenterU != widget.windowCenterU ||
        oldWidget.windowCenterV != widget.windowCenterV ||
        oldWidget.windowSpreadU != widget.windowSpreadU ||
        oldWidget.windowSpreadV != widget.windowSpreadV ||
        oldWidget.gridBaseOpacity != widget.gridBaseOpacity ||
        oldWidget.gridFadeMult != widget.gridFadeMult ||
        oldWidget.gridFadePower != widget.gridFadePower ||
        oldWidget.gridFadeMin != widget.gridFadeMin) {
      unawaited(_rebuildBoardTextures());
    }
    _particleGroup.visible = widget.particles;
  }

  void _updateToneMappingExposure() {
    _threeJs.renderer?.toneMappingExposure = widget.toneMappingExposure;
  }

  Future<void> _rebuildBoardTextures() async {
    final mat = _boardTopMaterial;
    if (mat == null) return;
    mat
      ..lightMap = _buildBoardTopIrradianceMap()
      ..needsUpdate = true;
    final newMap = await _buildBoardTopAppearanceMap();
    if (newMap != null) {
      newMap
        ..colorSpace = three.SRGBColorSpace
        ..wrapS = three.ClampToEdgeWrapping
        ..wrapT = three.ClampToEdgeWrapping
        ..needsUpdate = true;
      mat
        ..map = newMap
        ..needsUpdate = true;
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackSize =
            MediaQuery.maybeOf(context)?.size ?? const Size(1, 1);
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : fallbackSize.width;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : fallbackSize.height;
        final viewSize = Size(
          width.isFinite && width > 0 ? width : fallbackSize.width,
          height.isFinite && height > 0 ? height : fallbackSize.height,
        );

        return ClipRect(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(size: viewSize),
            child: SizedBox.expand(child: _threeJs.build()),
          ),
        );
      },
    );
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
      ..rotation.y = widget.boardRotationY;
    _threeJs.camera = three.PerspectiveCamera(
      widget.cinematicFrame ? widget.cinematicFov : 28,
      _threeJs.width / _threeJs.height,
      0.1,
      100,
    );
    _setCamera(0);

    _threeJs.scene.add(_root);
    _buildLights();
    await _buildBoard();
    _buildSideWoodDetail();
    _buildCornerLabels();
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

    _root.add(_debugGuideGroup);
    _updateDebugGuides();
  }

  void _buildCornerLabels() {
    _cornerLabelGroup.clear();
    _cornerLabelGroup.visible = widget.showCornerLabels;

    const inset = 0.36;
    const half = _boardWidth / 2 - inset;
    const labelY = _boardTop + 0.074;
    const scale = 0.34;
    const stroke = 0.045;
    final material = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x2f2118,
      three.MaterialProperty.opacity: 0.78,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.depthWrite: false,
    });

    final labels = [
      ('A', -half, -half),
      ('B', half, -half),
      ('C', half, half),
      ('D', -half, half),
    ];
    for (final (letter, x, z) in labels) {
      _cornerLabelGroup.add(_buildCornerLabel(
        letter: letter,
        x: x,
        z: z,
        y: labelY,
        scale: scale,
        stroke: stroke,
        material: material,
      ));
    }

    _root.add(_cornerLabelGroup);
  }

  three.Group _buildCornerLabel({
    required String letter,
    required double x,
    required double z,
    required double y,
    required double scale,
    required double stroke,
    required three.Material material,
  }) {
    final group = three.Group()..position.setValues(x, y, z);
    void addStroke(double cx, double cz, double width, double depth) {
      group.add(three.Mesh(
        three.BoxGeometry(width * scale, 0.010, depth * scale),
        material,
      )..position.setValues(cx * scale, 0, cz * scale));
    }

    switch (letter) {
      case 'A':
        addStroke(-0.38, 0.0, stroke, 1.0);
        addStroke(0.38, 0.0, stroke, 1.0);
        addStroke(0.0, -0.48, 0.80, stroke);
        addStroke(0.0, 0.0, 0.70, stroke);
        break;
      case 'B':
        addStroke(-0.38, 0.0, stroke, 1.0);
        addStroke(0.02, -0.48, 0.78, stroke);
        addStroke(0.02, 0.0, 0.72, stroke);
        addStroke(0.02, 0.48, 0.78, stroke);
        addStroke(0.38, -0.24, stroke, 0.44);
        addStroke(0.38, 0.24, stroke, 0.44);
        break;
      case 'C':
        addStroke(0.0, -0.48, 0.82, stroke);
        addStroke(-0.38, 0.0, stroke, 1.0);
        addStroke(0.0, 0.48, 0.82, stroke);
        break;
      case 'D':
        addStroke(-0.38, 0.0, stroke, 1.0);
        addStroke(0.0, -0.48, 0.74, stroke);
        addStroke(0.0, 0.48, 0.74, stroke);
        addStroke(0.38, 0.0, stroke, 0.92);
        break;
    }
    return group;
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
      _setCameraPositionAlongView(
        target: target,
        offsetX: -3.45 + drift * 0.10,
        offsetY: 2.18 + widget.cameraLift + lift * 0.045,
        offsetZ: _cinematicViewZOffset + drift * 0.06,
        distance: widget.cameraDepth ?? 6.55,
        viewScale: viewScale,
      );
      _threeJs.camera.lookAt(target);
    } else {
      final target =
          three.Vector3(0, _root.position.y + _boardTop, widget.targetZOffset);
      _setCameraPositionAlongView(
        target: target,
        offsetX: -5.35 + drift * 0.16,
        offsetY: 3.85 + widget.cameraLift + lift * 0.07,
        offsetZ: 7.15 + drift * 0.10,
        distance: widget.cameraDepth ?? 9.66,
        viewScale: viewScale,
      );
      _threeJs.camera.lookAt(target);
    }
  }

  void _setCameraPositionAlongView({
    required three.Vector3 target,
    required double offsetX,
    required double offsetY,
    required double offsetZ,
    required double distance,
    required double viewScale,
  }) {
    final vectorLength = math.sqrt(
      offsetX * offsetX + offsetY * offsetY + offsetZ * offsetZ,
    );
    if (vectorLength <= 0) return;
    final scaledDistance = distance / viewScale;
    _threeJs.camera.position.setValues(
      target.x + offsetX / vectorLength * scaledDistance,
      target.y + offsetY / vectorLength * scaledDistance,
      target.z + offsetZ / vectorLength * scaledDistance,
    );
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
    key.target?.position.setValues(
      _keyLightTarget.x,
      _keyLightTarget.y,
      _keyLightTarget.z,
    );
    key.shadow?.mapSize.width = 2048;
    key.shadow?.mapSize.height = 2048;
    key.shadow?.bias = -0.0008;
    key.shadow?.radius = 8;
    key.shadow?.blurSamples = 18;
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

    final sheen = three.RectAreaLight(
      widget.sheenLightColor,
      widget.sheenLightIntensity,
      8.0,
      5.0,
    );
    sheen.position.setValues(
      _sheenLightPosition.x,
      _sheenLightPosition.y,
      _sheenLightPosition.z,
    );
    sheen.lookAt(three.Vector3(
      _sheenLightTarget.x,
      _sheenLightTarget.y,
      _sheenLightTarget.z,
    ));
    _threeJs.scene.add(sheen);
    _sheenLight = sheen;
  }

  Future<void> _buildBoard() async {
    final sideMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xc6965e,
      three.MaterialProperty.roughness: 0.84,
      three.MaterialProperty.metalness: 0.0,
    });
    three.Texture? boardTopAppearance = await _buildBoardTopAppearanceMap();
    if (boardTopAppearance == null) {
      const boardTopAlbedoPath =
          kIsWeb ? 'assets/$_boardTopAlbedoAsset' : _boardTopAlbedoAsset;
      boardTopAppearance =
          await three.TextureLoader(flipY: false).fromAsset(boardTopAlbedoPath);
    }
    if (boardTopAppearance != null) {
      boardTopAppearance
        ..colorSpace = three.SRGBColorSpace
        ..wrapS = three.ClampToEdgeWrapping
        ..wrapT = three.ClampToEdgeWrapping
        ..needsUpdate = true;
    }
    final topMaterial = three.MeshPhysicalMaterial({
      three.MaterialProperty.color: 0xfffcf5,
      if (boardTopAppearance != null)
        three.MaterialProperty.map: boardTopAppearance,
      three.MaterialProperty.roughness: 0.68,
      three.MaterialProperty.metalness: 0.0,
      three.MaterialProperty.clearcoat: 0.16,
      three.MaterialProperty.clearcoatRoughness: 0.82,
      three.MaterialProperty.emissive: 0x000000,
    });
    topMaterial
      ..lightMap = _buildBoardTopIrradianceMap()
      ..lightMapIntensity = 1.80
      ..needsUpdate = true;
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
    if (_enableAdditiveBoardHighlights) {
      _buildSurfaceSheen();
    }

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

  void _buildSurfaceSheen() {
    _surfaceSheenMaterials.clear();
    const layers = [
      (radius: 1.12, opacity: 0.070, scaleX: 3.34, scaleZ: 1.10),
      (radius: 1.54, opacity: 0.040, scaleX: 3.18, scaleZ: 1.06),
      (radius: 2.04, opacity: 0.022, scaleX: 2.92, scaleZ: 1.00),
    ];
    for (int i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final material = three.MeshBasicMaterial({
        three.MaterialProperty.color: 0xffedc5,
        three.MaterialProperty.opacity: layer.opacity * _surfaceSheenOpacity,
        three.MaterialProperty.transparent: true,
        three.MaterialProperty.depthWrite: false,
        three.MaterialProperty.depthTest: true,
        three.MaterialProperty.toneMapped: false,
      });
      _surfaceSheenMaterials.add(material);
      final sheen = three.Mesh(
        three.CircleGeometry(radius: layer.radius, segments: 96),
        material,
      )
        ..position.setValues(
          2.08 + i * 0.22,
          _boardTop + 0.041 + i * 0.001,
          1.42 + i * 0.16,
        )
        ..rotation.x = -math.pi / 2
        ..rotation.z = -0.34
        ..scale.x = layer.scaleX
        ..scale.y = layer.scaleZ;
      _root.add(sheen);
    }
  }

  void _updateBoardBrightness() {
    final b = widget.boardTopBrightness.clamp(0.4, 2.4);
    final top = _boardTopMaterial;
    if (top != null) {
      top.color.setFromHex32(_lerpColorHex(
        0xfffcf5,
        0xfff2cb,
        (b - 1.0).clamp(0.0, 1.0),
      ));
      top.emissive?.setFromHex32(0x000000);
      top.emissiveIntensity = 1.0;
      top.needsUpdate = true;
    }
    for (int i = 0; i < _surfaceSheenMaterials.length; i++) {
      final material = _surfaceSheenMaterials[i];
      final baseOpacity = i == 0
          ? 0.070
          : i == 1
              ? 0.040
              : 0.022;
      material.opacity =
          baseOpacity * _surfaceSheenOpacity * b.clamp(0.75, 1.2);
      material.needsUpdate = true;
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
      key.target?.position.setValues(
        _keyLightTarget.x,
        _keyLightTarget.y,
        _keyLightTarget.z,
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
        _sheenLightPosition.x,
        _sheenLightPosition.y,
        _sheenLightPosition.z,
      );
      sheen.lookAt(three.Vector3(
        _sheenLightTarget.x,
        _sheenLightTarget.y,
        _sheenLightTarget.z,
      ));
    }
    _updateDebugGuides();
  }

  void _updateDebugGuides() {
    _debugGuideGroup.clear();

    final lightPosition = widget.keyLightPosition;
    const target = _keyLightTarget;
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
      three.MaterialProperty.color: 0xb98a52,
      three.MaterialProperty.opacity: 0.055,
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
      three.MaterialProperty.color: 0xffe2ad,
      three.MaterialProperty.opacity: 0.12,
      three.MaterialProperty.transparent: true,
    });
    final frontEdge = three.Mesh(
      three.BoxGeometry(_boardWidth + 0.04, 0.018, 0.014),
      edgeMaterial,
    )..position.setValues(0, _boardTop + 0.020, frontZ + 0.006);
    _root.add(frontEdge);
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
      three.MaterialProperty.color: 0x050403,
      three.MaterialProperty.roughness: 0.22,
      three.MaterialProperty.metalness: 0.02,
    });
    final whiteMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xf7efe2,
      three.MaterialProperty.roughness: 0.54,
      three.MaterialProperty.metalness: 0.02,
    });
    final shadowMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x3f2815,
      three.MaterialProperty.opacity: 0.30,
      three.MaterialProperty.transparent: true,
    });
    final softShadowMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x7a5a37,
      three.MaterialProperty.opacity: 0.12,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.depthWrite: false,
    });
    final radius = step * 0.46;
    const stoneHeightScale = 0.48;

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
            x - radius * 0.16,
            _boardTop + 0.049,
            z + radius * 0.11,
          )
          ..scale.x = 1.20
          ..scale.z = 0.82;
        _stoneGroup.add(shadow);
        final softShadow = three.Mesh(
          three.CylinderGeometry(radius * 1.55, radius * 1.55, 0.004, 40),
          softShadowMaterial,
        )
          ..position.setValues(
            x - radius * 0.22,
            _boardTop + 0.046,
            z + radius * 0.18,
          )
          ..scale.x = 1.28
          ..scale.z = 0.78;
        _stoneGroup.add(softShadow);
      }

      final mesh = three.Mesh(
        three.SphereGeometry(radius, 48, 18),
        material,
      )
        ..position.setValues(
          x,
          _boardTop + radius * stoneHeightScale,
          z,
        )
        ..scale.y = stoneHeightScale
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
    final geometry = three.ShapeGeometry([shape], curveSegments: 12);
    final uv = geometry.getAttributeFromString('uv');
    if (uv != null) {
      geometry.setAttributeFromString('uv2', uv.clone());
    }
    return geometry;
  }

  three.DataTexture _buildBoardTopIrradianceMap() {
    const size = 96;
    final data = three.Uint8Array(size * size * 4);
    for (int y = 0; y < size; y++) {
      final v = y / (size - 1);
      for (int x = 0; x < size; x++) {
        final u = x / (size - 1);
        final window = _windowIrradiance(u, v);
        final illumination = (0.55 + window * 0.45).clamp(0.0, 1.0);

        final index = (y * size + x) * 4;
        data[index] = (255 * illumination).round();
        data[index + 1] = (255 * illumination).round();
        data[index + 2] = (252 * illumination).round();
        data[index + 3] = 255;
      }
    }

    return three.DataTexture(
      data,
      size,
      size,
      three.RGBAFormat,
      three.UnsignedByteType,
      null,
      three.ClampToEdgeWrapping,
      three.ClampToEdgeWrapping,
      three.LinearFilter,
      three.LinearFilter,
      1,
      three.SRGBColorSpace,
    )..needsUpdate = true;
  }

  Future<three.DataTexture?> _buildBoardTopAppearanceMap() async {
    final Uint8List bytes;
    try {
      final data = await rootBundle.load(_boardTopAlbedoAsset);
      bytes = data.buffer.asUint8List();
    } catch (_) {
      return null;
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    const size = 512;
    final source = decoded.width == size && decoded.height == size
        ? decoded
        : img.copyResize(
            decoded,
            width: size,
            height: size,
            interpolation: img.Interpolation.average,
          );
    final data = three.Uint8Array(source.width * source.height * 4);

    const washStrength = 0.22;
    const washPower = 0.82;
    const washStart = 0.15;
    const creamR = 252.0;
    const creamG = 247.0;
    const creamB = 231.0;

    // Grid line UV geometry (same world coords as mesh grid).
    final n = widget.boardSize;
    final lineStartU = 0.5 - _gridSpan / (2 * _boardWidth);
    final lineStepU = _gridSpan / ((n - 1) * _boardWidth);
    final lineEndU = lineStartU + (n - 1) * lineStepU;
    // v = 0.5 - z/width  →  first z line (most negative z) maps to highest v.
    final lineStartV = 0.5 + _gridSpan / (2 * _boardWidth);
    final lineStepV = -_gridSpan / ((n - 1) * _boardWidth);
    final lineEndV = lineStartV + (n - 1) * lineStepV; // = lineStartU (near edge)
    // Half-width in UV: 2 texture pixels gives a ~4px-wide rendered line.
    const halfWidthUV = 2.0 / size;
    const gridDarkR = 0x5c;
    const gridDarkG = 0x4d;
    const gridDarkB = 0x3a;
    const gridTanR = 0xb8;
    const gridTanG = 0xab;
    const gridTanB = 0x94;

    for (int y = 0; y < source.height; y++) {
      final v = y / (source.height - 1);
      for (int x = 0; x < source.width; x++) {
        final u = x / (source.width - 1);
        final window = _windowIrradiance(u, v);
        final directionalWindow =
            ((window - washStart) / (1.0 - washStart)).clamp(0.0, 1.0);
        final wash =
            washStrength * math.pow(directionalWindow, washPower).toDouble();
        final pixel = source.getPixel(x, y);
        final index = (y * source.width + x) * 4;

        // Board surface with cream wash.
        final boardR = _lerpDouble(pixel.r.toDouble(), creamR, wash);
        final boardG = _lerpDouble(pixel.g.toDouble(), creamG, wash);
        final boardB = _lerpDouble(pixel.b.toDouble(), creamB, wash);

        // Grid line coverage: max of vertical-line and horizontal-line proximity.
        double gridCoverage = 0.0;
        if (n >= 2) {
          // Vertical lines run at fixed u, spanning v ∈ [lineEndV, lineStartV].
          if (v >= lineEndV - halfWidthUV && v <= lineStartV + halfWidthUV) {
            final distU = _distToNearestGridLine(u, lineStartU, lineStepU, n);
            gridCoverage = math.max(
              gridCoverage,
              (1.0 - distU / halfWidthUV).clamp(0.0, 1.0),
            );
          }
          // Horizontal lines run at fixed v, spanning u ∈ [lineStartU, lineEndU].
          if (u >= lineStartU - halfWidthUV && u <= lineEndU + halfWidthUV) {
            final distV = _distToNearestGridLine(v, lineStartV, lineStepV, n);
            gridCoverage = math.max(
              gridCoverage,
              (1.0 - distV / halfWidthUV).clamp(0.0, 1.0),
            );
          }
        }

        double finalR = boardR;
        double finalG = boardG;
        double finalB = boardB;
        if (gridCoverage > 0.0) {
          // Line color fades dark→tan as window irradiance rises (same as mesh grid).
          final gridLight =
              math.pow(window, widget.gridFadePower).toDouble();
          final fade =
              (1.0 - gridLight * widget.gridFadeMult)
                  .clamp(widget.gridFadeMin, 0.88);
          final lineBlend = widget.gridBaseOpacity * fade * gridCoverage;
          final lineR = _lerpDouble(
              gridDarkR.toDouble(), gridTanR.toDouble(), gridLight);
          final lineG = _lerpDouble(
              gridDarkG.toDouble(), gridTanG.toDouble(), gridLight);
          final lineB = _lerpDouble(
              gridDarkB.toDouble(), gridTanB.toDouble(), gridLight);
          finalR = _lerpDouble(boardR, lineR, lineBlend);
          finalG = _lerpDouble(boardG, lineG, lineBlend);
          finalB = _lerpDouble(boardB, lineB, lineBlend);
        }

        data[index] = finalR.round().clamp(0, 255);
        data[index + 1] = finalG.round().clamp(0, 255);
        data[index + 2] = finalB.round().clamp(0, 255);
        data[index + 3] = pixel.a.round();
      }
    }

    return three.DataTexture(
      data,
      source.width,
      source.height,
      three.RGBAFormat,
      three.UnsignedByteType,
      null,
      three.ClampToEdgeWrapping,
      three.ClampToEdgeWrapping,
      three.LinearFilter,
      three.LinearFilter,
      1,
      three.SRGBColorSpace,
    )..needsUpdate = true;
  }

  /// Returns the distance in UV space from [coord] to the nearest grid line.
  /// Lines are at [lineStart] + i×[lineStep] for i in [0, n).
  static double _distToNearestGridLine(
      double coord, double lineStart, double lineStep, int n) {
    if (n < 2) return double.infinity;
    final rawIdx = (coord - lineStart) / lineStep;
    final idx = rawIdx.round().clamp(0, n - 1).toInt();
    return (coord - (lineStart + idx * lineStep)).abs();
  }

  double _windowIrradiance(double u, double v) {
    // UV (1,0) = near-right corner = screen lower-right = target window-light region.
    // broadWindow and upperRightLift centres sit just inside that corner.
    final cu = widget.windowCenterU;
    final cv = widget.windowCenterV;
    final su = widget.windowSpreadU;
    final sv = widget.windowSpreadV;
    final broadWindow = math.exp(
      -((u - cu) * (u - cu) / su + (v - cv) * (v - cv) / sv),
    );
    // diagonalWash uses (1-v) so that high-u / low-v (near-right, C corner) gets the
    // strongest lift; far-left (A corner) falls to zero.
    final diagonalWash =
        ((u * 0.96 + (1.0 - v) * 0.68 - 0.18) / 1.58).clamp(0.0, 1.0);
    final middleLift = math.pow(diagonalWash, 0.58).toDouble();
    final upperRightLift = math.exp(
      -((u - 0.94) * (u - 0.94) / 0.65 + (v - 0.04) * (v - 0.04) / 0.50),
    );
    return (broadWindow * middleLift * 0.92 + upperRightLift * 0.08)
        .clamp(0.0, 1.0);
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

double _lerpDouble(double a, double b, double t) {
  final clamped = t.clamp(0.0, 1.0);
  return a + (b - a) * clamped;
}
