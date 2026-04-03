---
name: generate-svs-mesh
description: 用于在全景系统 (SVS) 中从外参或单应性矩阵自动生成 OpenGL 适用的 .mesh 格式二进制文件，并可选地进行本地渲染测试。当用户要求“生成 mesh”、“构建俯视图网格”、或在“修改摄像头外参/参数矩阵后需更新拼接图”时，请必须自动触发此技能。
---

# Generate SVS Mesh Skill

你当前正在执行 `generate-svs-mesh` 技能。当用户要求基于一组标定参数生成车载全景 (BEV) 拼接的 Mesh 模型时，你应当严格按照以下标准工作流操作。

## 1. 明确输入要求并校验

你需要使用以下两个主要输入路径：
1. **`params_dir` (必需)**：包含四个方向相机的 YAML 参数文件的目录（如 `front.yaml` 或 `params.yaml`）。
2. **`images_dir` (非必需，但强烈建议)**：包含用于离线模拟测试拼接效果的四个摄像头的未去畸变原始拍摄画面（如 `front.png` 等）。

**动作指南：**
- **首先检查**：如果用户未在 Prompt 中明确指出这两个目录，你必须主动用自然语言询问用户：“请问存放相机参数文件 (params) 的目录在哪里？如果您有测试图片 (images)，也请告诉我路径，我可以在生成后为您渲染一张全景拼接验证图。”
- **只有当 `params_dir` 确定存在且包含 yaml 时，才能进行下一步**。

## 2. 识别模式类型与执行生成

本系统支持两种数学模型的拼接原理。你需要通过探查 `params_dir` 目录内的文件特征，自动判断属于哪种模式，并调用不同的计算脚本。

### 模式 A: 单应性矩阵模式 (Homography Mode) - 推荐
* **特征识别**：
  如果 `params_dir` 包含 `weights.png` 图像文件，或者对应的 yaml 内部含有 `project_matrix` 或 `scale_xy` 字段。
* **执行构建**：
  由于采用了单应性矩阵，请使用专门抽取的轻量化脚本来计算出 `200x266` 网格（代表 `1200x1600` 物理比例）的网格坐标系。
  请使用命令行执行脚本，工作目录建议切换到 `tools/stitching/`：
  ```bash
  python3  generate_mesh_homography.py --params <绝对路径:params_dir> --images <绝对路径:images_dir> --output <期望输出绝对路径:output.mesh>
  ```
  *(注：如果用户没有给 `images_dir`，你可以省略该参数或随意提供一个空目录即可，仅在最后一步会跳过渲染。)*

### 模式 B: 物理外参模式 (Extrinsic Mode)
* **特征识别**：
  如果只有 YAML 文件，并且里面主要标定为旋转平移矩阵 `extrinsic` (T 矩阵) 而*没有* `weights.png`。
* **执行构建**：
  此模式为标准 3D World 转 2D 模式，Mesh 会按默认正方形 `200x200` 导出。
  请执行：
  ```bash
  python3  generate_mesh.py --params <绝对路径:params.yaml> --output <期望输出绝对路径:output.mesh> --cols 200 --rows 200
  ```

## 3. 运行本地视图验证试渲染 (如有图片)

如果用户提供了正确的 `images_dir` 且里面包含四路测试图：

- **若是模式 A (单应性)**，运行网格渲染测试脚本输出全景测试图像：
  ```bash
  python3  test_render_mesh.py --mesh <刚才生成的.mesh文件> --images <images_dir> --output <项目目录下某JPG路径>
  ```

- **若是模式 B (物理外参)**，运行标准预览脚本：
  ```bash
  python3  preview_mesh.py --mesh <刚才生成的.mesh文件> --images <images_dir> --output <项目目录下某JPG路径>
  ```

## 4. 输出反馈

渲染成图后：
1. 请使用 `view_file` 或相关图像展示工具，快速看一眼生成出的 `output_xxx_bev.jpg` 图像是否四角拼接严重错位。
2. 将最终生成的 `<output.mesh>` 路径以及测试效果图汇报给用户，任务完成。
