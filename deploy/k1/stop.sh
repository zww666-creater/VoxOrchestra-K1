#!/usr/bin/env bash
# 仅根据本部署目录中的 PID 文件停止六个服务，避免误杀其他工程进程。
set -euo pipefail

RUN_DIR=${VOXORCHESTRA_RUN_DIR:-/tmp/voxorchestra-k1}
SERVICES=(edge_gateway unit_manager session_node asr_node llm_node tts_node)
MODE=${1:-graceful}

if [ "$MODE" != graceful ] && [ "$MODE" != --force ]; then
  echo "用法: bash deploy/k1/stop.sh [--force]" >&2
  exit 2
fi

service_pid() {
  local service=$1
  local file="$RUN_DIR/$service.pid"
  local pid
  [ -r "$file" ] || return 1
  pid=$(cat "$file")
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
  [ -r "/proc/$pid/comm" ] || return 1
  [ "$(cat "/proc/$pid/comm")" = "$service" ] || return 1
  printf '%s\n' "$pid"
}

for service in "${SERVICES[@]}"; do
  if pid=$(service_pid "$service"); then
    if [ "$MODE" = --force ]; then
      kill -KILL "$pid" 2>/dev/null || true
    else
      kill -TERM "$pid" 2>/dev/null || true
    fi
  fi
done

if [ "$MODE" = graceful ]; then
  for _ in $(seq 1 40); do
    alive=0
    for service in "${SERVICES[@]}"; do
      if pid=$(service_pid "$service") && kill -0 "$pid" 2>/dev/null; then
        alive=1
        break
      fi
    done
    [ "$alive" -eq 0 ] && break
    sleep 0.25
  done
  for service in "${SERVICES[@]}"; do
    if pid=$(service_pid "$service") && kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done
fi

for service in "${SERVICES[@]}"; do
  rm -f "$RUN_DIR/$service.pid"
done
echo "K1 六进程服务已停止"
