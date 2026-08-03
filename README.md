# DatasetGen

DatasetGen 是一个基于 Godot 4.6 Mono 的合成数据集生成工具。项目用于在随机室内场景中摆放物体，渲染 RGB / 16-bit depth 图像，并输出目标检测标签。

主场景：`scenes/main.tscn`

## 功能概览

- 随机室内场景与桌面物体生成
- 三种生成方式：方桌、圆桌、悬浮物体
- 类别权重控制与模型浏览器
- RGB 图片保存与 16-bit 单通道 depth PNG 保存
- YOLO 风格标签输出
- bbox 可视化预览
- 遮挡检测与可见比例过滤
- 物体堆叠摆放
- 桌面扁平贴图干扰项
- 连续变化的相机畸变与白平衡扰动
- 响应式 GUI 缩放

## 环境要求

- Godot Mono `4.6`
- macOS 下默认 Godot 路径：

```bash
/Applications/Godot\ Mono\ 4.6.app/Contents/MacOS/Godot
```

- Git LFS。`models/` 和 `prefabs/` 已配置为 LFS：

```bash
git lfs install
git lfs pull
```

## 运行项目

打开项目：

```bash
/Applications/Godot\ Mono\ 4.6.app/Contents/MacOS/Godot --path .
```

运行 headless 加载检查：

```bash
/Applications/Godot\ Mono\ 4.6.app/Contents/MacOS/Godot --headless --log-file /tmp/datasetgen-godot-headless.log --path . --quit
```

使用 `--log-file /tmp/...` 可以避免 Godot 在沙箱环境中写入 `user://logs` 被拦截。

## 使用流程

1. 打开项目并运行 `scenes/main.tscn`。
2. 在右侧 Settings 页选择 `Output Dir...`。
3. 选择 `Generation Mode`：`Square Table`、`Disc Table` 或 `Floating`。
4. 设置物体数量、保存间隔、是否保存 depth、是否显示 bbox。
5. 在 Categories 页勾选类别并调整权重。
6. 点击 `Start` 开始生成；打开 `Enable Saving (live)` 后按间隔写入数据。
7. 点击 `Stop` 停止，会复位运行状态。
8. 点击 `Save Config` 可保存 GUI 配置到 `user://gui_config.cfg`。

## 输出结构

每次运行保存会创建一个时间戳目录：

```text
<output_dir>/
  YYYYMMDD_HHMMSS/
    images/
      000000.jpg
      000001.jpg
    images_depth/
      000000.png
      000001.png
    labels/
      000000.txt
      000001.txt
    classes.txt
```

- RGB 图片为 JPEG，默认质量较低，用于模拟真实照片压缩痕迹。
- depth 图片为标准 16-bit grayscale PNG，像素值单位为毫米。
- 标签为 YOLO 风格：`class center_x center_y width height`，坐标归一化到 viewport 尺寸。
- `Unknown` 类别不会写入 `classes.txt`，标签生成也会跳过 Unknown class id。

## GUI 参数说明

### Data Capture Control

- `Output Dir`：数据集输出目录。
- `Generation Mode`：
  - `Square Table`：方桌场景。
  - `Disc Table`：圆桌场景。
  - `Floating`：隐藏桌子，物体悬浮摆放，不使用物理下落。
- `Item Count`：每次重摆物体数量范围。
- `Enable Table Distractors`：是否生成桌面扁平贴图干扰项，Floating 模式下自动关闭。
- `Distractor Count`：桌面干扰项数量范围。
- `Save Interval`：每隔多少帧保存一次。

### Runtime Toggles

- `Enable Saving (live)`：运行中实时开启/关闭写盘。
- `Save Depth`：保存 16-bit depth PNG。
- `Show BBox Preview`：显示左侧 bbox 预览。
- `Enable Rotate Light`：启用旋转补光。

### Label Filtering

- `Visibility Threshold`：可见点比例阈值，低于此值的物体不输出标签。
- `Sample Mode`：
  - `Grid`：网格采样。
  - `Bounds Key Points`：边界关键点采样。
  - `Hybrid`：混合采样。
- `Grid Samples`：Grid / Hybrid 模式使用的采样密度。
- `Drop Threshold`：桌面模式下，物体底部低于桌面顶面超过该阈值会被认为掉落并移除。
- `Debug Occlusion Logs`：打印遮挡检测日志。

### Camera Motion

- `Rotation Speed`：相机绕目标旋转速度，单位为度/秒。
- `Motion Transition`：随机相机参数过渡时间。
- `Camera Distance`：相机到目标水平距离范围。
- `Camera Height`：相机高度范围。
- `Offset X/Y/Z`：相机视角偏移范围。

### Camera Perturbation

- `Enable Camera Perturbation`：启用相机图像扰动。
- `Change Time`：扰动参数变化时间范围。
- `Enable Lens Distortion`：启用镜头畸变。
- `Distortion Δ`：畸变强度变化范围。
- `Enable White Balance`：启用白平衡扰动。
- `Warm/Cool`：冷暖色偏范围。
- `Green/Magenta`：绿/品红色偏范围。

### Categories

- `Open Model Browser`：打开模型浏览器。
- 类别勾选框：控制是否参与随机生成。
- 权重：控制类别被采样的相对概率。

模型浏览器读取 `resources/object_catalog.tres`，不会自动扫描 `prefabs/`。

## 项目结构

```text
addons/        Godot 插件
hdri/          环境 HDR 贴图
models/        源模型和纹理，走 Git LFS
prefabs/       可实例化物体和桌子场景，走 Git LFS
resources/     ObjectCatalog 等资源配置
scenes/        主场景和生成场景
scripts/       GDScript 源码
shaders/       depth、预览、增强等 shader
themes/        全局 UI 主题
tools/         维护脚本
```

脚本目录：

```text
scripts/capture/      图像采集、标签生成、depth 写入
scripts/config/       ObjectCatalog / ObjectCategory
scripts/depth/        depth viewport 和 16-bit PNG 编码
scripts/environment/  相机、随机摆放、桌子、干扰项、相机增强
scripts/ui/           GUI、响应式缩放、模型浏览器
```

## 添加模型

1. 将源模型和贴图放到 `models/<category>/`。
2. 创建或更新 prefab 场景到 `prefabs/<category>/`。
3. 在 `resources/object_catalog.tres` 中加入对应 prefab。
4. 检查类别字段：
   - `display_name`
   - `key`
   - `label_name`
   - `class_id`
   - `is_unknown`
   - `enabled`
   - `weight`
   - `scenes`
5. 运行 headless 检查。

Unknown 类别使用 `is_unknown = true`。普通有标签数据集生成时不建议启用 Unknown 类别，因为标签生成会跳过 Unknown class id。

## 深度图说明

depth 渲染使用独立 `SubViewport` 和全屏 quad shader：

- `shaders/depth.gdshader` 从 `DEPTH_TEXTURE` 读取 reversed-Z depth。
- 使用 `INV_PROJECTION_MATRIX` 还原线性视图深度。
- 转成毫米后拆成高/低字节写入 R/G 通道。
- `scripts/capture/capture_writer.gd` 读取 R/G 并还原为 uint16。
- `scripts/depth/depth_png16.gd` 手写标准 PNG 容器，输出 16-bit grayscale PNG。

GUI 中 depth preview 只用于显示，不影响保存数据。

## Git 与资源规则

- `*.uid` 必须提交。
- `*.import` 必须提交。
- `.godot/`、`.import/` 目录不提交。
- `models/` 和 `prefabs/` 通过 Git LFS 管理。
- `.trae/`、`.agents/`、`.claude/`、`.cursor/` 等 agent 本地状态不提交。
- `AGENTS.md` 本身需要提交。

## 常用检查

```bash
git status --short
git ls-files -ci --exclude-standard
/Applications/Godot\ Mono\ 4.6.app/Contents/MacOS/Godot --headless --log-file /tmp/datasetgen-godot-headless.log --path . --quit
```

`git ls-files -ci --exclude-standard` 通常应该为空。若输出源码或资源文件，说明 `.gitignore` 规则过宽。
