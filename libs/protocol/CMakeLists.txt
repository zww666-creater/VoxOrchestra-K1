# 协议库：统一消息 MessageEnvelope 的 JSON 编码/解码与校验
add_library(voxorchestra_protocol STATIC
  src/message_envelope.cpp
)
add_library(voxorchestra::protocol ALIAS voxorchestra_protocol)

target_include_directories(voxorchestra_protocol PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# nlohmann/json 由系统开发包提供。上游仓库曾包含一个并非 amalgamated
# 版本的 json.hpp，单文件无法独立编译，因此不再以它作为静默 fallback。
find_package(nlohmann_json CONFIG REQUIRED)
target_link_libraries(voxorchestra_protocol PUBLIC nlohmann_json::nlohmann_json)

target_link_libraries(voxorchestra_protocol PUBLIC voxorchestra::common)
target_compile_features(voxorchestra_protocol PUBLIC cxx_std_17)
