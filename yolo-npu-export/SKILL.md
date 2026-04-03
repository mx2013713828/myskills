---
name: yolo-npu-export
description: 自动化执行 YOLOv5/v8 模型导出至 NBG(NPU) 格式的工作流。Make sure to use this skill whenever the user mentions exporting YOLO, changing input resolution (like 640x384), generating .nb models for T12, or running Pegasus quantization/conversion. Do not attempt manual conversion without this skill.
---

# YOLOv5/v8 NPU 导出与转换专家

当你被触发需要导出一个新的 YOLOv5 或 YOLOv8 模型，并将其转换为 NPU 支持的 `.nb` 格式时，请严格遵循以下工作流。哪怕你觉得自己能凭空写代码，也请**务必按顺序先完成环境自检**。

## 一、 环境自检 (强制第一步)

在开始任何操作前，**必须执行以下环境检查**：

### 1. Docker 环境检查
1. 检查 `docker images` 是否包含 `allwinner_v1.8.11`。
2. 检查 `docker ps -a` 确认容器是否已存在并启动。
3. 如果镜像不存在，主动提醒用户去下载并在宿主机 `docker load`。
4. 确认用户当前账号是否有权限执行类似 `sudo docker exec` 的命令。

### 2. Conda 与 Python 环境检查
1. 运行 `conda env list`，检查宿主机的虚拟环境列表。
2. 寻找是否存在名称中包含 `yolo` 的环境（如 `yolo310`），如果存在，后续涉及 ONNX 导出的 Python 指令请尝试在该环境内执行。
3. 如果不存在任何可行环境，暂缓操作并向用户确认：“是直接使用默认的系统 Python 环境安装 `ultralytics`/`torch` 等依赖，还是需要我帮忙创建一个全新的 Conda 环境？”。

### 3. YOLOv5 源码定制检查 (仅限用户导出 YOLOv5)
YOLOv5 的原生结构附带包含坐标解码和锚点的特征网格，这会立刻造成后续全志的 8-bit PTQ 静态量化发生极值坍塌（导致产生全屏幕的满置信度假阳性框）。因此**决不能用原版导出！**
- 检查系统 `/tmp/yolov5_repo` 目录是否存在。
- 如果不存在，请执行 `git clone https://github.com/ultralytics/yolov5 /tmp/yolov5_repo` 自动拉取代码。
- **强制阻断式修改**：打开 `/tmp/yolov5_repo/models/yolo.py`，定位到 `Detect` 类的 `forward` 方法。为了截断由于网格重组（Grid）和激活（Sigmoid）所导致的全志 NPU 量化误差雪崩，**你必须把原有冗长的推理分支砍掉，修改为以下极简状态**：
  ```python
      def forward(self, x):
          for i in range(self.nl):
              x[i] = self.m[i](x[i])  # 执行最终的卷积预测 (保留这行)
          # =========== 关键修改点 ===========
          return tuple(x) # 截断后续的 view/permute 变形与 _make_grid 解码，直接抛出特征图！
  ```
  > **操作指引**：保留开头的 `for i in ...` 循环及其内部的那句 `x[i] = self.m[i](x[i])`。紧接着插入 `return tuple(x)` (或者 `return x`)，并且把你看到的后面的所有关于 `bs, _, ny, nx = ...` 以及 `if not self.training:` 和 `self._make_grid` 等冗杂逻辑**全部注释掉或删除**。这是保障 NPU 部署精度不崩塌的生命线。

## 二、 准备工具链脚本与量化数据集

### 1. 查找或应用自动化脚本模板
不要直接硬敲 Bash 进去 Docker。
1. 检查当前项目的 `tools/` 目录下（如 `T12_svs/tools/`），是否存在针对用户目标模型和目标分辨率的构建脚本（例如 `reexport_v8n_640.sh`）。
2. **如果项目内存在相关脚本**：请你打开审阅该脚本，确保里面的分辨率长宽、网络模型名称是对的，然后可以直接执行。
3. **如果项目内不存在**：不要瞎编！你需要从本技能的目录里复制标准模板：
   - 模板路径：`.agents/skills/yolo-npu-export/templates/reexport_template.sh`
   - 将上述模板拷贝到宿主项目的 `tools/` 目录下（根据约定重命名，如 `reexport_v8m_416.sh`）。
   - 打开脚本，将其顶部的 `{MODEL_NAME}`, `{MODEL_FAMILY}`, `{IMG_W}`, `{IMG_H}`, `{IMG_SHAPE_STR}` 等大写花括号位置变量，利用 `sed` 命令或者 Python 替换成用户期望的真实值。

### 2. 补齐量化环境 (AI-SDK)
1. 在 `tools/ai-sdk/models/` 目录下建设对应的工作区（例如 `yolov5m-sim-416/`）。
2. 任何模型转换都**不能没有输入校准集**。你必须拷贝至少一份老旧工作区里的 `dataset.txt` 与图片目录至本次工作区，保证量化(pegasus quantize) 顺利运行。

## 三、 脚本联调与 NBG 输出

### 1. 启动导出 (执行准备好的 Bash)
当一切检查就绪，直接触发对应的 `.sh` 脚本。它将包办：
- 通过 conda python 完成 ONNX 特征的导出。
- 将 `.onnx` 文件移动至 AI-SDK 下的 `sim` 挂载目录。
- 生成在容器内执行 `Pegasus` 的二次 Bash。
- 使用 `docker exec` 将运行命令注入 `allwinner` 环境中进行 `0x1001E` 图运算编译。

### 2. LID 正则防掉坑提示
极大概率你在转换别的尺度网络时会碰到容器执行失败，报错提示 “找不到指定的 Layer Input（输入节点）ID”。
你必须阅读对应的构建脚本（或生成出的 `yolov8n-sim.json` 等原图拓扑），找到包含 `images` 命名层所在的正真的 LID（有可能是 `images_258` 等动态变体），在脚本内做好正则提取逻辑拦截它。

### 3. 后续扫尾
1. 脚本执行成功（提示 `Export command finished`）后，前往 `app/src/main/assets/models/` 核验产物 `.nb`。
2. 以优雅的 `git status` 向总负责人（用户）邀功，提示已无缝就绪即可。
