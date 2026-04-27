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
  final List<_LeafShadowSprite> _leafShadowSprites = [];
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
    _threeJs.scene.add(three.AmbientLight(0xffe2c4, 0.24));

    final key = three.DirectionalLight(0xffd4a2, 0.94);
    key.position.setValues(-4.2, 6.2, 4.8);
    key.castShadow = true;
    key.target?.position.setValues(0, 0, 0);
    _threeJs.scene.add(key);
    if (key.target != null) {
      _threeJs.scene.add(key.target);
    }
    _keyLight = key;
    _keyLightBasePosition = key.position.clone();

    final fill = three.DirectionalLight(0xe9d8c1, 0.15);
    fill.position.setValues(4.8, 3.4, -3.8);
    _threeJs.scene.add(fill);

    final sheen = three.SpotLight(0xffc784, 0.42, 16, math.pi / 6, 0.74, 1.7);
    sheen.position.setValues(-2.6, 4.8, 2.8);
    sheen.target?.position.setValues(0.6, 0, 0.2);
    _threeJs.scene.add(sheen);
    if (sheen.target != null) {
      _threeJs.scene.add(sheen.target);
    }
  }

  void _buildBoard() {
    final sideMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xa6662c,
      three.MaterialProperty.roughness: 0.72,
      three.MaterialProperty.metalness: 0.0,
    });
    final topMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xd79b55,
      three.MaterialProperty.roughness: 0.62,
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
      three.MaterialProperty.color: 0x463522,
      three.MaterialProperty.opacity: 0.62,
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

  void _buildWoodDetail() {
    final material = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x835128,
      three.MaterialProperty.opacity: 0.26,
      three.MaterialProperty.transparent: true,
    });
    for (int i = 0; i < 116; i++) {
      final t = i / 115;
      final z = -_boardWidth / 2 + t * _boardWidth;
      final length = _boardWidth * (0.16 + 0.56 * _noise(i * 17));
      final x = (_noise(i * 41) - 0.5) * (_boardWidth - length);
      final grain = three.Mesh(
        three.BoxGeometry(length, 0.006, 0.006),
        material,
      )
        ..position.setValues(x, _boardTop + 0.043, z)
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
      three.MaterialProperty.size: 0.038,
      three.MaterialProperty.opacity: 0.16,
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
    _leafShadowSprites.clear();

    final material = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x3a2613,
      three.MaterialProperty.opacity:
          widget.leafShadowOpacity.clamp(0.04, 0.28),
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.depthWrite: false,
    });

    for (int i = 0; i < 9; i++) {
      final baseX = (_noise(100 + i * 23) - 0.5) * (_gridSpan * 0.88);
      final baseZ = (_noise(200 + i * 29) - 0.5) * (_gridSpan * 0.88);
      final width = 0.55 + _noise(300 + i * 17) * 0.95;
      final depth = 0.32 + _noise(400 + i * 13) * 0.78;
      final speed = (0.85 + _noise(500 + i * 11) * 0.80) *
          widget.leafShadowSpeed.clamp(0.5, 2.0);
      final phase = _noise(600 + i * 7) * math.pi * 2;
      final swayMultiplier = widget.leafShadowSway.clamp(0.4, 2.2);
      final swayX = (0.07 + _noise(700 + i * 19) * 0.16) * swayMultiplier;
      final swayZ = (0.08 + _noise(800 + i * 5) * 0.20) * swayMultiplier;
      final mesh = three.Mesh(
        three.PlaneGeometry(width, depth),
        material,
      )
        ..position.setValues(baseX, _boardTop + 0.040, baseZ)
        ..rotation.x = -math.pi / 2
        ..rotation.z = (_noise(900 + i * 31) - 0.5) * 0.8;
      _leafShadowGroup.add(mesh);
      _leafShadowSprites.add(
        _LeafShadowSprite(
          mesh: mesh,
          baseX: baseX,
          baseZ: baseZ,
          baseScaleX: 0.86 + _noise(1000 + i * 37) * 0.62,
          baseScaleZ: 0.82 + _noise(1100 + i * 41) * 0.58,
          speed: speed,
          phase: phase,
          swayX: swayX,
          swayZ: swayZ,
        ),
      );
    }

    _root.add(_leafShadowGroup);
  }

  void _animateLeafShadowCaustics(double t) {
    final swing = widget.keyLightSwing.clamp(0.0, 2.0);
    final intensityPulse = 0.92 + 0.08 * math.sin(t * 1.15 * (0.6 + swing));
    for (final sprite in _leafShadowSprites) {
      final w = t * sprite.speed + sprite.phase;
      sprite.mesh.position.x = sprite.baseX + math.sin(w) * sprite.swayX;
      sprite.mesh.position.z =
          sprite.baseZ + math.cos(w * 0.93 + 0.5) * sprite.swayZ;
      sprite.mesh.rotation.z = math.sin(w * 0.71) * 0.25;
      sprite.mesh.scale.x = sprite.baseScaleX + math.sin(w * 1.21) * 0.12;
      sprite.mesh.scale.z = sprite.baseScaleZ + math.cos(w * 1.09) * 0.10;
    }

    final key = _keyLight;
    final base = _keyLightBasePosition;
    if (key != null && base != null) {
      key.position.setValues(
        base.x + math.sin(t * 0.88) * 0.14 * swing,
        base.y + math.sin(t * 1.02 + 0.6) * 0.11 * swing,
        base.z + math.cos(t * 0.76) * 0.13 * swing,
      );
      key.intensity = 0.90 * intensityPulse;
    }
  }

  void _rebuildStones() {
    _stoneGroup.clear();
    final n = widget.boardSize;
    if (n < 2) return;

    final step = _gridSpan / (n - 1);
    const start = -_gridSpan / 2;
    final blackMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0x18120d,
      three.MaterialProperty.roughness: 0.40,
      three.MaterialProperty.metalness: 0.0,
    });
    final whiteMaterial = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0xf0e6d6,
      three.MaterialProperty.roughness: 0.32,
      three.MaterialProperty.metalness: 0.0,
    });
    final shadowMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x3b2410,
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
          x + radius * 0.12,
          _boardTop + 0.052,
          z + radius * 0.18,
        )
        ..scale.x = 1.20
        ..scale.z = 0.82;
      _stoneGroup.add(shadow);

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

class _LeafShadowSprite {
  _LeafShadowSprite({
    required this.mesh,
    required this.baseX,
    required this.baseZ,
    required this.baseScaleX,
    required this.baseScaleZ,
    required this.speed,
    required this.phase,
    required this.swayX,
    required this.swayZ,
  });

  final three.Mesh mesh;
  final double baseX;
  final double baseZ;
  final double baseScaleX;
  final double baseScaleZ;
  final double speed;
  final double phase;
  final double swayX;
  final double swayZ;
}
