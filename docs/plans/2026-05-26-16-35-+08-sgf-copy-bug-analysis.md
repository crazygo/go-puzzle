# SGF 复制功能代码审查

*创建：2026-05-26，更新：2026-05-26（坐标方向确认后修正修复方向）*

---

## Background

用户在测试 v8 模型时复制 SGF，发现棋谱中 White 落在初始 Black 棋子位置，例如：

```
AB[gg][hh]AW[hg][gh]
;B[ig];W[hh];...
```

SGF 显示 `W[hh]` 落在 `AB[hh]`（初始黑棋），看似非法落子。

文字棋谱也有对应现象：
```
03 B[8六]   ← 初始黑棋报告在此位置
06 W[8六]   ← 白棋也落在同一坐标
```

---

## 根本原因（已确认）

### `applyCaptureInitialLayout` 与 `orderedCaptureInitialMoves` 对 `twistCross` 布局不一致

这两个函数对 `twistCross` 初始棋子的位置定义**不同**：

**`applyCaptureInitialLayout`**（`capture_game_provider.dart` 约 line 224）：

```dart
case CaptureInitialMode.twistCross:
    board[center][center]       = Black   // (6,6)
    board[center][center+1]     = White   // (6,7)
    board[center-1][center]     = White   // (5,6)  ← center-1
    board[center-1][center+1]   = Black   // (5,7)  ← center-1
```

**`orderedCaptureInitialMoves`**（同文件约 line 262）：

```dart
CaptureInitialMode.twistCross => [
    [center,   center],       // (6,6) Black
    [center,   center+1],     // (6,7) White
    [center+1, center+1],     // (7,7) Black  ← center+1
    [center+1, center],       // (7,6) White  ← center+1
]
```

13×13 棋盘 center=6，两函数对下方两颗棋子的行坐标差了 **2 行**（row 5 vs row 7）。

### 坐标方向确认

通过用户视觉确认（中文坐标：顶部 = "一"，底部 = "十三"；国际坐标：顶部行 = 13，底部行 = 1）：

- `applyCaptureInitialLayout`（`center-1` = row 5）对应用户视觉中的 "7六/8六"（center 正上方），**与实际棋盘一致**
- `orderedCaptureInitialMoves`（`center+1` = row 7）对应 "7八/8八"（center 正下方），**与实际棋盘不一致**

因此 **`applyCaptureInitialLayout` 正确，`orderedCaptureInitialMoves` 是 bug 所在**。

### 后果链

| 步骤 | 发生了什么 |
|------|-----------|
| 游戏初始化 | `applyCaptureInitialLayout` 在 `board[5][6/7]`（"7六/8六"）放白/黑棋，位置正确 |
| AI 决策 | `SimBoard.fromGameState` 正确读取 board，`board[7][6/7]`（"7八/8八"）是**空的** |
| AI 合法下棋 | White 落在 `board[7][7]`，`GoEngine.placeStone` 返回成功，`moveLog` 记录 `[7,7]` |
| SGF 复制 | `orderedCaptureInitialMoves` 错误地报告初始黑棋在 `[7,7]` → `AB[hh]` |
| SGF 复制（续） | `moveLog[1]=[7,7]` 编码为 `W[hh]` |
| 最终 SGF | `AB[hh]` 与 `W[hh]` 重叠 → 看起来非法，根源是 `orderedCaptureInitialMoves` 用了错误行坐标 |

**SGF 编码函数（`_toSgfCoord`、`_copyMovesAsSgf`）本身没有 bug**，问题在于 `orderedCaptureInitialMoves` 与 `applyCaptureInitialLayout` 的定义冲突。

---

## 死代码（额外问题，不影响上述 bug）

以下四个函数**定义存在但从未被调用**：

| 函数 | 行号 |
|------|------|
| `_copyMoveLogAsText` | 5180 |
| `_buildMoveLogPlainText` | 5215 |
| `_copyMoveLogAsSgf` | 5191 |
| `_buildMoveLogSgf` | 5231 |

实际被按钮（line 4861/4865）调用的是：
- `_copyMovesAsText`（line 5445）
- `_copyMovesAsSgf`（line 5538）

---

## 修复方案（已应用）

**修 `orderedCaptureInitialMoves`**（将 `center+1` 改为 `center-1`，使其与
`applyCaptureInitialLayout` 一致）：

```dart
CaptureInitialMode.twistCross => [
    [center,     center],       // (6,6) Black  — 不变
    [center,     center + 1],   // (6,7) White  — 不变
    [center - 1, center + 1],   // (5,7) Black  — 修复：was center+1
    [center - 1, center],       // (5,6) White  — 修复：was center+1
],
```

修复后布局（13×13，center=6，中文坐标顶部="一"）：

```
row 5 (六行):  . W B .
row 6 (七行):  . B W .
col:           5  6 7 8
```

中文坐标：黑在 7七/8六，白在 8七/7六 — 与用户视觉确认一致。

**`applyCaptureInitialLayout` 无需修改**，它本身是正确的。

---

## 关联文件

- `lib/providers/capture_game_provider.dart`
  - `applyCaptureInitialLayout`（line ~202）← 正确，无需修改
  - `orderedCaptureInitialMoves`（line ~238）← **bug 所在，已修复**（`center+1` → `center-1`）
- `lib/screens/capture_game_screen.dart`
  - `_copyMovesAsSgf`（line 5538）← 编码逻辑正确，无需修改
  - `_copyMovesAsText`（line 5445）← 编码逻辑正确，无需修改
  - 死代码区：line 5180–5293（可删除）
