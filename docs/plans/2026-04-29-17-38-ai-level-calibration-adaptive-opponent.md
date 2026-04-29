# AI 分级校准与自适应对手系统

## 1. Background

### Context

当前 AI 由两层组成：

- **`_WeightedCaptureAiAgent`**（`capture_ai.dart`）：权重评分 + 短路 rollout，含 7 个行为权重（`immediateCaptureWeight`、`opponentAtariWeight`、`ownRescueWeight`、`selfAtariPenalty`、`centerWeight`、`contactWeight`、`libertyWeight`）和 `playouts` 深度。
- **`MctsEngine`**（`mcts_engine.dart`）：纯 MCTS，通过 `maxPlayouts` 控制。

现有风格（`CaptureAiStyle`）：`hunter`（猎杀）、`trapper`（设陷）、`switcher`（转场）、`counter`（稳守），共 4 种。现有等级（`DifficultyLevel`）：`beginner`、`intermediate`、`advanced`，共 3 级，仅通过 `playouts` 数量区分。

`CaptureAiArena` 已支持 round-robin 对战，并输出胜率、平均步数、提子数、Elo 等信息，具备批量测评基础。落子时机（AI 思考完立刻落子）目前没有延迟处理。玩家胜负统计由 `GameHistoryRepository` 记录（最多 50 局），但尚未用于动态匹配对手。

### Problem

1. **等级设计粗糙**：3 个难度只靠 `playouts` 区分，初级机器人并不是"更短视"或"更容易漏掉打吃"，只是"想得少"，导致弱 AI 仍然比初学者强太多，失去挑战梯度。
2. **等级不可信**：等级由参数"设计出来"，没有通过实测胜率校准，不同风格同一级别的 AI 强弱差异未知。
3. **缺乏自适应性**：无论玩家水平如何，每次对局都使用相同等级，没有"略强于玩家"的动态匹配机制。
4. **落子体验缺失**：AI 计算完成后立刻落子，没有思考动画/延迟，给玩家压迫感，且计算时间随 `playouts` 变化，落子时机不稳定。
5. **风格与等级正交不清晰**：4 风格 × 3 等级共 12 种组合，但每个组合的参数差异仅体现在 `playouts` 上，风格特征随等级变化时没有相应调整。

### Motivation

- 引入"行为参数 → 实测 Elo → 映射等级"的校准流程，让等级可信、可迭代。
- 让低等级 AI 犯的是符合棋理的典型错误（短视、漏提、贪吃被反杀），而不是随机劣化。
- 根据玩家历史胜率，始终给出有挑战的对手（60% 略强、40% 略弱），提升留存。
- 规范落子延迟，让 AI 落子节奏自然，不压迫也不拖沓。

---

## 2. Goals

1. 扩展行为参数模型，让低等级 AI 表现出符合棋理的弱点（漏提、短视、缺少预判）。
2. 建立离线 Arena 校准工具，对所有风格 × 候选参数组合测出 Elo，映射到 Lv.1–Lv.9。
3. 基于 `GameHistoryRepository` 计算玩家动态 Elo，按"60% 略强 / 40% 略弱"规则自动选取对手。
4. 为 AI 落子添加最小/最大延迟，保证 UX 节奏（最少等待感、最多不卡顿）。
5. 全程保持风格特征在等级之间可辨识，低等级版猎杀风仍然"偏向进攻"，只是更容易出错。

---

## 3. Implementation Plan

### Phase A — 扩展行为参数（AI 错误模型）

1. 在 `_CaptureAiProfile` 中新增以下参数：

   | 参数 | 含义 | 典型范围 |
   |---|---|---|
   | `captureBlindRate` | 漏掉直接提子的概率 | 0.0（绝不漏）~ 0.6 |
   | `selfAtariBlindRate` | 忽略自打吃惩罚的概率 | 0.0 ~ 0.5 |
   | `rescueBlindRate` | 漏掉己方被打吃需要救棋的概率 | 0.0 ~ 0.5 |
   | `topKCandidates` | rollout 前保留的候选手数 | 2（短视）~ 8（全局） |

2. 在 `_WeightedCaptureAiAgent._score()` 中，根据以上参数按概率将对应权重临时置零，模拟"没看到"而非"随机变笨"。

3. `_CaptureAiProfile.forStyle()` 改为接受更细粒度的等级参数（`AiGeneLevel`，见 Phase B），而不仅仅是 `DifficultyLevel`。

### Phase B — 定义参数基因表（候选机器人）

1. 在 `capture_ai.dart` 中定义 `AiGeneLevel`（值域 1–9，对应 9 个候选等级），替代现有 3 档 `DifficultyLevel`。

2. 为每个 `CaptureAiStyle × AiGeneLevel` 组合手工拟定初始行为参数（基因），遵循以下原则：
   - **Lv.1–3**：`captureBlindRate ≥ 0.45`，`topKCandidates = 2`，`playouts = 8`，角色是"偶尔漏提，容易贪吃被反杀"。
   - **Lv.4–6**：`captureBlindRate 0.15–0.30`，`topKCandidates = 4`，`playouts = 20`，角色是"偶尔漏打吃，但不常犯低级错"。
   - **Lv.7–9**：`captureBlindRate ≤ 0.05`，`topKCandidates = 6`，`playouts = 48`，角色是"偶尔因风格激进/保守而失误，战术识别完整"。
   - 各风格在同一等级内保留原有倾向比例（猎杀仍高 `immediateCaptureWeight`，稳守仍高 `libertyWeight`）。

3. 将基因表以常量 Map 的形式内嵌于代码（`_geneTable`），方便后续通过 Arena 测试结果迭代调整。

### Phase C — Arena 离线校准工具

1. 新增 `CaptureAiCalibrator`（`lib/game/capture_ai_calibrator.dart`），封装以下流程：
   - 枚举所有 `CaptureAiStyle × AiGeneLevel` 组合，共 4 × 9 = 36 个机器人。
   - 以 `CaptureAiArena.runRoundRobin` 进行全量对战（每对 200 局，可配置）。
   - 汇总每个机器人的对战 Elo（使用现有 `_calculateElo` 逻辑）。
   - 输出一份机器人 Elo 排行表（文本/JSON），供手动验证后提交为常量。

2. 将校准结果作为编译期常量 `kAiEloTable`（`Map<String, double>`，key 为 `"${style.name}_lv${level}"`）写入 `capture_ai.dart`，供运行时动态匹配使用。

3. 校准工具只在开发环境（`kDebugMode` 或独立 Dart 脚本）下运行，不打包进 release。

### Phase D — 玩家 Elo 估算与动态对手选择

1. 在 `GameRecord`（`lib/models/game_record.dart`）中增加：
   - `aiStyleName`（对战 AI 风格）
   - `aiGeneLevel`（对战 AI 基因等级）

2. 在 `GameHistoryRepository` 中新增 `estimatePlayerElo()` 方法：
   - 取最近 20 局（可配置）的胜负结果。
   - 对每局已知的 AI Elo 用简化 Elo 公式反推玩家 Elo 估算值。
   - 首次游戏时默认给定初始 Elo（与 Lv.4 对应）。

3. 新增 `AdaptiveOpponentSelector`（`lib/game/adaptive_opponent_selector.dart`）：
   - 输入：玩家当前估算 Elo，`kAiEloTable`。
   - 输出：以 60% 概率选取比玩家 Elo 略高的机器人，40% 概率选取略低的机器人。
   - "略高/略低"定义为 Elo 差值在目标区间内（如 ±80–200 Elo 点），而非绝对排名。
   - 若用户手动指定风格，则在该风格内按相同概率分布选等级；若风格也不限，则全域选取。

4. 在 `CaptureGameProvider` 构造时，若未传入 `difficulty`，改为调用 `AdaptiveOpponentSelector` 自动决定等级和风格，并在 `GameRecord` 中记录实际使用的 AI 参数。

### Phase E — 落子延迟（UX）

1. 在 `CaptureGameProvider._doAiMove()` 中，将 AI 计算与实际落子分离：
   - 记录计算开始时间戳。
   - 计算完成后，若已用时 < `minMoveDelay`（建议 800 ms），用 `Future.delayed` 补足剩余等待。
   - 设置 `maxMoveDelay`（建议 2500 ms）作为上限，超时后直接落子（避免复杂局面过长等待）。
   - `isAiThinking` 标志保持为 true，直到延迟结束后落子，UI 可渲染思考动画。

2. `minMoveDelay` 和 `maxMoveDelay` 作为 `CaptureGameProvider` 的可选构造参数，默认值来自常量，方便测试时设为 0。

### Phase F — 向后兼容与迁移

1. 保留 `DifficultyLevel` 枚举作为外部接口（settings、URL params），内部映射到 `AiGeneLevel`：
   - `beginner` → Lv.1–3 随机（加权中间值）
   - `intermediate` → Lv.4–6
   - `advanced` → Lv.7–9

2. 现有 `CaptureAiRegistry.create(style, difficulty)` 保持签名不变，内部根据新的 `_geneTable` 路由。

3. 所有现有测试保持通过；`minMoveDelay` 在测试中默认 `Duration.zero`。

---

## 4. Acceptance Criteria

### 行为参数
- Lv.1 机器人在 9 路棋盘 200 局测试中，漏掉直接提子（captureBlindRate）的实际触发次数占比 ≥ 35%。
- Lv.9 机器人与 Lv.1 机器人对战 200 局，胜率 ≥ 80%。

### 等级校准
- 36 个机器人完成 round-robin 对战后，Elo 从最低到最高呈单调递增趋势（允许同等级不同风格间交叉，但相邻等级 Elo 均值差 ≥ 60 点）。
- `kAiEloTable` 常量已提交，可供运行时查询。

### 自适应对手
- 新建游戏时，系统根据玩家历史自动选取机器人（无需用户手动选等级）。
- 在 100 局模拟测试中，选取的机器人 Elo 比玩家估算 Elo 略高（+80~200）的概率落在 55%–65% 区间内。
- 胜负结果正确写入 `GameRecord.aiGeneLevel`，`estimatePlayerElo()` 随对局增加而收敛。

### 落子延迟
- AI 落子等待时间在 `[minMoveDelay, maxMoveDelay]` 区间内（800 ms–2500 ms）。
- `isAiThinking` 在延迟期间保持 `true`，UI 思考指示器正常显示。
- 测试环境下将两个延迟参数设为 `Duration.zero`，所有现有测试通过。

### 回归
- `flutter analyze --no-fatal-infos --no-fatal-warnings` 通过。
- `flutter test` 全部通过，无测试被删除或跳过。
