# 轻量 RAG 库：JSONL 知识库、文本规范化、BM25 打分与 L0-L3 分级路由。
# 依赖统一块结构 RetrievedChunk（backends 契约头，无厂商 SDK）。
add_library(voxorchestra_rag STATIC
  src/bm25.cpp
  src/knowledge_store.cpp
  src/router.cpp
  src/text_normalizer.cpp
)
add_library(voxorchestra::rag ALIAS voxorchestra_rag)

target_include_directories(voxorchestra_rag PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)
target_link_libraries(voxorchestra_rag PUBLIC voxorchestra::backend)

# 使用系统 nlohmann-json CMake 包，避免误用不完整的单文件副本。
find_package(nlohmann_json CONFIG REQUIRED)
target_link_libraries(voxorchestra_rag PUBLIC nlohmann_json::nlohmann_json)

target_compile_features(voxorchestra_rag PUBLIC cxx_std_17)
