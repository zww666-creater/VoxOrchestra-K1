#!/usr/bin/env bash
# 启动 K1 上可直接运行的六进程链路（默认 Fake 模型后端，用于移植验收）。
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=${VOXORCHESTRA_DEPLOY_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}
BUILD_DIR=${VOXORCHESTRA_BUILD_DIR:-$ROOT/build-k1}
CONFIG=${VOXORCHESTRA_CONFIG:-$ROOT/config/k1/session.json}
RUN_DIR=${VOXORCHESTRA_RUN_DIR:-/tmp/voxorchestra-k1}
SETUP_TIMEOUT=${VOXORCHESTRA_SETUP_TIMEOUT_SECONDS:-30}
SERVICES=(edge_gateway unit_manager session_node asr_node llm_node tts_node)

fail() {
  echo "K1 启动失败: $*" >&2
  return 1
}

for service in "${SERVICES[@]}"; do
  [ -x "$BUILD_DIR/apps/$service/$service" ] || \
    fail "缺少可执行文件 $BUILD_DIR/apps/$service/$service；请先运行 deploy/k1/build.sh"
done
[ -r "$CONFIG" ] || fail "无法读取配置 $CONFIG"
command -v python3 >/dev/null 2>&1 || fail "缺少 python3"
[[ "$SETUP_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || fail "setup 超时必须是正整数"

VOXORCHESTRA_RUN_DIR="$RUN_DIR" bash "$SCRIPT_DIR/stop.sh" --force >/dev/null
mkdir -p "$RUN_DIR/session-out" "$RUN_DIR/tts-out"

rollback() {
  local status=$?
  trap - EXIT INT TERM
  echo "启动未完成，正在清理；日志保留在 $RUN_DIR" >&2
  VOXORCHESTRA_RUN_DIR="$RUN_DIR" bash "$SCRIPT_DIR/stop.sh" --force >/dev/null 2>&1 || true
  exit "$status"
}
trap rollback EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

start_service() {
  local service=$1
  shift
  nohup "$@" >"$RUN_DIR/$service.log" 2>&1 </dev/null &
  local pid=$!
  echo "$pid" >"$RUN_DIR/$service.pid"
  sleep 0.1
  kill -0 "$pid" 2>/dev/null || fail "$service 启动失败，查看 $RUN_DIR/$service.log"
}

cd "$ROOT"
start_service asr_node "$BUILD_DIR/apps/asr_node/asr_node" \
  --listen tcp://127.0.0.1:19201 --config "$CONFIG" \
  --events tcp://127.0.0.1:19421 --events-sync tcp://127.0.0.1:19422
start_service llm_node "$BUILD_DIR/apps/llm_node/llm_node" \
  --listen tcp://127.0.0.1:19203 --config "$CONFIG" \
  --events tcp://127.0.0.1:19431 --events-sync tcp://127.0.0.1:19432
start_service tts_node "$BUILD_DIR/apps/tts_node/tts_node" \
  --listen tcp://127.0.0.1:19204 --config "$CONFIG" \
  --output-dir "$RUN_DIR/tts-out" \
  --events tcp://127.0.0.1:19441 --events-sync tcp://127.0.0.1:19442
start_service session_node "$BUILD_DIR/apps/session_node/session_node" \
  --listen tcp://127.0.0.1:19310 --backend net \
  --asr-endpoint tcp://127.0.0.1:19201 \
  --asr-events tcp://127.0.0.1:19421 --asr-events-sync tcp://127.0.0.1:19422 \
  --llm-endpoint tcp://127.0.0.1:19203 \
  --llm-events tcp://127.0.0.1:19431 --llm-events-sync tcp://127.0.0.1:19432 \
  --tts-endpoint tcp://127.0.0.1:19204 \
  --tts-events tcp://127.0.0.1:19441 --tts-events-sync tcp://127.0.0.1:19442 \
  --config "$CONFIG" --output-dir "$RUN_DIR/session-out" \
  --fixture-dir "$ROOT/data/fixtures"
start_service unit_manager "$BUILD_DIR/apps/unit_manager/unit_manager" \
  --listen tcp://127.0.0.1:19100 --node tcp://127.0.0.1:19310 \
  --node-rpc-timeout-ms 30000
start_service edge_gateway "$BUILD_DIR/apps/edge_gateway/edge_gateway" \
  --forward-timeout-ms 30000

sleep 1
SETUP_REPLY=$(python3 "$ROOT/scripts/gateway_probe.py" 9100 \
  '{"version":1,"type":"setup","request_id":"k1-deploy-setup"}' \
  "$SETUP_TIMEOUT")
printf '%s\n' "$SETUP_REPLY" >"$RUN_DIR/setup.log"
python3 - "$SETUP_REPLY" <<'PY'
import json
import sys

reply = json.loads(sys.argv[1])
if reply.get("type") != "ack" or not reply.get("work_id"):
    raise SystemExit(f"setup 失败: {reply}")
PY

trap - EXIT INT TERM
echo "K1 六进程链路已启动；日志目录: $RUN_DIR"
