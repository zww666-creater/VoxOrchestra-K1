#!/usr/bin/env bash
# 经 TCP 网关验证 setup 后的 L1 RAG → TTS 完整链路与六进程存活状态。
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
RUN_DIR=${VOXORCHESTRA_RUN_DIR:-/tmp/voxorchestra-k1}
SERVICES=(edge_gateway unit_manager session_node asr_node llm_node tts_node)

for service in "${SERVICES[@]}"; do
  file="$RUN_DIR/$service.pid"
  [ -r "$file" ] || { echo "缺少 $service PID 文件" >&2; exit 1; }
  pid=$(cat "$file")
  kill -0 "$pid" 2>/dev/null || { echo "$service 未运行" >&2; exit 1; }
  [ -r "/proc/$pid/comm" ] && [ "$(cat "/proc/$pid/comm")" = "$service" ] || {
    echo "$service PID 校验失败" >&2
    exit 1
  }
done

[ -s "$RUN_DIR/setup.log" ] || { echo "缺少 setup.log" >&2; exit 1; }
WORK_ID=$(python3 - "$RUN_DIR/setup.log" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    print(json.load(f)["work_id"])
PY
)

REQUEST=$(printf '{"version":1,"type":"inference","work_id":"%s","request_id":"k1-smoke","payload":{"mode":"text","text":"16kHz 音频格式"}}' "$WORK_ID")
REPLY=$(python3 "$ROOT/scripts/gateway_probe.py" 9100 "$REQUEST" 30)
printf '%s\n' "$REPLY" >"$RUN_DIR/smoke.log"
python3 - "$REPLY" <<'PY'
import json
import os
import sys

reply = json.loads(sys.argv[1])
if reply.get("type") != "result":
    raise SystemExit(f"推理返回类型异常: {reply}")
payload = reply.get("payload", {})
if payload.get("status") != "completed":
    raise SystemExit(f"推理未完成: {payload}")
if not payload.get("final_text"):
    raise SystemExit("final_text 为空")
wav = payload.get("wav_path")
if not wav or not os.path.isfile(wav) or os.path.getsize(wav) <= 44:
    raise SystemExit(f"WAV 输出无效: {wav}")
print(f"route={payload.get('route')} final_text={payload['final_text']}")
print(f"wav={wav} bytes={os.path.getsize(wav)}")
PY

echo "K1 smoke test 通过：六进程、网关、RAG、数据面与 WAV 输出均正常"
