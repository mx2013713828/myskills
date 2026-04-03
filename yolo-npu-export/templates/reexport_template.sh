#!/bin/bash
# Re-export script Template for YOLOv5/v8 - targeting 0x1001E version for 1.13.0 Driver
# ----------------------------------------------------
# 使用说明 / Usage for Agents:
# 1. 拷贝本模板到项目的 `tools/` 目录下，并命名为类似 `reexport_v8n_416.sh`。
# 2. 替换其中的大写变量 {MODEL_NAME}, {MODEL_FAMILY}, {IMG_W}, {IMG_H}, {IMG_SHAPE_STR}
#    - MODEL_NAME: yolov8n, yolov5s 等
#    - MODEL_FAMILY: v8 或 v5
#    - IMG_W: 图像宽度 (例如 640)
#    - IMG_H: 图像高度 (例如 384)
#    - IMG_SHAPE_STR: "384,640" (v8) 或者 "384 640" (v5) 即 heights, widths
# ----------------------------------------------------

PASSWORD="sdlgmyf"
INTERNAL_SDK="/root/Vivante_IDE/VivanteIDE5.8.2/cmdtools"
TARGET_CONFIG="VIP9000NANOSI_PLUS_PID0X10000016"

ROOT_DIR="/home/myf/AndroidStudioProjects/T12_svs"
echo "Preparing {MODEL_NAME} {IMG_W}x{IMG_H} environment..."
cd "$ROOT_DIR/tools" || exit

# ----------------- 1. ONNX 导出 -----------------
# 注意：基于不同的模型家族 (v5/v8)，这里有差异，Agent 请务必检查并只保留一段。

if [ "{MODEL_FAMILY}" == "v8" ]; then
    # === YOLOv8 导出逻辑 ===
    # 要求环境: ultralytics (可以通过 conda 激活对应含有 yolo 的环境)
    echo ">> Exporting YOLOv8 ONNX..."
    conda run -n yolo310 yolo export model={MODEL_NAME}.pt format=onnx imgsz={IMG_SHAPE_STR} opset=11
elif [ "{MODEL_FAMILY}" == "v5" ]; then
    # === YOLOv5 导出逻辑 ===
    # 注意：YOLOv5 必须去除解码层！所以需要在定制版的 /tmp/yolov5_repo 下通过 export.py 导出。
    echo ">> Exporting YOLOv5 ONNX without decode head..."
    cd /tmp/yolov5_repo
    # conda run -n yolo310 也可。这里假定环境已对齐。
    python export.py --weights {MODEL_NAME}.pt --img {IMG_SHAPE_STR} --include onnx --opset 11
    # 然后需要把导出的模型拷贝回我们的工作区：
    cp {MODEL_NAME}.onnx "$ROOT_DIR/tools/{MODEL_NAME}.onnx"
    cd "$ROOT_DIR/tools" || exit
else
    echo "Unknown MODEL_FAMILY -> {MODEL_FAMILY}. Expect v5 or v8."
    exit 1
fi

if [ $? -ne 0 ]; then
    echo "FAILURE: YOLO ONNX export failed."
    exit 1
fi

# ----------------- 2. 准备配置目录 -----------------
mkdir -p "$ROOT_DIR/tools/ai-sdk/models/{MODEL_NAME}-sim-{IMG_W}"
mv {MODEL_NAME}.onnx ai-sdk/models/{MODEL_NAME}-sim-{IMG_W}/{MODEL_NAME}-sim-{IMG_W}.onnx

# 从项目统一校准集目录 (yolov8n-sim-640) 复制 calibration 数据。
# 所有模型共享同一份校准图片，仅在该目录维护即可。
cp ai-sdk/models/yolov8n-sim-640/dataset.txt ai-sdk/models/{MODEL_NAME}-sim-{IMG_W}/
cp -r ai-sdk/models/yolov8n-sim-640/images ai-sdk/models/{MODEL_NAME}-sim-{IMG_W}/ 2>/dev/null || true

# ----------------- 3. 生成 Docker 内嵌脚本 -----------------
cat << 'DOCKER_EOF' > "$ROOT_DIR/tools/ai-sdk/models/{MODEL_NAME}-sim-{IMG_W}/run_pegasus.sh"
#!/bin/bash
export ACUITY_PATH=/usr/local/acuity_command_line_tools
export VIVANTE_SDK_DIR=/root/Vivante_IDE/VivanteIDE5.8.2/cmdtools
export VSI_SRAM_SIZE=0x80000
export VSIMULATOR_CONFIG=VIP9000NANOSI_PLUS_PID0X10000016
export VSIMULATOR_SHADER_CORE_COUNT=1

cd /workspace/ai-sdk/models/{MODEL_NAME}-sim-{IMG_W}

echo '>> Importing ONNX...'
python3 /usr/local/acuity_command_line_tools/pegasus.py import onnx \
    --model {MODEL_NAME}-sim-{IMG_W}.onnx \
    --output-model {MODEL_NAME}-sim.json \
    --output-data {MODEL_NAME}-sim.data \
    --inputs images --input-size-list '3,{IMG_H},{IMG_W}'

echo '>> Generating inputmeta.yml...'
python3 -c "
import re
with open('{MODEL_NAME}-sim.json', 'r') as f:
    text = f.read()

# !!! 动态匹配正确的输入节点 ID 防止硬编码报错 !!!
match = re.search(r'\"([^\"]+)\":\s*\{\s*\"name\":\s*\"images\"', text)
lid = match.group(1) if match else 'images_0'
print('Input LID extracted:', lid)

with open('{MODEL_NAME}-sim_inputmeta.yml', 'w') as f:
    f.write(f'''# !!!This file disallow TABs!!!
input_meta:
  databases:
  - path: dataset.txt
    type: TEXT
    ports:
    - lid: {lid}
      category: image
      dtype: uint8
      sparse: false
      tensor_name:
      layout: nchw
      shape:
      - 1
      - 3
      - {IMG_H}
      - {IMG_W}
      fitting: scale
      preprocess:
        reverse_channel: true
        mean:
        - 0
        - 0
        - 0
        scale:
        - 0.00392157
        - 0.00392157
        - 0.00392157
        preproc_node_params:
          add_preproc_node: false
          preproc_type: IMAGE_RGB
          preproc_image_size:
          - {IMG_W}
          - {IMG_H}
          preproc_crop:
            enable_preproc_crop: false
            crop_rect:
            - 0
            - 0
            - {IMG_W}
            - {IMG_H}
''')
"

echo '>> Generating Quantization (Asymmetric_affine)...'
python3 /usr/local/acuity_command_line_tools/pegasus.py quantize \
    --model {MODEL_NAME}-sim.json \
    --model-data {MODEL_NAME}-sim.data \
    --with-input-meta {MODEL_NAME}-sim_inputmeta.yml \
    --quantizer asymmetric_affine \
    --qtype uint8 \
    --model-quantize {MODEL_NAME}-sim.quantize

echo '>> Exporting ovxlib (NBG target)...'
python3 /usr/local/acuity_command_line_tools/pegasus.py export ovxlib \
    --model {MODEL_NAME}-sim.json \
    --model-data {MODEL_NAME}-sim.data \
    --dtype quantized \
    --model-quantize {MODEL_NAME}-sim.quantize \
    --with-input-meta {MODEL_NAME}-sim_inputmeta.yml \
    --target-ide-project 'linux64' \
    --pack-nbg-unify \
    --optimize VIP9000NANOSI_PLUS_PID0X10000016 \
    --viv-sdk /root/Vivante_IDE/VivanteIDE5.8.2/cmdtools \
    --output-path wksp/582
DOCKER_EOF

chmod +x "$ROOT_DIR/tools/ai-sdk/models/{MODEL_NAME}-sim-{IMG_W}/run_pegasus.sh"

echo "Running export with IDE5.8.2 (Version 0x1001E) inside Docker..."
# ----------------- 4. 调用 Docker 执行  -----------------
# 注意：容器名称我们指定为 allwinner_v1.8.11。密码通过 EOF 注入。
sudo -S docker exec allwinner_v1.8.11 bash -c "/workspace/ai-sdk/models/{MODEL_NAME}-sim-{IMG_W}/run_pegasus.sh" <<EOF
$PASSWORD
EOF

if [ $? -eq 0 ]; then
    echo "SUCCESS: Export command finished."
    mkdir -p "$ROOT_DIR/app/src/main/assets/models"
    
    NB_FILE=$(find "$ROOT_DIR/tools/ai-sdk/models/{MODEL_NAME}-sim-{IMG_W}/wksp_nbg_unify" -name "*.nb" 2>/dev/null | head -n 1)
    if [ -n "$NB_FILE" ]; then
        cp "$NB_FILE" "$ROOT_DIR/app/src/main/assets/models/{MODEL_NAME}_{IMG_W}.nb"
        echo "Model successfully deployed: $NB_FILE -> app/src/main/assets/models/{MODEL_NAME}_{IMG_W}.nb"
    else
        echo "FAILURE: Could not find generated .nb file in wksp_nbg_unify"
    fi
else
    echo "FAILURE: Docker script encountered an error."
fi
