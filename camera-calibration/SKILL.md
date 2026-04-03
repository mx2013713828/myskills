---
name: camera-calibration
description: Perform camera intrinsic calibration and batch image undistortion. Use when the user provides checkerboard images for calibration or needs to undistort images using either OpenCV fisheye or MATLAB polynomial models.
---

# Camera Calibration & Undistortion Skill

该 Skill 用于执行摄像头的内参标定和图像去畸变任务，支持 OpenCV 鱼眼模型和 MATLAB 多项式模型。

## 启用前检查
在执行任何脚本前，必须检查 Python 环境：
1. 运行 `python3 -c "import cv2, numpy"`。
2. 如果报错，询问用户是否存在虚拟环境。
3. 如果没有虚拟环境，执行 `pip install opencv-python numpy` 进行安装。

## 任务流

### 1. 内参标定
**场景**：用户给定一组包含棋盘格的图片。
**操作**：
- 询问棋盘格尺寸（内角点数，如 11x7）。
- 使用 `scripts/calibrate.py --input_dir <path> --output_file <json_path> --rows <R> --cols <C>`。
- 脚本会自动处理标定异常图片。

### 2. 图像去畸变
**场景**：已有标定好的内参 JSON 文件。
**操作**：
- **参数检测**：读取 JSON 文件。
  - 如果包含 `mappingCoefficients` -> 识别为 MATLAB 多项式模型。
  - 如果包含 `camera_matrix` -> 识别为 OpenCV 鱼眼模型。
- **输出目录**：如果用户未指定，询问是否使用默认目录 `/tmp/undistorted_img`。
- **执行转换**：
  - 调用 `scripts/undistort.py --input <path> --config <json_path> --output <out_path>`。
  - 支持单张图片或整个文件夹。
- **参数微调**：询问用户是否需要调整 `--scale` (MATLAB) 或 `--balance` (OpenCV) 以改变视野范围。

## 完成通知
脚本执行完毕后，汇报成功/失败状态、输出位置以及标定后的 RMS 误差。
