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
        toneMappingExposure: 0.70,
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
    _threeJs.scene.add(three.AmbientLight(0xffeddc, 0.19));

    final key = three.DirectionalLight(0xfff0d2, 0.92);
    key.position.setValues(5.8, 5.6, -3.8);
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
    _keyLightBasePosition = key.position.clone();

    final fill = three.DirectionalLight(0xf4e8d8, 0.14);
    fill.position.setValues(-4.8, 2.6, 3.2);
    _threeJs.scene.add(fill);

    final sheen = three.SpotLight(0xfffaed, 0.36, 20, math.pi / 5, 0.82, 1.18);
    sheen.position.setValues(6.2, 5.9, -3.9);
    sheen.castShadow = true;
    sheen.target?.position.setValues(0.4, -0.05, 0.08);
    sheen.shadow?.mapSize.width = 2048;
    sheen.shadow?.mapSize.height = 2048;
    sheen.shadow?.bias = -0.0009;
    _threeJs.scene.add(sheen);
    if (sheen.target != null) {
      _threeJs.scene.add(sheen.target);
    }
  }

  void _buildBoard() {
    final sideMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xa06a35,
      three.MaterialProperty.roughness: 0.78,
      three.MaterialProperty.metalness: 0.0,
    });
    final topMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xdab074,
      three.MaterialProperty.roughness: 0.36,
      three.MaterialProperty.metalness: 0.03,
      three.MaterialProperty.emissive: 0x2d1e10,
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

    final frontGlow = three.Mesh(
      three.BoxGeometry(_boardWidth - _cornerRadius, 0.018, 0.020),
      three.MeshBasicMaterial({
        three.MaterialProperty.color: 0xffc179,
        three.MaterialProperty.opacity: 0.30,
        three.MaterialProperty.transparent: true,
      }),
    )..position.setValues(0, _boardTop + 0.030, _boardWidth / 2 + 0.014);
    _root.add(frontGlow);

    final reflectionMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0xfff3dd,
      three.MaterialProperty.opacity: 0.06,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.blending: three.AdditiveBlending,
      three.MaterialProperty.depthWrite: false,
    });
    for (int i = 0; i < 5; i++) {
      final t = i / 4;
      final glow = three.Mesh(
        three.CircleGeometry(radius: 0.28 + _noise(820 + i * 17) * 0.34),
        reflectionMaterial,
      )
        ..position.setValues(
          1.85 + t * 1.70 + (_noise(830 + i * 13) - 0.5) * 0.14,
          _boardTop + 0.046 + i * 0.0004,
          -2.45 + t * 0.68 + (_noise(840 + i * 19) - 0.5) * 0.16,
        )
        ..rotation.x = -math.pi / 2
        ..rotation.z = -0.46 + (_noise(850 + i * 23) - 0.5) * 0.22
        ..scale.x = 2.0 + _noise(860 + i * 29) * 1.5
        ..scale.y = 0.65 + _noise(870 + i * 31) * 0.25;
      _root.add(glow);
    }

    final shaftMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0xfff6e5,
      three.MaterialProperty.opacity: 0.035,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.blending: three.AdditiveBlending,
      three.MaterialProperty.depthWrite: false,
    });
    for (int i = 0; i < 3; i++) {
      final shaft = three.Mesh(
        three.PlaneGeometry(0.28 + i * 0.05, 2.6 - i * 0.32),
        shaftMaterial,
      )
        ..position.setValues(2.95 + i * 0.32, 1.02 + i * 0.05, -2.85 + i * 0.18)
        ..rotation.y = -0.72
        ..rotation.z = 0.18 + i * 0.04;
      _root.add(shaft);
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
    _leafShadowBlobs.clear();

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
      final phase = _noise(510 + i * 13) * math.pi * 2;
      final phaseWeight = 0.010 + _noise(610 + i * 17) * 0.012;

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
    final driftX = math.sin(w + 0.2) * 0.042 * sway;
    final driftZ = math.cos(w * 0.92 + 0.8) * 0.024 * sway;
    _leafShadowGroup.position.x = driftX;
    _leafShadowGroup.position.z = driftZ;
    _leafShadowGroup.rotation.y = -0.06 + math.sin(w * 0.7) * 0.014 * sway;

    for (final blob in _leafShadowBlobs) {
      final local =
          math.sin(w * 1.12 + blob.phase) * blob.phaseWeight * sway * 0.75;
      blob.core.position.x = blob.baseX + local;
      blob.core.position.z = blob.baseZ + local * 0.55;
      blob.core.rotation.z += math.sin(w * 0.38 + blob.phase) * 0.00024;
      blob.penumbra.position.x = blob.baseX + local * 0.68;
      blob.penumbra.position.z = blob.baseZ + local * 0.42;
      blob.penumbra.rotation.z = blob.core.rotation.z;
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
      key.intensity = 1.02 * intensityPulse;
    }
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
