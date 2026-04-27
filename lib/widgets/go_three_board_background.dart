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
    this.leafShadowSpeed = 1.05,
    this.leafShadowSway = 1.0,
    this.keyLightSwing = 1.0,
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
  final double leafShadowSpeed;
  final double leafShadowSway;
  final double keyLightSwing;

  @override
  State<GoThreeBoardBackground> createState() => _GoThreeBoardBackgroundState();
}

class _GoThreeBoardBackgroundState extends State<GoThreeBoardBackground> {
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
  final List<_LeafShadowBlob> _leafShadowBlobs = [];
  three.DirectionalLight? _keyLight;
  three.Vector3? _keyLightBasePosition;
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
        toneMappingExposure: 1.02,
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
    if (oldWidget.leafShadowOpacity != widget.leafShadowOpacity ||
        oldWidget.leafShadowSpeed != widget.leafShadowSpeed ||
        oldWidget.leafShadowSway != widget.leafShadowSway) {
      _buildLeafShadowCaustics();
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
    _buildBoard();
    _buildSideWoodDetail();
    _buildGrid();
    _buildWoodDetail();
    _buildLeafShadowCaustics();
    _buildParticles();
    _rebuildStones();

    _threeJs.addAnimationEvent((dt) {
      if (!mounted) return;
      _elapsed += dt;
      if (widget.animate) {
        _setCamera(_elapsed);
        _animateLeafShadowCaustics(_elapsed);
      }
      if (widget.particles) {
        _particleGroup.rotation.y += dt * 0.045;
        _particleGroup.position.y = 0.12 + math.sin(_elapsed * 0.7) * 0.025;
      }
    });
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
    _threeJs.scene.add(three.AmbientLight(0xffead2, 0.24));

    final key = three.DirectionalLight(0xffdcb2, 1.28);
    key.position.setValues(5.2, 6.4, 4.4);
    key.castShadow = true;
    key.target?.position.setValues(0.7, -0.10, -0.50);
    _threeJs.scene.add(key);
    if (key.target != null) {
      _threeJs.scene.add(key.target);
    }
    _keyLight = key;
    _keyLightBasePosition = key.position.clone();

    final fill = three.DirectionalLight(0xf6ecdf, 0.30);
    fill.position.setValues(-4.8, 3.4, -3.0);
    _threeJs.scene.add(fill);

    final sheen = three.SpotLight(0xffdfb5, 0.34, 16, math.pi / 7, 0.72, 1.2);
    sheen.position.setValues(3.4, 5.2, 2.1);
    sheen.target?.position.setValues(0.8, -0.05, -0.25);
    _threeJs.scene.add(sheen);
    if (sheen.target != null) {
      _threeJs.scene.add(sheen.target);
    }
  }

  void _buildBoard() {
    final sideMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0x9f6933,
      three.MaterialProperty.roughness: 0.56,
      three.MaterialProperty.metalness: 0.0,
    });
    final topMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xdeb47b,
      three.MaterialProperty.roughness: 0.24,
      three.MaterialProperty.metalness: 0.0,
    });

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

    _addBoardBox(
      width: straightWidth,
      height: 0.032,
      depth: _boardWidth + 0.012,
      y: _boardTop + 0.012,
      material: topMaterial,
    );
    _addBoardBox(
      width: _boardWidth + 0.012,
      height: 0.032,
      depth: straightWidth,
      y: _boardTop + 0.013,
      material: topMaterial,
    );

    for (final xSign in [-1.0, 1.0]) {
      for (final zSign in [-1.0, 1.0]) {
        final cornerSkin = three.Mesh(
          three.CylinderGeometry(_cornerRadius, _cornerRadius, 0.034, 32),
          topMaterial,
        )
          ..position.setValues(
            xSign * (_boardWidth / 2 - _cornerRadius),
            _boardTop + 0.015,
            zSign * (_boardWidth / 2 - _cornerRadius),
          )
          ..receiveShadow = true;
        _root.add(cornerSkin);
      }
    }

    final topSpecularLayer = three.Mesh(
      three.BoxGeometry(_boardWidth + 0.008, 0.014, _boardWidth + 0.008),
      three.MeshPhongMaterial({
        three.MaterialProperty.color: 0xffdfba,
        three.MaterialProperty.opacity: 0.20,
        three.MaterialProperty.transparent: true,
        three.MaterialProperty.shininess: 90,
      }),
    )
      ..position.setValues(0, _boardTop + 0.034, 0)
      ..receiveShadow = true;
    _root.add(topSpecularLayer);

    final frontGlow = three.Mesh(
      three.BoxGeometry(_boardWidth - _cornerRadius, 0.018, 0.020),
      three.MeshBasicMaterial({
        three.MaterialProperty.color: 0xffc179,
        three.MaterialProperty.opacity: 0.30,
        three.MaterialProperty.transparent: true,
      }),
    )..position.setValues(0, _boardTop + 0.030, _boardWidth / 2 + 0.014);
    _root.add(frontGlow);
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
    final material = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0x6f4020,
      three.MaterialProperty.opacity: 0.34,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.roughness: 0.60,
      three.MaterialProperty.metalness: 0.0,
    });
    const frontZ = _boardWidth / 2 + 0.016;
    for (int i = 0; i < 42; i++) {
      final y = -_boardThickness * (0.14 + 0.72 * i / 41);
      final length = _boardWidth * (0.42 + 0.46 * _noise(i * 31));
      final x = (_noise(i * 13) - 0.5) * (_boardWidth - length * 0.68);
      final line = three.Mesh(
        three.CylinderGeometry(0.005, 0.007, length, 8),
        material,
      )
        ..position.setValues(x, y, frontZ)
        ..rotation.x = math.pi / 2
        ..rotation.y = (_noise(i * 43) - 0.5) * 0.08
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
    final lineMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0x6d5033,
      three.MaterialProperty.opacity: 0.34,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.roughness: 0.32,
      three.MaterialProperty.metalness: 0.0,
    });
    final grooveShadowMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0x4b3420,
      three.MaterialProperty.opacity: 0.16,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.roughness: 0.70,
      three.MaterialProperty.metalness: 0.0,
    });
    final grooveHighlightMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xf5d6aa,
      three.MaterialProperty.opacity: 0.18,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.roughness: 0.24,
      three.MaterialProperty.metalness: 0.0,
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
      final hShadow = three.Mesh(
        three.BoxGeometry(_gridSpan, 0.004, 0.008),
        grooveShadowMaterial,
      )..position.setValues(0, _boardTop + 0.031, p + 0.0025);
      final vShadow = three.Mesh(
        three.BoxGeometry(0.008, 0.004, _gridSpan),
        grooveShadowMaterial,
      )..position.setValues(p + 0.0025, _boardTop + 0.031, 0);
      final hHighlight = three.Mesh(
        three.BoxGeometry(_gridSpan, 0.003, 0.006),
        grooveHighlightMaterial,
      )..position.setValues(0, _boardTop + 0.036, p - 0.002);
      final vHighlight = three.Mesh(
        three.BoxGeometry(0.006, 0.003, _gridSpan),
        grooveHighlightMaterial,
      )..position.setValues(p - 0.002, _boardTop + 0.036, 0);
      _root
        ..add(horizontal)
        ..add(vertical)
        ..add(hShadow)
        ..add(vShadow)
        ..add(hHighlight)
        ..add(vHighlight);
    }
  }

  void _buildWoodDetail() {
    final material = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0x85522a,
      three.MaterialProperty.opacity: 0.28,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.roughness: 0.48,
      three.MaterialProperty.metalness: 0.0,
    });
    for (int i = 0; i < 116; i++) {
      final t = i / 115;
      final z = -_boardWidth / 2 + t * _boardWidth;
      final length = _boardWidth * (0.16 + 0.56 * _noise(i * 17));
      final x = (_noise(i * 41) - 0.5) * (_boardWidth - length);
      final grain = three.Mesh(
        three.CylinderGeometry(0.004, 0.006, length, 6),
        material,
      )
        ..position.setValues(x, _boardTop + 0.043, z)
        ..rotation.z = math.pi / 2
        ..rotation.y = (_noise(i * 29) - 0.5) * 0.08;
      _root.add(grain);
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
    _leafShadowBlobs.clear();

    final opacity = widget.leafShadowOpacity.clamp(0.03, 0.22);
    final coreMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x4a3320,
      three.MaterialProperty.opacity: opacity * 0.68,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.depthWrite: false,
    });
    final penumbraMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x5a3f27,
      three.MaterialProperty.opacity: opacity * 0.26,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.depthWrite: false,
    });

    const centerX = 1.45;
    const centerZ = -1.35;
    for (int i = 0; i < 14; i++) {
      final ring = 0.35 + _noise(210 + i * 31) * 1.85;
      final angle = -0.85 + _noise(310 + i * 19) * 1.25;
      final baseX = centerX + math.cos(angle) * ring;
      final baseZ = centerZ + math.sin(angle) * ring * 0.78;
      final radius = 0.16 + _noise(410 + i * 7) * 0.28;
      final phase = _noise(510 + i * 13) * math.pi * 2;
      final phaseWeight = 0.010 + _noise(610 + i * 17) * 0.016;

      final seedRot = (_noise(710 + i * 29) - 0.5) * 0.7;
      final core = three.Mesh(
        three.CircleGeometry(radius: radius * 0.42, segments: 18),
        coreMaterial,
      )..position.setValues(baseX, _boardTop + 0.0385, baseZ);
      final penumbra = three.Mesh(
        three.CircleGeometry(radius: radius * 1.12, segments: 22),
        penumbraMaterial,
      )..position.setValues(baseX, _boardTop + 0.0380, baseZ);
      core.rotation
        ..x = -math.pi / 2
        ..z = seedRot;
      penumbra.rotation
        ..x = -math.pi / 2
        ..z = seedRot;

      for (int j = 0; j < 4; j++) {
        final localR = radius * (0.36 + _noise(790 + i * 31 + j * 7) * 0.42);
        final localX = (_noise(810 + i * 17 + j * 23) - 0.5) * radius * 0.95;
        final localY = (_noise(830 + i * 11 + j * 19) - 0.5) * radius * 0.95;
        final corePatch = three.Mesh(
          three.CircleGeometry(radius: localR, segments: 18),
          coreMaterial,
        )..position.setValues(localX, localY, 0);
        final penumbraPatch = three.Mesh(
          three.CircleGeometry(radius: localR * 2.15, segments: 22),
          penumbraMaterial,
        )..position.setValues(localX * 0.8, localY * 0.8, 0);
        core.add(corePatch);
        penumbra.add(penumbraPatch);
      }

      _leafShadowGroup
        ..add(penumbra)
        ..add(core);
      _leafShadowBlobs.add(
        _LeafShadowBlob(
          core: core,
          penumbra: penumbra,
          baseX: baseX,
          baseZ: baseZ,
          phase: phase,
          phaseWeight: phaseWeight,
        ),
      );
    }

    _root.add(_leafShadowGroup);
  }

  void _animateLeafShadowCaustics(double t) {
    final swing = widget.keyLightSwing.clamp(0.0, 2.0);
    final sway = widget.leafShadowSway.clamp(0.3, 1.8);
    final speed = widget.leafShadowSpeed.clamp(0.4, 1.8);
    final w = t * 0.22 * speed;
    final driftX = math.sin(w + 0.2) * 0.055 * sway;
    final driftZ = math.cos(w * 0.92 + 0.8) * 0.030 * sway;
    _leafShadowGroup.position.x = driftX;
    _leafShadowGroup.position.z = driftZ;
    _leafShadowGroup.rotation.y = -0.06 + math.sin(w * 0.7) * 0.014 * sway;

    for (final blob in _leafShadowBlobs) {
      final local =
          math.sin(w * 1.12 + blob.phase) * blob.phaseWeight * sway * 0.75;
      blob.core.position.x = blob.baseX + local;
      blob.core.position.z = blob.baseZ + local * 0.55;
      blob.penumbra.position.x = blob.baseX + local * 0.68;
      blob.penumbra.position.z = blob.baseZ + local * 0.42;
    }

    final intensityPulse = 0.94 + 0.045 * math.sin(t * 0.34 + 0.2);
    final key = _keyLight;
    final base = _keyLightBasePosition;
    if (key != null && base != null) {
      key.position.setValues(
        base.x + math.sin(t * 0.32 + 0.2) * 0.08 * swing,
        base.y + math.sin(t * 0.27 + 0.6) * 0.06 * swing,
        base.z + math.cos(t * 0.29 + 0.9) * 0.07 * swing,
      );
      key.intensity = 0.98 * intensityPulse;
    }
  }

  void _rebuildStones() {
    _stoneGroup.clear();
    final n = widget.boardSize;
    if (n < 2) return;

    final step = _gridSpan / (n - 1);
    const start = -_gridSpan / 2;
    final blackMaterial = three.MeshPhysicalMaterial({
      three.MaterialProperty.color: 0x17110f,
      three.MaterialProperty.roughness: 0.12,
      three.MaterialProperty.metalness: 0.02,
    });
    final whiteMaterial = three.MeshPhysicalMaterial({
      three.MaterialProperty.color: 0xf1e8db,
      three.MaterialProperty.roughness: 0.20,
      three.MaterialProperty.metalness: 0.0,
    });
    final shadowMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x3f2815,
      three.MaterialProperty.opacity: 0.20,
      three.MaterialProperty.transparent: true,
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
      final shadow = three.Mesh(
        three.CylinderGeometry(radius * 1.08, radius * 1.08, 0.006, 40),
        shadowMaterial,
      )
        ..position.setValues(
          x + radius * 0.07,
          _boardTop + 0.049,
          z + radius * 0.10,
        )
        ..scale.x = 1.14
        ..scale.z = 0.88;
      _stoneGroup.add(shadow);
      final shadowSoft = three.Mesh(
        three.CylinderGeometry(radius * 1.34, radius * 1.34, 0.004, 40),
        three.MeshBasicMaterial({
          three.MaterialProperty.color: 0x2a1b0f,
          three.MaterialProperty.opacity: 0.08,
          three.MaterialProperty.transparent: true,
        }),
      )
        ..position.setValues(x + radius * 0.11, _boardTop + 0.048, z + radius * 0.16)
        ..scale.x = 1.24
        ..scale.z = 0.92;
      _stoneGroup.add(shadowSoft);

      final mesh = three.Mesh(
        three.SphereGeometry(radius, 64, 24),
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

      final spec = three.Mesh(
        three.SphereGeometry(radius * 0.56, 32, 12),
        three.MeshPhongMaterial({
          three.MaterialProperty.color: stone.color == GoThreeStoneColor.black
              ? 0xb8aba5
              : 0xffffff,
          three.MaterialProperty.opacity:
              stone.color == GoThreeStoneColor.black ? 0.18 : 0.24,
          three.MaterialProperty.transparent: true,
          three.MaterialProperty.shininess: 96,
        }),
      )
        ..position.setValues(
          x - radius * 0.15,
          _boardTop + radius * 0.52,
          z - radius * 0.12,
        )
        ..scale.y = 0.30;
      _stoneGroup.add(spec);
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
}

class _LeafShadowBlob {
  _LeafShadowBlob({
    required this.core,
    required this.penumbra,
    required this.baseX,
    required this.baseZ,
    required this.phase,
    required this.phaseWeight,
  });

  final three.Mesh core;
  final three.Mesh penumbra;
  final double baseX;
  final double baseZ;
  final double phase;
  final double phaseWeight;
}
