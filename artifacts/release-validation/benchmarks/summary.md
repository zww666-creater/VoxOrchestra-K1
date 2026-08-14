# 稳定性摘要

| 指标 | 结果 |
|---|---|
| 固定 WAV 全真实轮次 | 30 |
| 成功 | 30 |
| p50 | 56,273 ms |
| p95 | 61,849 ms |
| ASR RSS 首末 | 136,428 -> 130,096 KB |
| LLM RSS 首末 | 1,065,544 -> 1,065,588 KB |
| TTS RSS 首末 | 385,544 -> 385,440 KB |
| 温度 | 43.461–46.230 °C |
| Fake/Mock 标记 | 180 份日志中 0 |

原始归档不入库：

- `full-pipeline-stability-30.tar.gz`
- SHA256 `5cb91dd560072c45066d70da12ba9b26bfa4df13b29edb21c0fa5da2fd880da0`
- 汇总 CSV SHA256 `41c828a3cbc62697a6a73780985a667523fd1b22ecf5256408746a3b23e7858d`

详细方法和适用边界见 `docs/benchmark.md`。
