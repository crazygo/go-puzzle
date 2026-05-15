# 围棋截图 YOLO 识别训练与迭代手册

本文记录本项目当前的离线 YOLO 训练流程。目标读者是以后继续加样本、复训模型、导出模型、接入 iOS/Web 的开发者。

核心原则：先把模型方案放在 `tool/yolo/` 里离线验证，暂时保留 Dart 规则识别算法作为生产默认路径和回退路径。只有当完整截图到棋盘文本的指标稳定优于规则算法，才值得继续承担 iOS/Web 端模型加载、ONNX 推理、包体大小和故障恢复的复杂度。

## 为什么不直接替换规则算法

当前项目已经有 Dart 规则识别器，输入截图后输出现有棋盘文本格式，例如：

```text
Size 9
B,D8
W,C7
```

规则算法的优点是轻、离线、可解释、运行时已经接入产品；缺点是在真实截图上失败模式明显，例如 9 路棋盘误判为 19 路、整盘识别成白子、或者漏掉大量棋子。

YOLO 方案不是为了看 mAP 好不好，而是为了回答一个产品问题：用户截图能不能稳定变成同一份棋盘文本格式。离线阶段保留规则算法有三个实际好处：

- 生产路径不被实验影响，模型失败时还有可用回退。
- 规则算法可以作为 baseline，后续每次模型迭代都有明确对照。
- iOS/Web 的 ONNX、模型下载、包体大小和加载 UI 都可以等准确率达标后再做。

## 数据来源

人工标注源数据放在：

```bash
test/assets/recognition_samples/
```

每个样本应成组出现：

```text
<sample>.PNG 或 <sample>.png
<sample>.txt
<sample>.json
```

其中：

- `.PNG/.png` 是原始截图。
- `.txt` 是棋盘真值，第一行是 `Size 9/13/19`，后续每行是 `B,D8` 这种已有文本格式。
- `.json` 是 `tool/recognition_labeler.html` 保存的几何标注，包含图片尺寸、棋盘路数、四角坐标、棋子行列和颜色。

`.txt` 是业务真值，`.json` 是训练几何真值。后续不要手写 YOLO label；应该继续维护这两份人工可读标注，然后用转换脚本生成 YOLO 数据集。

当前固定 split：

```text
train: 31 samples
val:    8 samples
```

对应文件：

```bash
tool/yolo/splits/train.txt
tool/yolo/splits/val.txt
```

验证集目前包含这些样本：

```text
IMG_2720
IMG_2737
IMG_2828
IMG_2838
IMG_3078
IMG_3157
IMG_3830
IMG_4778
```

固定 split 很重要。不要为了让一次训练数字好看就随手换验证集；新增样本后应该明确记录为什么重排 split。

## 生成 YOLO 数据集

所有生成物都放在 `.cache/yolo/`，不要提交到 Git：

```text
.cache/yolo/
  venv/
  dataset/
  board_pose_dataset/
  runs/
```

棋子 detect 数据集由 `.txt + .json` 生成：

```bash
python tool/yolo/convert_recognition_samples.py \
  --samples test/assets/recognition_samples \
  --splits tool/yolo/splits \
  --out .cache/yolo/dataset
```

生成结果是 Ultralytics YOLO detect 格式：

- `images/train`, `images/val`
- `labels/train`, `labels/val`
- `data.yaml`
- class `0 = black_stone`
- class `1 = white_stone`

棋盘四角 pose 数据集由 `.json` 生成：

```bash
python tool/yolo/convert_board_pose_samples.py \
  --samples test/assets/recognition_samples \
  --splits tool/yolo/splits \
  --out .cache/yolo/board_pose_dataset
```

生成结果是 YOLO pose 格式：

- class `0 = board_9`
- class `1 = board_13`
- class `2 = board_19`
- keypoints 顺序：`topLeft`, `topRight`, `bottomRight`, `bottomLeft`

## 两个模型的分工

当前不是训练一个“大而全”的模型，而是拆成两个小模型：

- **棋盘四角/路数 pose 模型**：输入截图，输出棋盘路数和四个角点。当前优先使用 `.cache/yolo/runs/go_board_pose_yolov8n_640_b2_rebalanced/weights/best.pt`。
- **黑白棋 detect 模型**：输入截图，输出黑子/白子的检测框。当前优先使用 `.cache/yolo/runs/go_stones_yolov8n_640_b2/weights/best.pt`。

完整流程是：

1. pose 模型找到棋盘路数和四角。
2. `board_grid_refiner.py` 把粗略四角吸附到可见网格线，修正 YOLO pose 的像素级偏差。
3. detect 模型找黑白棋检测框。
4. 用棋子框中心点映射到最近棋盘交叉点。
5. 输出和规则算法相同的棋盘文本/矩阵。

这个拆法的好处是问题更容易定位：如果路数错或四角偏，先看 pose；如果棋盘对但漏子/错色，先看 detect 或后处理阈值。

## 环境安装

首次使用：

```bash
python3 -m venv .cache/yolo/venv
source .cache/yolo/venv/bin/activate
pip install -r tool/yolo/requirements.txt
```

也可以用封装脚本：

```bash
python3 tool/yolo/run_experiment.py check
python3 tool/yolo/run_experiment.py install
```

如果 `pip install` 拉取 `torch`/Ultralytics 相关 wheel 时出现 hash mismatch、下载中断或缓存损坏，优先处理环境，不要改训练代码：

```bash
.cache/yolo/venv/bin/python -m pip cache purge
.cache/yolo/venv/bin/python -m pip install --no-cache-dir -r tool/yolo/requirements.txt
```

如果只是网络不稳定，直接重跑 install 通常也能恢复。不要把本机临时下载出来的 wheel 或 venv 提交进仓库。

## 训练命令

推荐先用封装脚本，避免记错参数。

检查环境和数据集：

```bash
python3 tool/yolo/run_experiment.py check
```

生成 detect 数据集：

```bash
python3 tool/yolo/run_experiment.py convert
```

生成 pose 数据集：

```bash
python3 tool/yolo/run_experiment.py convert-board-pose
```

棋子 detect 冒烟训练：

```bash
python3 tool/yolo/run_experiment.py smoke
```

棋盘 pose 冒烟训练：

```bash
python3 tool/yolo/run_experiment.py board-pose-smoke
```

棋子 detect 主训练：

```bash
python3 tool/yolo/run_experiment.py main
```

当前主训练参数来自 `run_experiment.py`：

```text
model=yolov8n.pt
epochs=100
patience=30
imgsz=640
batch=2
name=go_stones_yolov8n_640_b2
```

棋盘 pose 主训练：

```bash
python3 tool/yolo/run_experiment.py board-pose-main
```

当前主训练参数：

```text
model=yolov8n-pose.pt
epochs=150
patience=50
imgsz=640
batch=2
name=go_board_pose_yolov8n_640_b2
```

棋盘 pose 调参训练：

```bash
python3 tool/yolo/run_experiment.py board-pose-tuned
```

这个版本关闭了对棋盘四角不友好的增强：

```text
mosaic=0
fliplr=0
erasing=0
translate=0.03
scale=0.15
hsv_s=0.25
hsv_v=0.20
```

棋盘 pose 重排 split 训练：

```bash
python3 tool/yolo/run_experiment.py board-pose-rebalanced
```

当前完整评估优先选这个 pose 权重。

## 中断恢复

训练中断后不要重新开一个新名字乱跑，先从 `last.pt` 恢复：

```bash
python3 tool/yolo/run_experiment.py resume-smoke
python3 tool/yolo/run_experiment.py resume-main
python3 tool/yolo/run_experiment.py resume-board-pose-smoke
python3 tool/yolo/run_experiment.py resume-board-pose-main
python3 tool/yolo/run_experiment.py resume-board-pose-tuned
python3 tool/yolo/run_experiment.py resume-board-pose-rebalanced
```

底层等价于：

```bash
yolo detect train model=.cache/yolo/runs/go_stones_yolov8n_640_b2/weights/last.pt resume=True
yolo pose train model=.cache/yolo/runs/go_board_pose_yolov8n_640_b2_rebalanced/weights/last.pt resume=True
```

恢复前先确认 `last.pt` 存在：

```bash
python3 tool/yolo/run_experiment.py results
```

## 评估命令

只评估棋子 detect，并使用人工 `.json` 棋盘几何：

```bash
python3 tool/yolo/run_experiment.py eval-stones
```

只评估棋盘 pose：

```bash
python3 tool/yolo/run_experiment.py eval-board-pose
```

评估完整模型流程，全量 39 张样本，并附带规则 baseline：

```bash
python3 tool/yolo/run_experiment.py eval-full
```

只评估固定验证集：

```bash
python3 tool/yolo/run_experiment.py eval-full-val
```

识别单张截图：

```bash
.cache/yolo/venv/bin/python tool/yolo/recognize_screenshot.py \
  test/assets/recognition_samples/IMG_4778.PNG
```

需要角点和文本 JSON 时加：

```bash
--json
```

## 当前指标

以下数字来自 2026-05-15 在当前工作区执行 `python3 tool/yolo/run_experiment.py eval-full` 的输出。

规则 baseline，全量 39 张：

```text
points 2447/3879 (63.1%)
stones correct=390 expected=773 predicted=1127 precision=34.6% recall=50.5%
exact samples 16/39
failed samples: IMG_2720, IMG_2728, IMG_2729, IMG_2730, IMG_2737, IMG_2742, IMG_2743, IMG_2744, IMG_2745, IMG_2752, IMG_2799, IMG_2800, IMG_2801, IMG_2802, IMG_2803, IMG_2828, IMG_2829, IMG_2830, IMG_2872, IMG_3078, IMG_3157, IMG_3830, IMG_4778
```

模型完整流程，全量 39 张：

```text
board pose model: .cache/yolo/runs/go_board_pose_yolov8n_640_b2_rebalanced/weights/best.pt
stone model: .cache/yolo/runs/go_stones_yolov8n_640_b2/weights/best.pt

points 3878/3879 (100.0%)
stones correct=772 expected=773 predicted=773 precision=99.9% recall=99.9%
board size accuracy 39/39 (100.0%)
exact samples 38/39
failed samples: IMG_2830
```

`IMG_2830` 的失败是一个错色点：

```text
size expected=9 predicted=9
points 80/81 (98.8%)
stones correct=5 expected=6 predicted=6 precision=83.3% recall=83.3%
E2 expected=B predicted=W
```

固定验证集 8 张当前模型全对：

```text
points 824/824 (100.0%)
stones correct=299 expected=299 predicted=299 precision=100.0% recall=100.0%
board size accuracy 8/8 (100.0%)
exact samples 8/8
```

这些数字说明模型路线已经显著优于规则算法，但还不能把问题视为结束：样本只有 39 张，且全量里仍有 `IMG_2830` 错色。以后新增更复杂截图后，指标可能下降。

## 已遇到的问题和处理办法

### pip/torch 下载 hash 或缓存问题

现象：安装 Ultralytics 时拉取 `torch` 等大 wheel，网络中断、缓存损坏或镜像内容变化导致 hash mismatch/download error。

处理：

```bash
.cache/yolo/venv/bin/python -m pip cache purge
.cache/yolo/venv/bin/python -m pip install --no-cache-dir -r tool/yolo/requirements.txt
```

如果公司/地区网络不稳定，换稳定网络或官方源后重跑。不要把临时 wheel、venv 或 `.cache/yolo/` 产物提交。

### 训练中断

现象：长时间 CPU 训练被终端关闭、电源睡眠或进程中断。

处理：优先用 `resume-*` 从 `last.pt` 继续，不要直接删除旧 run。`best.pt` 是当前最佳，`last.pt` 是恢复点。

### NumPy 2 兼容

`evaluate_full_pipeline.py` 和 `board_grid_refiner.py` 都使用 NumPy。一般纯 Python 代码没问题，但部分编译型依赖可能会因为 NumPy 2 ABI 报错。

处理顺序：

1. 先升级相关包：`pip install -U ultralytics Pillow PyYAML`。
2. 如果报错明确指向 NumPy ABI，再在本地 venv 临时 pin：`pip install "numpy<2"`。
3. 如果要把 pin 固化进 `tool/yolo/requirements.txt`，必须重新跑 `eval-full`，确认不是只修了本机环境。

### 少样本

当前只有 39 张样本，验证集只有 8 张。`eval-full` 结果很好，但这不等于模型泛化已经充分验证。

处理：

- 每次真实用户截图失败，都优先转成新样本。
- 新样本要覆盖不同设备、缩放、主题、棋盘大小、棋子密度、边缘裁切和 UI 背景。
- 不要只加容易样本；失败样本比成功样本更有训练价值。

### 棋盘边界不明显

截图中棋盘边缘有时和背景接近，YOLO pose 能找到大概区域，但四角像素不够准。仅靠 pose keypoint 直接映射棋子，会让交叉点偏移。

处理：保留 `board_grid_refiner.py`。它用可见网格线的周期性做二次吸附，当前完整流程默认启用。只有排查 pose 原始质量时才用 `--no-refine-board` 或 `--no-refine`。

### 需要 grid refine

模型输出的四角是“粗定位”，产品需要的是“棋子映射到哪一个交叉点”。这两个精度要求不同。即使 pose mAP 看起来好，也可能因为半格偏差导致棋子落到相邻点。

处理：

- 评估时看 `eval-full` 的棋盘文本指标，不只看训练日志。
- 如果四角偏差导致大量错点，先调 refine 或 pose split/增强。
- 如果只有个别错色/漏子，优先看 detect 阈值、颜色分类和样本覆盖。

### Web/iOS 模型大小与 ONNX 导出

当前本地 `.pt` 权重大小大致是：

```text
board pose best.pt: about 6.1M
stone detect best.pt: about 23M
```

`.pt` 不是 Flutter Web/iOS 的最终运行格式。后续接运行时时，需要导出 ONNX，再评估包体和加载体验：

```bash
.cache/yolo/venv/bin/yolo export \
  model=.cache/yolo/runs/go_board_pose_yolov8n_640_b2_rebalanced/weights/best.pt \
  format=onnx \
  imgsz=640 \
  simplify=True

.cache/yolo/venv/bin/yolo export \
  model=.cache/yolo/runs/go_stones_yolov8n_640_b2/weights/best.pt \
  format=onnx \
  imgsz=640 \
  simplify=True
```

iOS 倾向把 ONNX 资源打进 app bundle；Web 倾向从 GitHub Release URL 下载模型。无论哪种方式，都要保留规则算法作为默认和 fallback，因为模型加载可能失败或变慢。

## 以后新增样本怎么做

1. 把原始截图放入 `test/assets/recognition_samples/`。
2. 用 `tool/recognition_labeler.html` 标注棋盘四角、路数和棋子。
3. 导出同名 `.txt` 和 `.json`，确保三件套齐全。
4. 跑几何校验：

```bash
dart run tool/validate_recognition_geometry.dart
```

5. 运行规则 baseline，记录这个样本是不是规则算法失败样本：

```bash
dart run tool/recognition_accuracy_report.dart
```

6. 更新 `tool/yolo/splits/train.txt` 和 `tool/yolo/splits/val.txt`。

split 原则：

- hard case 要放一部分在 val，不能全放 train。
- 新设备/新棋盘尺寸/新失败类型，至少留代表样本在 val。
- 如果新增样本很多，可以重排 split，但要在 PR 或文档里说明重排原因。

## 重新训练建议流程

完整迭代建议按这个顺序跑：

```bash
python3 tool/yolo/run_experiment.py check
python3 tool/yolo/run_experiment.py convert
python3 tool/yolo/run_experiment.py convert-board-pose

python3 tool/yolo/run_experiment.py smoke
python3 tool/yolo/run_experiment.py board-pose-smoke
python3 tool/yolo/run_experiment.py eval-full-val

python3 tool/yolo/run_experiment.py main
python3 tool/yolo/run_experiment.py board-pose-rebalanced
python3 tool/yolo/run_experiment.py eval-full
```

冒烟训练的作用是确认数据格式、依赖、路径和训练入口可用；不要用 smoke 权重发布模型。主训练后，至少要保存：

- 使用的 train/val split。
- 使用的 detect run 名称和 `best.pt` 路径。
- 使用的 pose run 名称和 `best.pt` 路径。
- `eval-full` 输出。
- 是否出现新的失败样本。

当前离线准确率门槛来自计划文档：

```text
points accuracy >= 95%
stones precision >= 95%
stones recall >= 90%
exact samples >= 85%
board size accuracy >= 95%
```

如果 `eval-full` 低于门槛，不要发布模型。先补样本或调后处理。

## 发布模型前检查

发布或接入运行时前，至少完成这些检查：

```bash
python3 tool/yolo/run_experiment.py eval-full
python3 tool/yolo/recognize_screenshot.py test/assets/recognition_samples/IMG_4778.PNG
```

然后导出 ONNX，记录文件大小，并在目标运行时验证：

- iOS：模型是否随 app bundle 打包；冷启动加载是否可接受；加载失败是否能回退规则算法。
- Web：模型 URL 是否稳定；首次下载是否有明确 loading UI；离线/网络慢时是否能取消或回退。
- 输出格式：模型识别结果必须继续转换成现有 `Size` + `B/W,坐标` 文本格式和棋盘矩阵。
- fallback：模型失败不能阻断截图导入，规则算法仍然可用。

## 维护注意事项

- 不要提交 `.cache/yolo/`、venv、训练 run、临时权重。
- 不要只看 YOLO 训练日志，最终 gate 是 `eval-full` 的业务指标。
- 不要删除规则算法；它是生产默认路径、对照组和模型失败兜底。
- 不要把新增样本只塞进 train；验证集必须持续包含真实失败类型。
- 如果改了 `board_grid_refiner.py`、阈值、颜色判定或 split，必须重新跑 `eval-full` 并记录结果。
