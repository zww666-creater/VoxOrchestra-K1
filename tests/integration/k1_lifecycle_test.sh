#!/bin/bash
set -euo pipefail

CASE_NAME=$1
START_SCRIPT=$2
STOP_SCRIPT=$3
TEST_ROOT=$(mktemp -d /tmp/voxorchestra-k1-lifecycle.XXXXXX)
RUN_DIR="$TEST_ROOT/run"
BUILD_DIR="$TEST_ROOT/build-k1"
CONFIG="$TEST_ROOT/config/k1/session.json"
SERVICES=(edge_gateway unit_manager session_node asr_node llm_node tts_node)
PIDS=()

cleanup() {
  trap - EXIT
  if [ "${#PIDS[@]}" -gt 0 ]; then
    kill -KILL "${PIDS[@]}" 2>/dev/null || true
    wait "${PIDS[@]}" 2>/dev/null || true
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$RUN_DIR" "$TEST_ROOT/config/k1" "$TEST_ROOT/scripts"
printf '{}\n' >"$CONFIG"

cat >"$TEST_ROOT/service_stub.cpp" <<'CPP'
#include <libgen.h>
#include <signal.h>
#include <sys/prctl.h>
#include <unistd.h>

volatile sig_atomic_t running = 1;
void stop(int) { running = 0; }

int main(int argc, char** argv) {
  (void)argc;
  prctl(PR_SET_NAME, basename(argv[0]), 0, 0, 0);
  signal(SIGTERM, stop);
  while (running) pause();
  return 0;
}
CPP
g++ -std=c++17 "$TEST_ROOT/service_stub.cpp" -o "$TEST_ROOT/service_stub"

for service in "${SERVICES[@]}"; do
  mkdir -p "$BUILD_DIR/apps/$service"
  cp "$TEST_ROOT/service_stub" "$BUILD_DIR/apps/$service/$service"
done

cat >"$TEST_ROOT/scripts/gateway_probe.py" <<'PY'
#!/usr/bin/env python3
import os

if os.environ.get("K1_SETUP_FAILURE") == "1":
    print('{"version":1,"type":"error","request_id":"k1-deploy-setup"}')
else:
    print('{"version":1,"type":"ack","request_id":"k1-deploy-setup","work_id":"w-0"}')
PY

run_start() {
  VOXORCHESTRA_DEPLOY_ROOT="$TEST_ROOT" \
  VOXORCHESTRA_BUILD_DIR="$BUILD_DIR" \
  VOXORCHESTRA_CONFIG="$CONFIG" \
  VOXORCHESTRA_RUN_DIR="$RUN_DIR" \
  VOXORCHESTRA_SETUP_TIMEOUT_SECONDS=1 \
    /bin/bash "$START_SCRIPT"
}

remember_and_check_services() {
  for service in "${SERVICES[@]}"; do
    pid=$(cat "$RUN_DIR/$service.pid")
    PIDS+=("$pid")
    kill -0 "$pid"
    [ "$(cat "/proc/$pid/comm")" = "$service" ]
  done
}

assert_stopped() {
  for service in "${SERVICES[@]}"; do
    [ ! -e "$RUN_DIR/$service.pid" ]
  done
  for pid in "${PIDS[@]}"; do
    wait "$pid" 2>/dev/null || true
    ! kill -0 "$pid" 2>/dev/null
  done
}

case "$CASE_NAME" in
  start_success)
    run_start
    grep -Fq '"type":"ack"' "$RUN_DIR/setup.log"
    remember_and_check_services
    VOXORCHESTRA_RUN_DIR="$RUN_DIR" /bin/bash "$STOP_SCRIPT"
    assert_stopped
    ;;
  setup_failure)
    export K1_SETUP_FAILURE=1
    set +e
    OUTPUT=$(run_start 2>&1)
    STATUS=$?
    set -e
    [ "$STATUS" -ne 0 ]
    grep -Fq '启动未完成' <<<"$OUTPUT"
    for service in "${SERVICES[@]}"; do
      [ ! -e "$RUN_DIR/$service.pid" ]
    done
    ;;
  stop_idempotent)
    run_start
    remember_and_check_services
    VOXORCHESTRA_RUN_DIR="$RUN_DIR" /bin/bash "$STOP_SCRIPT"
    VOXORCHESTRA_RUN_DIR="$RUN_DIR" /bin/bash "$STOP_SCRIPT"
    assert_stopped
    ;;
  *)
    echo "未知 K1 生命周期测试: $CASE_NAME" >&2
    exit 2
    ;;
esac
