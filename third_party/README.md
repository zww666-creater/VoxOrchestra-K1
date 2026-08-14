# 第三方源码与 SDK 边界

本目录只允许存放经许可核验、适合再分发的小型依赖。K1 版本不内嵌
nlohmann-json；它由系统开发包提供，避免把非 amalgamated 头文件误当成
可独立使用的单头文件。

以下依赖由部署环境提供，不复制到本目录：

| 组件 | 构建参数或发现方式 | 版本/许可 |
|---|---|---|
| ZeroMQ / cppzmq | Ubuntu `libzmq3-dev` / `cppzmq-dev` | MPL-2.0 / MIT |
| nlohmann-json | Ubuntu `nlohmann-json3-dev` | MIT |
| ALSA | CMake `find_package(ALSA)` | LGPL-2.1-or-later，系统动态库 |
| sherpa-onnx | `VOXORCHESTRA_SHERTA_ROOT` | Apache-2.0 |
| RKLLM Runtime/API | `VOXORCHESTRA_RKLLM_ROOT` | 1.2.0，Rockchip 分发包许可 |
| SummerTTS / Eigen | `VOXORCHESTRA_SUMMERTTS_ROOT` | MIT / Eigen 文件级许可 |

模型获取与哈希见 `models/README.md`，完整登记见根目录
`THIRD_PARTY_NOTICES.md`。任何没有明确许可证的参考工程自有代码都不得
复制进仓库。
