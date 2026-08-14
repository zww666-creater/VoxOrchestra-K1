# 传输库：ZeroMQ 的 REQ/REP、PUB/SUB、PUSH/PULL 封装
#
# 依赖 libzmq 与 cppzmq（Ubuntu/Bianbu 包：libzmq3-dev、cppzmq-dev）。
# 不写死 x86_64/aarch64 库目录，确保 riscv64 的 multiarch 路径可被发现。
add_library(voxorchestra_transport STATIC
  src/rpc.cpp
  src/pubsub.cpp
  src/pushpull.cpp
)
add_library(voxorchestra::transport ALIAS voxorchestra_transport)

find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
  pkg_check_modules(PC_ZMQ QUIET libzmq)
endif()

find_path(ZMQ_INCLUDE_DIR NAMES zmq.h HINTS ${PC_ZMQ_INCLUDE_DIRS})
find_path(ZMQ_CPP_INCLUDE_DIR NAMES zmq.hpp HINTS ${PC_ZMQ_INCLUDE_DIRS})
find_library(ZMQ_LIBRARY NAMES zmq libzmq HINTS ${PC_ZMQ_LIBRARY_DIRS})

if(NOT ZMQ_INCLUDE_DIR OR NOT ZMQ_CPP_INCLUDE_DIR OR NOT ZMQ_LIBRARY)
  message(FATAL_ERROR
    "找不到 ZeroMQ（zmq.h/zmq.hpp/libzmq）。请安装 libzmq3-dev 与 cppzmq-dev，"
    "或设置 PKG_CONFIG_PATH/CMAKE_PREFIX_PATH。")
endif()

target_include_directories(voxorchestra_transport PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)
target_include_directories(voxorchestra_transport SYSTEM PUBLIC
  ${ZMQ_INCLUDE_DIR}
)
target_link_libraries(voxorchestra_transport PUBLIC voxorchestra::common ${ZMQ_LIBRARY})
target_compile_features(voxorchestra_transport PUBLIC cxx_std_17)
