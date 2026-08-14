# 许可与发布内容审计

## 许可结论

- 项目自有代码：MIT；
- 仓库内第三方代码：仅 nlohmann-json 3.10.5 单头文件，MIT 许可头保留；
- ZeroMQ/cppzmq/ALSA：系统包；
- sherpa-onnx、ONNX Runtime、RKLLM、SummerTTS、Eigen：外部依赖；
- 参考工程无明确许可的自有集成代码未复制；
- 模型与厂商 SDK 的再分发边界不足以支持公开入库，全部排除。

完整组件表见 `THIRD_PARTY_NOTICES.md`，参考源码台账见
`artifacts/environment-preflight/source-reuse-ledger.md`。

## 内容审计规则

对 `git ls-files` 执行扩展名、文件大小和敏感字符串扫描：

- 禁止模型：`.rkllm`、`.onnx`、模型 `.bin`；
- 禁止动态库/SDK：`.so`、`.a`、厂商头文件副本和构建目录；
- 禁止证据原件：大型日志、稳定性 tar 包、现场录音；
- 禁止凭据：私钥、令牌、密码、板卡地址和个人绝对路径。

仓库保留的 `.wav` 仅为公开固定 fixture，不是现场麦克风录音。

## 候选扫描结果

- `.rkllm/.onnx/.so/.a/.bin/.tar/.tar.gz/.key/.pem` 追踪文件：0；
- 最大追踪文件：`third_party/nlohmann/json.hpp`，170,631 B；
- 追踪音频：`data/fixtures/voice.wav` 32,044 B、`demo_zh.wav` 106,540 B，
  均为 16 kHz mono S16 固定 fixture；
- 追踪日志：两份历史 Mock/TSan 小型文本记录，分别 3,015 B 和 14,175 B；
- 板卡地址、开发机个人绝对路径、私钥头、常见令牌格式命中：0。
