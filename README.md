# 围棋谜题 (Go Puzzle)

一款基于 Flutter 的围棋解谜 iOS 应用，采用最新的 iOS 设计语言（Cupertino）。

---

## 功能特性

### 今日谜题
- 日期时间轴，每日一题
- 可交互的棋盘（支持落子、悔棋、提示）
- 显示落子进度、提子数量

### 技巧训练
分为三大类，每类 5 道以上练习题：

| 类别 | 说明 |
|------|------|
| **入门** | 基本吃子、边角利用 |
| **规则** | 禁入点、打劫基础、两眼活棋 |
| **断吃** | 切断联系后吃子 |
| **造劫** | 创造打劫局面 |
| **征子** | 连续叫吃追击 |
| **网** | 包围圈困住对方 |
| **双吃** | 同时叫吃两处 |

### 设置
- 棋盘大小：9路吃子 / 13路吃子 / 19路围空
- 游戏选项：提示显示、手数显示
- 反馈：音效、触感

---

## 技术架构

```
lib/
├── main.dart                    # 应用入口
├── models/
│   ├── board_position.dart      # 棋盘坐标和棋子颜色
│   ├── puzzle.dart              # 谜题数据模型
│   └── game_state.dart          # 对局状态
├── game/
│   ├── go_engine.dart           # 围棋规则引擎（气、提子、打劫、征子）
│   └── puzzle_validator.dart    # 谜题解答验证
├── data/
│   ├── daily_puzzles.dart       # 每日谜题数据
│   └── skill_puzzles.dart       # 技巧训练题库
├── providers/
│   ├── game_provider.dart       # 对局状态管理
│   └── settings_provider.dart   # 设置状态管理
├── screens/
│   ├── main_screen.dart         # 主屏幕（底部标签栏）
│   ├── daily_puzzle_screen.dart # 今日谜题
│   ├── skills_screen.dart       # 技巧训练
│   ├── settings_screen.dart     # 设置
│   └── puzzle_screen.dart       # 解题界面
└── widgets/
    ├── go_board_widget.dart     # 棋盘 Widget + CustomPainter
    ├── date_timeline.dart       # 日期时间轴
    └── puzzle_card.dart         # 题目卡片
```

### 核心技术
- **Flutter** + **Cupertino** — iOS 设计语言
- **Provider** — 状态管理
- **CustomPainter** — 棋盘渲染（带木纹背景、石子渐变、叫吃标记）
- **围棋规则**：气的计算、提子、打劫（Ko）规则、禁入点判断、悔棋

---

## 快速开始

```bash
# 依赖安装
flutter pub get

# 运行（iOS 模拟器或设备）
flutter run

# 运行测试
flutter test
```

### 构建目标平台

```bash
# Web（输出到 build/web/）
flutter config --enable-web
flutter build web --release --web-renderer html

# iOS（需要 macOS + Xcode 14+）
cd ios && pod install
flutter build ios --release --no-codesign
```

### 环境要求
- Flutter SDK ≥ 3.22.0
- Dart ≥ 3.0.0
- iOS 12+ / Android 6.0+
- Xcode 14+（iOS 构建）

---

## Vercel 部署

### 方式一：自动 CI/CD（推荐）

推送到 `main` 分支时，GitHub Actions 会自动构建 web 并部署到 Vercel。

1. 在 [Vercel 控制台](https://vercel.com) 导入此仓库
2. 在 GitHub 仓库 Settings → Secrets 中添加：
   - `VERCEL_TOKEN` — Vercel 账户 API token
   - `VERCEL_ORG_ID` — Vercel 团队/用户 ID
   - `VERCEL_PROJECT_ID` — Vercel 项目 ID
3. 推送代码即可触发自动构建部署

### 方式二：手动 Vercel 部署

```bash
# 安装 Vercel CLI
npm i -g vercel

# 构建 web
flutter build web --release --web-renderer html

# 部署
vercel build/web --prod
```

### 方式三：通过 Vercel 控制台直接构建

在 Vercel 控制台导入仓库后，框架设置选择 "Other"，构建命令和输出目录会通过 `vercel.json` 自动配置（运行 `vercel-build.sh` 安装 Flutter 并构建）。

---

## 题目数据格式

每道题由以下字段组成：

```dart
Puzzle(
  id: 'unique_id',
  title: '题目名称',
  description: '题目说明',
  boardSize: 9,                     // 9 / 13 / 19
  initialStones: [...],             // 初始棋子列表
  targetCaptures: [...],            // 需要吃掉的目标棋子坐标
  solutions: [[BoardPosition, ...]] // 正解路线（支持多解）
  category: PuzzleCategory.beginner,
  difficulty: PuzzleDifficulty.easy,
  hint: '提示文字',
)
```

---

## 参考资料
- 题目设计参考：[online-go.com/learn-to-play-go](https://online-go.com/learn-to-play-go)
- 围棋规则：[中国围棋规则](https://www.igofederation.org)
