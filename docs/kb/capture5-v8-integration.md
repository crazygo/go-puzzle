# Capture5 v8 Model Integration Guide

This guide covers integrating the `capture5_13x13_policy_only_v8.onnx` model
into go-puzzle 1.3.0 alongside the existing KataGo ONNX models, so users can
choose their AI.

## What v8 Is

v8 is a CNN policy model trained in the `go-puzzle-ml` repository on a 13×13
capture-five task. It takes a board state and returns a policy output with 170
entries: board points `0..168` plus pass at index `169`. The current app
integration ignores pass and selects only legal board points. It does **not**
do MCTS at inference time — it is a pure policy model, fast enough for
real-time play.

**Release results:** 88/90 arena wins, 28/30 vs `mcts_counter`, 14/14 tactical
fixtures, 0 illegal moves.

## Model Contract

**ONNX inputs:**

| Name       | Shape           | dtype   | Description                     |
|------------|-----------------|---------|----------------------------------|
| `features` | `[1, 9, 13, 13]` | float32 | Spatial feature planes (below)  |
| `globals`  | `[1, 6]`        | float32 | Scalar game state features       |

**ONNX outputs (only `policy` is used at runtime):**

| Name            | Shape     | dtype   |
|-----------------|-----------|---------|
| `policy`        | `[1, 170]` | float32 |
| `value`         | `[1, 1]`  | float32 |
| `capture_delta` | `[1, 1]`  | float32 |
| `group_risk`    | `[1, 1]`  | float32 |

`policy[0][row * 13 + col]` is the logit for placing a stone at `(row, col)`.
`policy[0][169]` is pass in the ML rules engine. Apply softmax only after
filtering to app-supported legal board moves. The first app integration does
not apply pass implicitly.

**Implementation note:** the production implementation should be treated as
authoritative for app API names. Older draft snippets in this guide may use
stale `KatagoPolicyCandidate` field names; current app code uses
`position`, `score`, `probability`, `rank`, and `policyPlane`.

## Feature Encoding Specification

### Plane Definitions (features tensor, channels 0–8)

Let `player = board.currentPlayer` (1=black, 2=white),
`opponent = 3 - player`.

| Index | Name                     | Value                                                                         |
|-------|--------------------------|-------------------------------------------------------------------------------|
| 0     | `black_stones`           | `1.0` where `cells[i] == SimBoard.black`, else `0.0`                         |
| 1     | `white_stones`           | `1.0` where `cells[i] == SimBoard.white`, else `0.0`                         |
| 2     | `current_player`         | Filled with `+1.0` if player is black, `-1.0` if white                       |
| 3     | `last_move`              | `1.0` at the last move index (if known and not pass), else `0.0`              |
| 4     | `legal_moves_or_ko`      | `1.0` at each legal move; `-1.0` at the ko point (if ko index is exposed)    |
| 5     | `own_1_liberty_groups`   | `1.0` at every point belonging to a current-player group with exactly 1 liberty |
| 6     | `own_2_liberty_groups`   | `1.0` at every point belonging to a current-player group with exactly 2 liberties |
| 7     | `opponent_1_liberty_groups` | `1.0` at every point belonging to opponent group with exactly 1 liberty   |
| 8     | `opponent_2_liberty_groups` | `1.0` at every point belonging to opponent group with exactly 2 liberties |

**Ko note:** `SimBoard._koIndex` is private. Until a public getter `int get koIndex => _koIndex;` is added to `SimBoard`, omit the `-1.0` ko mark (planes[4] only contains legal move `1.0` values). The accuracy loss is small because ko is rare.

**Liberty planes:** Walk every cell. For non-empty cells, flood-fill to find the group and count distinct adjacent empty cells (liberties). Mark the cell in the appropriate plane based on `(color == player, libertyCount)`.

### Global Definitions (globals tensor, indices 0–5)

| Index | Value                                        |
|-------|----------------------------------------------|
| 0     | `board.size / 19.0`                          |
| 1     | `board.captureTarget / 10.0`                 |
| 2     | `board.capturedByBlack / board.captureTarget` |
| 3     | `board.capturedByWhite / board.captureTarget` |
| 4     | `+1.0` if `currentPlayer == black`, else `-1.0` |
| 5     | `estimatedMoveNumber / (board.size * board.size * 2.0)` |

**Estimating move number** (SimBoard has no explicit counter):
```dart
final stonesOnBoard = board.cells.where((c) => c != SimBoard.empty).length;
final estimatedMoveNumber =
    stonesOnBoard + board.capturedByBlack + board.capturedByWhite + board.consecutivePasses;
```

## Files to Add

### 1. `assets/models/capture5_13x13_policy_only_v8.onnx`

Copy from `go-puzzle-ml/models/released/capture5_13x13_policy_only_v8.onnx`.

SHA-256 (from metadata): check `capture5_13x13_policy_only_v8.metadata.json` in
the ML repo for the exact hash. Verify after copy with `shasum -a 256`.

Add to `pubspec.yaml` under `flutter > assets`:
```yaml
  - assets/models/capture5_13x13_policy_only_v8.onnx
```

### 2. `lib/game/capture5_onnx_features.dart`

Feature encoder. Mirrors `capture5/features/encoder.py` from go-puzzle-ml.

```dart
import 'mcts_engine.dart';

const String kCapture5DefaultModelAsset =
    'assets/models/capture5_13x13_policy_only_v8.onnx';

class Capture5EncodedFeatures {
  const Capture5EncodedFeatures({
    required this.features,
    required this.featuresShape,
    required this.globals,
    required this.globalsShape,
  });

  final List<double> features;
  final List<int> featuresShape;
  final List<double> globals;
  final List<int> globalsShape;
}

class Capture5FeatureEncoder {
  const Capture5FeatureEncoder();

  static const int _planes = 9;
  static const int _globalCount = 6;

  Capture5EncodedFeatures encode(SimBoard board) {
    final n = board.size;
    final total = n * n;
    final planes = List<double>.filled(_planes * total, 0.0);

    final player = board.currentPlayer;
    final opponent = player == SimBoard.black ? SimBoard.white : SimBoard.black;

    // Planes 0 & 1: stone positions
    for (var i = 0; i < total; i++) {
      if (board.cells[i] == SimBoard.black) planes[0 * total + i] = 1.0;
      if (board.cells[i] == SimBoard.white) planes[1 * total + i] = 1.0;
    }

    // Plane 2: current player (uniform)
    final playerVal = player == SimBoard.black ? 1.0 : -1.0;
    for (var i = 0; i < total; i++) {
      planes[2 * total + i] = playerVal;
    }

    // Plane 3: last move — caller may set this externally if tracked;
    // SimBoard doesn't expose lastMove, so this plane is left at 0.

    // Plane 4: legal moves (ko mark omitted — SimBoard._koIndex is private)
    for (final moveIndex in board.getLegalMoves()) {
      planes[4 * total + moveIndex] = 1.0;
    }

    // Planes 5–8: liberty groups
    _encodeLibertyPlanes(board, planes, player, opponent, n, total);

    // globals
    final stonesOnBoard =
        board.cells.where((c) => c != SimBoard.empty).length;
    final estimatedMoveNumber = stonesOnBoard +
        board.capturedByBlack +
        board.capturedByWhite +
        board.consecutivePasses;
    final maxMoves = n * n * 2.0;

    final globals = [
      n / 19.0,
      board.captureTarget / 10.0,
      board.capturedByBlack / board.captureTarget.toDouble(),
      board.capturedByWhite / board.captureTarget.toDouble(),
      playerVal,
      estimatedMoveNumber / maxMoves,
    ];

    return Capture5EncodedFeatures(
      features: planes,
      featuresShape: [1, _planes, n, n],
      globals: globals,
      globalsShape: [1, _globalCount],
    );
  }

  void _encodeLibertyPlanes(
    SimBoard board,
    List<double> planes,
    int player,
    int opponent,
    int n,
    int total,
  ) {
    final visited = <int>{};
    for (var i = 0; i < total; i++) {
      final color = board.cells[i];
      if (color == SimBoard.empty || visited.contains(i)) continue;

      // Flood-fill group and count liberties
      final group = <int>[];
      final liberties = <int>{};
      final queue = [i];
      visited.add(i);
      while (queue.isNotEmpty) {
        final cur = queue.removeLast();
        group.add(cur);
        final row = cur ~/ n;
        final col = cur % n;
        for (final nb in _neighbours(row, col, n)) {
          final nbColor = board.cells[nb];
          if (nbColor == SimBoard.empty) {
            liberties.add(nb);
          } else if (nbColor == color && !visited.contains(nb)) {
            visited.add(nb);
            queue.add(nb);
          }
        }
      }

      final lc = liberties.length;
      if (lc != 1 && lc != 2) continue;

      final own = color == player;
      // Plane index: own+1lib=5, own+2lib=6, opp+1lib=7, opp+2lib=8
      final planeIdx = own
          ? (lc == 1 ? 5 : 6)
          : (lc == 1 ? 7 : 8);

      for (final pt in group) {
        planes[planeIdx * total + pt] = 1.0;
      }
    }
  }

  List<int> _neighbours(int row, int col, int n) {
    final result = <int>[];
    if (row > 0) result.add((row - 1) * n + col);
    if (row < n - 1) result.add((row + 1) * n + col);
    if (col > 0) result.add(row * n + col - 1);
    if (col < n - 1) result.add(row * n + col + 1);
    return result;
  }
}
```

### 3. `lib/game/capture5_flutter_onnx_model_adapter.dart`

ONNX adapter. Implements `AsyncKatagoModelAdapter` to reuse existing dispatch.

```dart
import 'dart:math' as math;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter/foundation.dart';

import 'capture5_onnx_features.dart';
import 'katago_model_adapter.dart';
import 'mcts_engine.dart';

class Capture5OnnxModelAdapter implements AsyncKatagoModelAdapter {
  Capture5OnnxModelAdapter({
    OnnxRuntime? runtime,
    Capture5FeatureEncoder encoder = const Capture5FeatureEncoder(),
    Duration sessionLoadTimeout = const Duration(seconds: 30),
  })  : _runtime = runtime ?? OnnxRuntime(),
        _encoder = encoder,
        _sessionLoadTimeout = sessionLoadTimeout;

  final OnnxRuntime _runtime;
  final Capture5FeatureEncoder _encoder;
  final Duration _sessionLoadTimeout;
  final Map<String, OrtSession> _sessions = {};
  final Map<String, String> _loadFailures = {};

  @override
  Future<void> preload(Iterable<KatagoModelRequest> requests) async {
    final assets = requests.map((r) => r.modelAsset).toSet();
    for (final asset in assets) {
      try {
        await _sessionFor(asset);
      } catch (_) {}
    }
  }

  @override
  Future<KatagoModelEvaluation> chooseMove(KatagoModelRequest request) async {
    OrtValue? featuresOrt;
    OrtValue? globalsOrt;
    Map<String, OrtValue> outputs = const {};
    try {
      final legalMoves = request.board.getLegalMoves().where((idx) {
        return request.board
            .analyzeMove(idx ~/ request.board.size, idx % request.board.size)
            .isLegal;
      }).toList(growable: false);
      if (legalMoves.isEmpty) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'capture5_no_legal_moves',
        );
      }

      final session = await _sessionFor(request.modelAsset);
      final encoded = _encoder.encode(request.board);
      final timeout = Duration(milliseconds: request.timeBudgetMillis);

      featuresOrt = await OrtValue.fromList(
        encoded.features,
        encoded.featuresShape,
      ).timeout(timeout);
      globalsOrt = await OrtValue.fromList(
        encoded.globals,
        encoded.globalsShape,
      ).timeout(timeout);

      outputs = await session.run({
        'features': featuresOrt,
        'globals': globalsOrt,
      }).timeout(timeout);

      final policyOrt = outputs['policy'];
      if (policyOrt == null) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'capture5_missing_policy_output',
        );
      }
      final logits = List<double>.from(await policyOrt.asFlattenedList());
      if (logits.length < request.board.size * request.board.size) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'capture5_policy_output_too_short',
        );
      }

      // Softmax over legal moves only
      final candidates = _rankCandidates(
        logits: logits,
        legalMoves: legalMoves,
        boardSize: request.board.size,
        candidateLimit: request.candidateLimit,
        temperature: request.policyTemperature,
      );
      final move = _selectMove(candidates, request.policyTemperature);

      double? value;
      final valueOrt = outputs['value'];
      if (valueOrt != null) {
        final v = await valueOrt.asFlattenedList();
        if (v.isNotEmpty) value = (v[0] as num).toDouble();
      }

      return KatagoModelEvaluation(
        status: KatagoBackendStatus.ready,
        move: move,
        policyCandidates: candidates,
        value: value,
      );
    } catch (error) {
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.failed,
        failureReason: 'capture5_onnx_error:$error',
      );
    } finally {
      await featuresOrt?.dispose();
      await globalsOrt?.dispose();
      for (final out in outputs.values) {
        await out.dispose();
      }
    }
  }

  Future<void> close() async {
    for (final s in _sessions.values) await s.close();
    _sessions.clear();
    _loadFailures.clear();
  }

  Future<OrtSession> _sessionFor(String modelAsset) async {
    final existing = _sessions[modelAsset];
    if (existing != null) return existing;
    final failure = _loadFailures[modelAsset];
    if (failure != null) throw StateError(failure);
    try {
      final path = kIsWeb && !modelAsset.startsWith('assets/')
          ? 'assets/$modelAsset'
          : modelAsset;
      final session = await _runtime
          .createSessionFromAsset(path)
          .timeout(_sessionLoadTimeout);
      return _sessions[modelAsset] = session;
    } catch (error) {
      final reason = 'capture5_onnx_load_failed:$modelAsset:$error';
      _loadFailures[modelAsset] = reason;
      throw StateError(reason);
    }
  }

  List<KatagoPolicyCandidate> _rankCandidates({
    required List<double> logits,
    required List<int> legalMoves,
    required int boardSize,
    required int candidateLimit,
    required double temperature,
  }) {
    // Softmax over legal moves
    final legalLogits = legalMoves.map((i) => logits[i]).toList();
    final maxLogit = legalLogits.reduce(math.max);
    final exps = legalLogits.map((l) => math.exp(l - maxLogit)).toList();
    final expSum = exps.fold(0.0, (a, b) => a + b);

    final candidates = [
      for (var k = 0; k < legalMoves.length; k++)
        KatagoPolicyCandidate(
          moveIndex: legalMoves[k],
          prior: exps[k] / expSum,
          row: legalMoves[k] ~/ boardSize,
          col: legalMoves[k] % boardSize,
        ),
    ];
    candidates.sort((a, b) => b.prior.compareTo(a.prior));
    return candidates.take(candidateLimit).toList(growable: false);
  }

  int _selectMove(List<KatagoPolicyCandidate> candidates, double temperature) {
    if (candidates.isEmpty) return -1;
    if (temperature <= 0.0) return candidates.first.moveIndex;
    // Temperature-weighted sampling
    final rng = math.Random();
    final probs = candidates.map((c) => c.prior).toList();
    final total = probs.fold(0.0, (a, b) => a + b);
    var r = rng.nextDouble() * total;
    for (var i = 0; i < candidates.length; i++) {
      r -= probs[i];
      if (r <= 0) return candidates[i].moveIndex;
    }
    return candidates.last.moveIndex;
  }
}
```

## Changes to Existing Files

### `lib/game/ai_algorithm_framework.dart`

**Step 1 — Add new framework ID.**

In the `AiAlgorithmFrameworkId` enum, add:
```dart
capture5,  // Capture-five CNN policy model (13x13)
```

**Step 2 — Add two new algorithm configs** to `AiAlgorithmRegistry._configs`:
```dart
AiAlgorithmConfig(
  id: 'capture5_v8',
  frameworkId: AiAlgorithmFrameworkId.capture5,
  parameters: {
    'modelAsset': kCapture5DefaultModelAsset,
    'timeBudgetMillis': '500',
    'policyTemperature': '0.05',
    'candidateLimit': '7',
  },
),
```

**Step 3 — Wire the new framework ID** in `AiAlgorithmRegistry.createAgent()`.
Add a case alongside the existing `katago` dispatch:
```dart
case AiAlgorithmFrameworkId.capture5:
  return _AsyncCapture5OnnxAgent(config: config, adapter: sharedCapture5Adapter);
```

**Step 4 — Add `_AsyncCapture5OnnxAgent`**, modelled after `_AsyncKatagoOnnxAgent`:
```dart
class _AsyncCapture5OnnxAgent implements AiAgent {
  const _AsyncCapture5OnnxAgent({
    required AiAlgorithmConfig config,
    required Capture5OnnxModelAdapter adapter,
  })  : _config = config,
        _adapter = adapter;

  final AiAlgorithmConfig _config;
  final Capture5OnnxModelAdapter _adapter;

  @override
  Future<int> chooseMove(SimBoard board) async {
    final request = KatagoModelRequest(
      board: board,
      modelAsset: _config.parameters['modelAsset'] ?? kCapture5DefaultModelAsset,
      timeBudgetMillis:
          int.tryParse(_config.parameters['timeBudgetMillis'] ?? '500') ?? 500,
      policyTemperature:
          double.tryParse(_config.parameters['policyTemperature'] ?? '0.1') ?? 0.1,
      candidateLimit:
          int.tryParse(_config.parameters['candidateLimit'] ?? '7') ?? 7,
    );
    final eval = await _adapter.chooseMove(request);
    if (eval.status != KatagoBackendStatus.ready || eval.move == null) return -1;
    return eval.move!;
  }
}
```

**Step 5 — Import** at the top of `ai_algorithm_framework.dart`:
```dart
import 'capture5_flutter_onnx_model_adapter.dart';
import 'capture5_onnx_features.dart';
```

### `pubspec.yaml`

Under `flutter > assets`:
```yaml
  - assets/models/capture5_13x13_policy_only_v8.onnx
```

## Coexistence and UI

With two framework IDs (`katago` and `capture5`) both registered, users can
select their preferred AI from any screen that lists algorithm config IDs:

| Config ID   | Description                             |
|-------------|-----------------------------------------|
| `capture5_v8` | Capture5 v8 — full strength policy model |
| `katago_standard` | KataGo ONNX — general Go engine   |
| `katago_weak`     | KataGo ONNX — beginner-friendly strength |

Expose these via the existing AI selection UI. No changes to `ai_search_entry.dart`
are required if `_AsyncCapture5OnnxAgent.chooseMove()` runs in the same isolate
context as existing agents.

## Minor Recommended Change to `mcts_engine.dart`

Expose the ko point to enable accurate encoding of plane 4:
```dart
// In SimBoard class
int get koIndex => _koIndex;  // -1 if no ko restriction
```

Then in `Capture5FeatureEncoder.encode()`, replace the legal-move loop with:
```dart
for (final moveIndex in board.getLegalMoves()) {
  planes[4 * total + moveIndex] = 1.0;
}
if (board.koIndex >= 0) {
  planes[4 * total + board.koIndex] = -1.0;
}
```

## Verification Checklist

- [ ] ONNX file copied to `assets/models/` and `pubspec.yaml` updated
- [ ] SHA-256 matches `capture5_13x13_policy_only_v8.metadata.json`
- [ ] `Capture5FeatureEncoder` passes a round-trip: encode a known board, confirm policy output is a valid distribution over 169 positions
- [ ] `capture5_v8` agent beats heuristic-only in 10+ games (expected ≥ 9/10)
- [ ] No illegal moves from `capture5_v8_standard` in 50+ games
- [ ] KataGo agents still work unchanged after adding the new framework
- [ ] `flutter analyze` passes with no errors
