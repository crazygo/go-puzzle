# 首页 3D 棋盘场景实现分析（与当前代码一致）

> 文档目的：准确描述当前代码如何构建 3D 棋盘背景、各模块职责、视觉策略与已知边界，供工程评审使用。

## 1. 场景在页面中的挂载策略

首页（`capture_game_screen`）把 3D 棋盘作为视觉背景层放进 `Stack`：

- 通过 `Positioned` 固定在页面上半区；
- 使用 `IgnorePointer`，确保不拦截任何交互；
- `Transform.translate` 做整体 Y 偏移，方便对齐卡片遮挡关系；
- 传入固定 `boardSize: 19`、示例落子 `kGoThreeDemoStones`，以及镜头/叶影/光摆动参数。

这意味着：**3D 棋盘是“首页氛围背景”，不是交互棋盘控件**。交互逻辑在上层 UI 卡片中完成。  

## 2. `GoThreeBoardBackground` 的生命周期与容错

组件为 `StatefulWidget`，内部持有：

- `three.ThreeJS` 渲染实例；
- 一个根组 `_root`；
- 独立的棋子组、粒子组、叶影组。

容错策略：

- 在 `initState` 临时接管 `FlutterError.onError`；
- 若初始化早期遇到 `MissingPluginException`（如无 OpenGL 插件环境），切换 `_pluginUnavailable = true`，回退成空 `SizedBox.expand()`，避免页面崩溃；
- 成功初始化后恢复原错误处理器。

## 3. 渲染器与相机策略

### 3.1 渲染器设置

当前 `three.Settings` 关键值：

- `alpha: true`、`clearAlpha: 0`：允许透明背景；
- `antialias: true`：边缘抗锯齿；
- `toneMappingExposure: 1.02`：比旧方案更高的曝光，提升高光可见度。

### 3.2 相机与动态机位

- 相机使用 `PerspectiveCamera`；`cinematicFrame=true` 时 FOV 为 `24`（更“摄影”），否则 `28`；
- `_setCamera()` 采用 `drift/lift` 正弦扰动，使镜头有缓慢漂移；
- `sceneScale` 通过“目标点与机位的相对距离缩放”实现推拉；
- `cameraLift/cameraDepth/targetZOffset` 作为外部可调参数。

结论：机位是**可呼吸的斜视透视镜头**，不是静态俯视。

## 4. 场景构建顺序（`_setup`）

初始化顺序固定为：

1. 创建 `Scene`；
2. 创建并定位 `_root`；
3. 创建相机并设定初始机位；
4. 构建灯光；
5. 构建棋盘主体；
6. 构建侧面木纹细节；
7. 构建 19 路网格（或传入尺寸）；
8. 构建顶面木纹细节；
9. 构建叶影系统；
10. 构建粒子层；
11. 构建棋子；
12. 注册逐帧动画（镜头、叶影、粒子、主光轻摆）。

该顺序体现“先结构、后细节、最后动态”的组织策略。

## 5. 光照系统（当前实现）

当前采用四灯组合：

1. **AmbientLight**：`0xffead2`, `0.24`（暖色底光）；
2. **Directional Key**：`0xffdcb2`, `1.28`，开启 `castShadow=true`，负责主明暗方向；
3. **Directional Fill**：`0xf6ecdf`, `0.30`，抬暗部但保留体积；
4. **Spot Sheen**：`0xffdfb5`, `0.34`，用于棋盘上方柔性高光增强。

动画阶段会对主光位置和强度做低频脉动，实现轻微“自然光呼吸感”。

## 6. 棋盘几何与材质策略

### 6.1 几何拼装

棋盘由代码拼接（非外部模型）：

- 两个交叉 Box + 四角 Cylinder 形成厚板主体与圆角；
- 顶面再叠薄层形成“面皮”；
- 前缘保留 `frontGlow` 做暖色边缘光；
- 新增 `topSpecularLayer`（薄 Box + Phong），专门强化顶面镜面带。

### 6.2 材质分层

- 侧面：`MeshStandardMaterial(color 0x9f6933, roughness 0.56)`；
- 顶面：`MeshStandardMaterial(color 0xdeb47b, roughness 0.24)`；
- 顶面高光层：`MeshPhongMaterial(opacity 0.20, shininess 90)`。

策略含义：

- 主体维持木材非金属属性（`metalness=0`）；
- 通过“低粗糙度顶面 + 独立高光层”提升可读高光，而不让整体变成塑料感。

## 7. 网格与木纹细节（从“贴线”到“受光细节”）

### 7.1 网格

网格并非单层线条，而是三层叠加：

- 主线（line）；
- 暗槽（groove shadow）；
- 亮槽（groove highlight）。

且这三层都使用 `MeshStandardMaterial`（可受光），相比纯 `MeshBasicMaterial` 更能随机位和光向变化。

### 7.2 顶面/侧面木纹

- 顶面与前侧木纹由大量细 `CylinderGeometry` 程序化分布；
- 材质为半透明 `MeshStandardMaterial`，参与光照；
- 每条纹理具备随机长度、位置和旋转，避免完全规则重复。

这仍是程序化近似，不是高精度贴图木纹，但已从“纯平面贴线”升级为“可受光 3D 微结构”。

## 8. 叶影系统（Caustics）

当前叶影不是单圆片，而是“簇状 patch”结构：

- 每个 blob 由一个核心 mesh + 一个半影 mesh 组成；
- 在其局部坐标下再叠加 4 组小圆 patch，形成不规则轮廓；
- 全局组做平移/旋转漂移，局部 blob 也做相位偏移，避免机械同步。

结果：右上光影仍是程序化模拟，但圆形模板感显著降低。

## 9. 棋子与接触阴影

每颗棋子由四层构成：

1. 主接触阴影（深色薄圆柱，较集中）；
2. 软接触阴影（更大更淡的薄圆柱）；
3. 棋子本体（高分段 `SphereGeometry`，Y 压扁）；
4. 高光帽层（小球 Phong 透明层）。

材质：

- 黑子：`MeshPhysicalMaterial(roughness 0.12)`；
- 白子：`MeshPhysicalMaterial(roughness 0.20)`。

策略：

- 通过 Physical 材质提升高光响应；
- 通过双层假接触阴影增强“贴桌感”；
- 高光帽层保证黑白子都能读到明确亮斑。

## 10. 动画与可调参数

逐帧动画（`addAnimationEvent`）包含：

- 相机漂移（若 `animate=true`）；
- 叶影组平移/旋转与局部 blob 位移；
- 粒子组缓慢旋转与上下浮动（`particles=true`）；
- 主光小幅摆动（受 `keyLightSwing` 影响）。

对外暴露的关键调参：

- `sceneScale / cameraLift / cameraDepth / targetZOffset`（镜头构图）；
- `leafShadowOpacity / leafShadowSpeed / leafShadowSway`（叶影观感）；
- `keyLightSwing`（光摆动幅度）；
- `particles / animate / cinematicFrame`（效果开关）。

## 11. 当前方案能做什么、不能做什么（客观边界）

### 已覆盖

- 真实 3D 几何棋盘（含厚度、圆角、侧边）；
- 斜视透视镜头与动态机位；
- 受光网格/木纹细节；
- 棋子高光与接触阴影增强；
- 程序化叶影与暖色氛围光。

### 仍是近似

- 未接入 HDRI / envMap / IBL / AO / SSR 等完整摄影级反射管线；
- 木纹仍为程序化几何细节，不是高质量法线/粗糙度贴图；
- 接触阴影包含“假阴影层”，并非纯物理软阴影解。

结论：当前实现已是**真实 3D 场景表达 + 风格化写实增强**，明显强于旧版“偏平氛围层”；但若目标是完全摄影级 PBR，仍需引入环境贴图与后期链路。

## 12. 与评审沟通的建议口径

对外审查可使用以下一句话：

> 我们当前版本是“可实时运行的 3D 程序化棋盘场景”，通过 PBR/Phong 混合材质、四灯体系、双层接触阴影与簇状叶影实现高质感首页背景；其视觉策略和代码完全一致，且已保留向 HDRI/贴图化材质升级的扩展空间。
