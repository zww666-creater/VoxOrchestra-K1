# K1 部署与验收

目标平台：SpacemiT K1、`riscv64`、Bianbu Linux。

## 1. 安装依赖

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake pkg-config python3 \
  libzmq3-dev cppzmq-dev nlohmann-json3-dev
```

检查环境：

```bash
uname -m                    # 应输出 riscv64
cmake --version             # 要求 >= 3.22
pkg-config --modversion libzmq
test -r /usr/include/zmq.hpp
test -r /usr/include/nlohmann/json.hpp
```

`libs/transport/CMakeLists.txt` 先使用 pkg-config 提供的路径，再使用 CMake
通用查找，不包含 `/usr/lib/x86_64-linux-gnu` 或
`/usr/lib/aarch64-linux-gnu` 等架构硬编码。

云实例没有 sudo 权限时，可把固定版本依赖编译到用户目录：

```bash
deploy/k1/bootstrap_deps.sh
source "$HOME/.local/voxorchestra-k1/env.sh"
```

该脚本安装 libzmq 4.3.5、cppzmq 4.10.0 与 nlohmann-json 3.11.3，
不修改系统目录。后续新终端需要重新 `source` 该环境文件。

## 2. 原生构建

```bash
chmod +x deploy/k1/*.sh
source "$HOME/.local/voxorchestra-k1/env.sh"  # 使用系统 apt 包时无需此行
deploy/k1/build.sh
```

脚本依次完成 Release 配置、构建、全量 CTest 与“无 RK 厂商依赖”检查。
默认产物目录为 `build-k1/`。K1 内存紧张时可降低并行度：

```bash
VOXORCHESTRA_BUILD_JOBS=2 deploy/k1/build.sh
```

CI 在 x86_64 上复用同一脚本时显式设置
`VOXORCHESTRA_ALLOW_NON_RISCV=1`；真机不应设置该变量。

## 3. 启动六进程链路

```bash
deploy/k1/start.sh
```

启动顺序为 ASR、LLM、TTS、Session、Unit Manager、Edge Gateway。
每个进程都有独立 PID 与日志，默认保存在 `/tmp/voxorchestra-k1/`；
启动脚本随后经 `9100/tcp` 发出 `setup`，只有收到 `ack + work_id`
才视为成功。任一阶段失败都会回滚已经启动的进程。

常用覆盖项：

```bash
VOXORCHESTRA_BUILD_DIR=/opt/voxorchestra/build-k1 \
VOXORCHESTRA_CONFIG=/opt/voxorchestra/config/k1/session.json \
VOXORCHESTRA_RUN_DIR=/var/tmp/voxorchestra-k1 \
deploy/k1/start.sh
```

## 4. Smoke test

```bash
deploy/k1/run_smoke.sh
```

该测试不是简单检查 PID，而是执行：

1. 校验六个 PID 与 `/proc/<pid>/comm`；
2. 读取启动时分配的 `work_id`；
3. 经 TCP 网关提交“16kHz 音频格式”请求；
4. 验证请求完成、RAG 路由与 `final_text`；
5. 验证 TTS 数据面产生有效 WAV 文件。

查看证据：

```bash
cat /tmp/voxorchestra-k1/setup.log
cat /tmp/voxorchestra-k1/smoke.log
tail -n 50 /tmp/voxorchestra-k1/*.log
```

## 5. 停止与清理

```bash
deploy/k1/stop.sh
# 紧急停止，仅处理本部署目录 PID 文件记录的进程：
deploy/k1/stop.sh --force
```

脚本不会使用全局 `pkill`，避免误杀同一设备上的其他工程实例。

## 6. 当前后端边界

`config/k1/session.json` 默认使用 Fake ASR/LLM/TTS。它们用于验证 K1 上的
编译、进程隔离、ZMQ/TCP、RAG、流式事件、取消语义和音频文件输出，输出的
WAV 是确定性的 500 Hz 测试音，不是自然语音。

上游真实后端中的 RKLLM 和 SummerTTS 绑定 RK3576 SDK，不能直接链接到 K1。
在 K1 真实模型后端接入并完成板端测量前，本仓库不会把 RK3576 数据标成 K1
结果。真实模型适配需另行记录模型、Runtime、驱动、延迟、RSS 与稳定性证据。

## 7. 故障排查

- CMake 报缺 `zmq.hpp`：安装 `cppzmq-dev`，它和 `libzmq3-dev` 是两个包。
- CMake 报缺 `nlohmann_jsonConfig.cmake`：安装 `nlohmann-json3-dev`。
- 构建被系统杀死：设置 `VOXORCHESTRA_BUILD_JOBS=1` 或 `2`。
- `setup` 失败：逐个查看 `/tmp/voxorchestra-k1/*.log`，确认 19100、
  19310、19201、19203、19204、19421-19442 和 9100 端口未被占用。
- smoke 找不到 WAV：检查 `session_node.log` 与 `tts_node.log`，并确认运行目录
  可写。
