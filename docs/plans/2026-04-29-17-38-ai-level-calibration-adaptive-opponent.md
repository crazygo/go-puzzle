# AI 分级校准与自适应对手系统

## 1. Background

### Context

当前 AI 由两层组成：

- **`_WeightedCaptureAiAgent`**（`capture_ai.dart`）：权重评分 + 短路 rollout，含 7 个行为权重（`immediateCaptureWeight`、`opponentAtariWeight`、`ownRescueWeight`、`selfAtariPenalty`、`centerWeight`、`contactWeight`、`libertyWeight`）和 `playouts` 深度。
- **`MctsEngine`**（`mcts_engine.dart`）：纯 MCTS，通过 `maxPlayouts` 控制。

现有风格（`CaptureAiStyle`）：`hunter`（猎杀）、`trapper`（设陷）、`switcher`（转场）、`counter`（稳守），共 4 种。现有等级（`DifficultyLevel`）：`beginner`、`intermediate`、`advanced`，共 3 级，仅通过 `playouts` 数量区分。

`CaptureAiArena` 已支持 round-robin 对战，并输出胜率、平均步数、提子数、Elo 等信息，具备批量测评基础。落子时机（AI 思考完立刻落子）目前没有延迟处理。玩家胜负统计由 `GameHistoryRepository` 记录（最多 50 局），但尚未用于动态匹配对手。

**目标用户**：K12 学生（主要是小学至初中）。核心体验原则：**让用户赢得有成就感**优先于展示技术能力。机器人整体应略弱于对应水平的用户，让用户通过认真思考能够取胜，而非被碾压。

### Problem

1. **等级设计粗糙**：3 个难度只靠 `playouts` 区分，初级机器人并不是"更短视"或"更容易漏掉打吃"，只是"想得少"，导致弱 AI 仍然比初学者强太多，没有胜利爽感。
2. **等级不可信**：等级由参数"设计出来"，没有通过实测胜率校准，不同风格同一级别的 AI 强弱差异未知。
3. **缺乏自适应性**：无论玩家水平如何，每次对局都使用相同等级，没有"略弱于玩家"的动态匹配机制。
4. **落子体验缺失**：AI 计算完成后立刻落子，没有思考动画/延迟，给玩家压迫感，且计算时间随 `playouts` 变化，落子时机不稳定。
5. **风格与等级正交不清晰**：4 风格 × 3 等级共 12 种组合，但每个组合的参数差异仅体现在 `playouts` 上，风格特征随等级变化时没有相应调整。
6. **等级命名缺失**：没有面向 K12 用户的等级命名体系；直接沿用"段/级"对新用户不友好。

### Motivation

- 构建 28 阶（含两大区间）的等级体系，以围棋人类评级为参照但使用自有命名。
- 引入"行为参数 → 实测 Elo → 映射等级"的校准流程，让等级可信、可迭代。
- 让低等级 AI 犯的是符合棋理的典型错误（短视、漏提、贪吃被反杀），且错误概率随等级提升快速衰减到 0，而非随机劣化。
- 根据玩家历史胜率，始终给出**略弱于玩家**的对手（60% 略弱、40% 略强），保证胜利成就感同时维持挑战。
- 规范落子延迟，让 AI 落子节奏自然，不压迫也不拖沓。

---

## 2. Goals

1. 建立 28 阶两区间等级体系和对应的产品命名，与人类围棋评级对齐但不直接使用级/段名称。
2. 扩展行为参数模型，让低等级 AI（探索区 8 阶及以下）表现出符合棋理的弱点（漏提、短视），且犯傻概率随等级提升单调衰减至 0。
3. 建立离线 Arena 校准工具，对所有风格 × 候选参数组合测出 Elo，映射到 28 个等级档位。
4. 基于 `GameHistoryRepository` 计算玩家动态 Elo，按"60% 略弱 / 40% 略强"规则自动选取对手，给用户以胜利爽感为优先。
5. 为 AI 落子添加最小/最大延迟，保证 UX 节奏（最少等待感、最多不卡顿）。
6. 全程保持风格特征在等级之间可辨识，低等级版猎杀风仍然"偏向进攻"，只是更容易出错。

---

## 3. 等级体系设计

### 3.1 等级区间与命名

整体等级结构参照人类围棋评级体系：

| 区间名（待定）| 档位数 | 对应人类评级 | 能力描述 |
|---|---|---|---|
| **探索区**（Exploration） | 8 阶（E1–E8） | 22 级 ~ 15 级 | 初学者；会犯低级错误，但错误在此区间快速衰减 |
| **进阶区**（Advancement） | 6 阶（A1–A6） | 14 级 ~ 9 级 | 掌握基本提子和逃棋；不犯傻，但视野有限 |
| **挑战区**（Challenge） | 8 阶（C1–C8） | 8 级 ~ 1 级 | 具备连续威胁能力；棋力接近认真思考的成年人 |
| **精英区**（Elite） | 6 阶（L1–L6） | 业余 1 段 ~ 6 段 | 接近当前本地策略上限；每个风格的最强形态 |

> **命名说明**：区间英文缩写仅供代码内部使用；面向用户的展示名称后续另行设计（例如以"探险家→侠客→宗师→传说"等 K12 友好的名称呈现），不在本 plan 范围内。

代码中等级用整数 1–28 表示，1 最弱，28 最强。映射关系：E1–E8 = 1–8，A1–A6 = 9–14，C1–C8 = 15–22，L1–L6 = 23–28。

### 3.2 犯傻衰减规则（Blunder Decay）

"犯傻"定义为以下三类行为参数触发：

- `captureBlindRate`（漏掉直接提子）
- `selfAtariBlindRate`（忽略自打吃风险）
- `rescueBlindRate`（漏掉己方被打吃）

衰减约束：

| 等级区间 | 犯傻概率上限 | 说明 |
|---|---|---|
| E1（等级 1） | 最高 0.55 | 最初级：经常漏提 |
| E8（等级 8） | 约 0.15 | 低级区末尾：偶尔出错 |
| 等级 9（进阶区起点） | **0.00** | 进入进阶区后严格禁止 |
| A1–L6（等级 9–28） | **0.00** | 绝不犯傻，只有战略判断失误 |

衰减曲线采用指数衰减（而非线性），使得 E1–E4 下降较慢、E4–E8 下降急剧，视觉上和局面感受上快速"变聪明"，给玩家明显的成长反馈。

```
blunderRate(level) = 0.55 × exp(-0.35 × (level - 1))   for level 1..8
blunderRate(level) = 0.0                                  for level >= 9
```

### 3.3 等级与棋力的对应关系

等级是实测结果，不是参数定义。粗略参照：

| 等级 | 对标人类评级 | Elo 目标区间（初始估算，待校准） |
|---|---|---|
| 1–8   | 22 级 ~ 15 级 | 400–750 |
| 9–14  | 14 级 ~ 9 级  | 750–1000 |
| 15–22 | 8 级 ~ 1 级   | 1000–1300 |
| 23–28 | 业1段 ~ 业6段 | 1300–1600 |

具体 Elo 值由 Arena 校准后确定（见 Phase C）。

---

## 4. Implementation Plan

### Phase A — 扩展行为参数（AI 错误模型）

1. 在 `_CaptureAiProfile` 中新增以下参数：

   | 参数 | 含义 | 有效区间 |
   |---|---|---|
   | `captureBlindRate` | 漏掉直接提子的概率 | 0.0（绝不漏）~ 0.55 |
   | `selfAtariBlindRate` | 忽略自打吃惩罚的概率 | 0.0 ~ 0.45 |
   | `rescueBlindRate` | 漏掉己方被打吃需要救棋的概率 | 0.0 ~ 0.45 |
   | `topKCandidates` | rollout 前保留的候选手数 | 2（短视）~ 10（全局） |

2. 在 `_WeightedCaptureAiAgent._score()` 中，根据以上参数按概率将对应权重临时置零，模拟"没看到"而非"随机变笨"。每次评分调用独立采样，不在一局内累积偏差。

3. 提供静态工具方法 `AiBlunderProfile.forLevel(int level)` 按指数衰减公式计算对应等级的三个盲区率，供 Phase B 的基因表使用，杜绝手工拼凑。

4. `_CaptureAiProfile.forStyle()` 改为接受 28 档 `AiRankLevel`（见 Phase B），而不仅仅是 `DifficultyLevel`。

### Phase B — 定义参数基因表（候选机器人）

1. 在 `capture_ai.dart` 中定义 `AiRankLevel`（值域 1–28），替代现有 3 档 `DifficultyLevel`。对外暴露 `rank`（int）和 `zone`（enum：exploration / advancement / challenge / elite）属性。

2. 为每个 `CaptureAiStyle × AiRankLevel` 组合生成行为参数（基因），规则如下：

   **探索区（rank 1–8）**
   - `captureBlindRate`、`selfAtariBlindRate`、`rescueBlindRate` 按指数衰减公式计算。
   - `topKCandidates` 从 2 线性增长到 4。
   - `playouts` 从 6 增长到 14。

   **进阶区（rank 9–14）**
   - 三个盲区率严格为 0。
   - `topKCandidates` 从 4 增长到 6。
   - `playouts` 从 16 增长到 28。

   **挑战区（rank 15–22）**
   - 三个盲区率严格为 0。
   - `topKCandidates` 从 6 增长到 8。
   - `playouts` 从 32 增长到 56。
   - 开始引入策略性失误（风格偏向过激/过保守），通过调整 `immediateCaptureWeight` 偏置实现。

   **精英区（rank 23–28）**
   - 三个盲区率严格为 0。
   - `topKCandidates` = 10。
   - `playouts` 从 64 增长到 96。
   - 强化风格特征到最大（猎杀最激进，稳守最保守），风格差异是主要变量。

   各风格在同一等级内保留原有倾向比例（猎杀仍高 `immediateCaptureWeight`，稳守仍高 `libertyWeight`）。

3. 将基因表以常量 Map 的形式内嵌于代码（`_rankGeneTable`），方便后续通过 Arena 测试结果迭代调整。

### Phase C — Arena 离线校准工具

1. 新增 `CaptureAiCalibrator`（`lib/game/capture_ai_calibrator.dart`），封装以下流程：
   - 枚举所有 `CaptureAiStyle × AiRankLevel` 组合，共 4 × 28 = 112 个机器人。
   - 以 `CaptureAiArena.runRoundRobin` 进行全量对战（每对 200 局，可配置）。
   - 汇总每个机器人的对战 Elo（使用现有 `_calculateElo` 逻辑）。
   - 输出一份机器人 Elo 排行表（JSON），同时输出"等级 Elo 均值"表（每个 rank 对应 4 个风格的 Elo 均值）。
   - 自动验证：相邻等级 Elo 均值是否单调递增（若不满足，报警提示调整基因参数）。

2. 将校准结果作为编译期常量 `kAiEloTable`（`Map<String, double>`，key 为 `"${style.name}_r${rank}"`）写入 `capture_ai.dart`，供运行时动态匹配使用。另提供按 rank 聚合的 `kRankEloRange`（Map<int, (double min, double max)>）。

3. 校准工具只在开发环境（`kDebugMode` 或独立 Dart 脚本）下运行，不打包进 release。

### Phase D — 道场晋级制（取代 Elo 估算）

> **设计思路**：玩家水平不通过 Elo 公式反推，而是像围棋道场升降班一样，用"最近 3 局 2 胜/2 负"规则直接升降机器人等级。28 个机器人即 28 个"班级"，玩家通过连续胜利逐级升班，连续失败降班。机制直观、对 K12 用户友好，升级感强。

#### D1 — 玩家等级状态持久化

1. 新增 `PlayerRankState`（`lib/models/player_rank_state.dart`）：
   - `currentRank`（int，1–28，默认值 3）：玩家当前对战的机器人等级。新用户从 rank 3 出发，先赢几局再晋级，建立信心。
   - `recentResults`（`List<bool>`，最多保留最近 10 局胜负）：每次游戏结束后追加。

2. 在 `GameHistoryRepository`（或新增 `PlayerRankRepository`）中持久化 `PlayerRankState`，存储在 SharedPreferences（key: `'player_rank_v1'`）。

#### D2 — 晋级/降级规则（"3 局 2 胜/2 负"判定）

每局结束后执行以下判定：

```
取最近 3 局结果（不足 3 局时只取已有局数）：
  若胜局数 >= 2  →  currentRank = min(currentRank + 1, 28)  // 晋级
  若负局数 >= 2  →  currentRank = max(currentRank - 1, 1)   // 降级
  否则           →  保持不变
```

**注意事项**：
- 判定窗口严格取"最近 3 局"（含本局），不跨等级累计（升级后 recentResults 清空，重新计数）。
- rank 1 不再降级；rank 28 不再晋级。
- 连续晋级/降级不做限制（玩家快速进步时应快速提升，避免卡关感）。

#### D3 — 机器人选取

1. 新建游戏时，直接以 `PlayerRankState.currentRank` 对应的机器人作为对手，无需概率抽取。
2. 若玩家指定风格（`CaptureAiStyle`），则在该风格 × `currentRank` 的机器人上选取；若风格不限，随机选 4 种风格之一。
3. 在 `GameRecord` 中记录本局使用的 `aiRank`（int）和 `aiStyleName`（String）。

#### D4 — GameRecord 扩展

在 `GameRecord`（`lib/models/game_record.dart`）中增加：
- `aiStyleName`（对战 AI 风格，String，可为 null 兼容旧记录）
- `aiRank`（对战 AI 等级，int 1–28，可为 null 兼容旧记录）

旧记录读取时 `aiRank` 为 null，不参与晋降判定。

#### D5 — 与 Elo 系统的关系

- Phase C 的 `kAiEloTable` 仍然存在，供开发者了解各机器人相对棋力；
- **运行时不再使用 Elo 驱动对手选择**，改由道场晋级制驱动；
- Elo 作为"棋力参考"展示在开发者工具 / 调试界面，不向用户暴露。

### Phase E — 落子延迟（UX）

1. 在 `CaptureGameProvider._doAiMove()` 中，将 AI 计算与实际落子分离：
   - 记录计算开始时间戳。
   - 计算完成后，若已用时 < `minMoveDelay`（建议 800 ms），用 `Future.delayed` 补足剩余等待。
   - 设置 `maxMoveDelay`（建议 2500 ms）作为上限，超时后直接落子（避免复杂局面过长等待）。
   - `isAiThinking` 标志保持为 true，直到延迟结束后落子，UI 可渲染思考动画。

2. `minMoveDelay` 和 `maxMoveDelay` 作为 `CaptureGameProvider` 的可选构造参数，默认值来自常量，方便测试时设为 0。

3. 延迟范围与等级无关（保持统一节奏），但高等级机器人因 `playouts` 更多，实际计算时间本身已趋近 `minMoveDelay`，无需特殊处理。

### Phase F — 向后兼容与迁移

1. 保留 `DifficultyLevel` 枚举作为外部接口（settings、URL params），内部映射到 `AiRankLevel`：
   - `beginner` → rank 3（探索区中段）
   - `intermediate` → rank 12（进阶区中段）
   - `advanced` → rank 20（挑战区中段）

2. 现有 `CaptureAiRegistry.create(style, difficulty)` 保持签名不变，内部根据新的 `_rankGeneTable` 路由。

3. 所有现有测试保持通过；`minMoveDelay` 在测试中默认 `Duration.zero`。

---

## 5. Acceptance Criteria

### 等级体系
- 28 个等级档位（rank 1–28）已定义，覆盖两大区间（探索/进阶/挑战/精英）。
- `AiRankLevel.zone` 属性正确返回对应区间枚举值。
- 面向用户的展示名称文案已确定（另行设计，不阻塞本 plan）。

### 犯傻衰减
- rank 1–8 的 `captureBlindRate` 按指数衰减，`AiBlunderProfile.forLevel(8).captureBlindRate < 0.20`。
- rank 9 及以上三个盲区率严格为 0（单元测试断言）。
- rank 1 机器人在 9 路棋盘 200 局测试中，实际漏提触发次数占比 ≥ 30%。

### 等级校准
- 112 个机器人完成 round-robin 对战后，各 rank 的 Elo 均值单调递增（相邻档位 Elo 均值差 ≥ 40 点）。
- `kAiEloTable` 常量已提交，可供运行时查询。
- rank 28 机器人对 rank 1 机器人胜率 ≥ 90%；rank 14 对 rank 1 胜率 ≥ 70%。

### 道场晋级制（取代 Elo 估算）
- 新建游戏时，系统以 `PlayerRankState.currentRank` 直接决定对战机器人，无需概率抽取。
- 每局结束后正确执行"最近 3 局 2 胜晋级 / 2 负降级"判定，判定结果持久化到 SharedPreferences。
- 晋级后 recentResults 清空，不跨等级累计。
- 新用户首局从 rank 3 出发，rank 上限 28，下限 1。
- `GameRecord.aiRank` 和 `GameRecord.aiStyleName` 正确记录，旧记录 null 兼容不崩溃。
- 在 100 局模拟测试中：固定胜率 ≥ 80% 的玩家最终稳定在 rank ≥ 22；固定胜率 ≤ 30% 的玩家稳定在 rank ≤ 5。

### 落子延迟
- AI 落子等待时间在 `[minMoveDelay, maxMoveDelay]` 区间内（800 ms–2500 ms）。
- `isAiThinking` 在延迟期间保持 `true`，UI 思考指示器正常显示。
- 测试环境下将两个延迟参数设为 `Duration.zero`，所有现有测试通过。

### 回归
- `flutter analyze --no-fatal-infos --no-fatal-warnings` 通过。
- `flutter test` 全部通过，无测试被删除或跳过。
