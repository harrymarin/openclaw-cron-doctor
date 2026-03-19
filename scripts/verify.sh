#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JS="$SCRIPT_DIR/configure-openclaw.mjs"
ROOT="${1:-$HOME/.openclaw}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd node
need_cmd openclaw

runtime_json="$(node "$CONFIG_JS" runtime "$ROOT")"
PORT="$(printf '%s' "$runtime_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).port))')"
TOKEN="$(printf '%s' "$runtime_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).token || ""))')"
PRIMARY="$(printf '%s' "$runtime_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).primary || ""))')"

if [[ -z "$TOKEN" ]]; then
  echo "Gateway token missing in $ROOT/openclaw.json" >&2
  exit 1
fi

SMOKE_FILE="$ROOT/workspace/memory/cron-smoke.md"
JOB_NAME="cron-smoke-verify-$(date +%s)"
MESSAGE="Create or update $SMOKE_FILE with a single new line in the format: CRON_SMOKE_OK <ISO8601 timestamp>. Then output exactly that same line as the final response. Do not call the message tool."
PREVIOUS_LAST_LINE=""
PREVIOUS_LINE_COUNT=0

echo "Runtime primary model: $PRIMARY"
echo "Smoke file: $SMOKE_FILE"

mkdir -p "$(dirname "$SMOKE_FILE")"
if [[ -f "$SMOKE_FILE" ]]; then
  PREVIOUS_LAST_LINE="$(tail -n 1 "$SMOKE_FILE" 2>/dev/null || true)"
  PREVIOUS_LINE_COUNT="$(wc -l < "$SMOKE_FILE" | tr -d ' ')"
fi

add_output="$(
  openclaw cron add \
    --json \
    --url "ws://127.0.0.1:$PORT" \
    --token "$TOKEN" \
    --name "$JOB_NAME" \
    --description "Silent one-shot cron smoke test from OpenClaw Cron Doctor" \
    --at 70s \
    --session isolated \
    --no-deliver \
    --delete-after-run \
    --message "$MESSAGE"
)"

echo "$add_output"
JOB_ID="$(printf '%s' "$add_output" | node -e '
let s="";
process.stdin.on("data",d=>s+=d).on("end",()=>{
  const objects = [];
  let depth = 0;
  let start = -1;
  let inString = false;
  let escaped = false;
  for (let i = 0; i < s.length; i += 1) {
    const ch = s[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\\\") {
        escaped = true;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }
    if (ch === "\"") {
      inString = true;
      continue;
    }
    if (ch === "{") {
      if (depth === 0) start = i;
      depth += 1;
      continue;
    }
    if (ch === "}") {
      if (depth === 0) continue;
      depth -= 1;
      if (depth === 0 && start >= 0) {
        objects.push(s.slice(start, i + 1));
        start = -1;
      }
    }
  }
  for (let i = objects.length - 1; i >= 0; i -= 1) {
    try {
      const obj = JSON.parse(objects[i]);
      if (obj && typeof obj.id === "string") {
        console.log(obj.id);
        return;
      }
    } catch {}
  }
  process.exit(1);
})')"
START_EPOCH="$(date +%s)"
TIMEOUT_SECONDS=180

while true; do
  now="$(date +%s)"
  if (( now - START_EPOCH > TIMEOUT_SECONDS )); then
    echo "Smoke verification timed out. Cleaning up $JOB_ID" >&2
    openclaw cron remove "$JOB_ID" --url "ws://127.0.0.1:$PORT" --token "$TOKEN" --json >/dev/null 2>&1 || true
    exit 1
  fi

  if [[ -f "$SMOKE_FILE" ]] && tail -n 5 "$SMOKE_FILE" | rg -q '^CRON_SMOKE_OK '; then
    CURRENT_LAST_LINE="$(tail -n 1 "$SMOKE_FILE" 2>/dev/null || true)"
    CURRENT_LINE_COUNT="$(wc -l < "$SMOKE_FILE" | tr -d ' ')"
    if [[ "$CURRENT_LAST_LINE" != "$PREVIOUS_LAST_LINE" ]] || (( CURRENT_LINE_COUNT > PREVIOUS_LINE_COUNT )); then
      if openclaw cron list --json --url "ws://127.0.0.1:$PORT" --token "$TOKEN" | rg -q "\"$JOB_ID\""; then
        openclaw cron remove "$JOB_ID" --url "ws://127.0.0.1:$PORT" --token "$TOKEN" --json >/dev/null 2>&1 || true
        echo "Smoke verification succeeded. Job executed and stale cron entry was cleaned up."
      else
        echo "Smoke verification succeeded."
      fi
      tail -n 5 "$SMOKE_FILE"
      exit 0
    fi
  fi

  sleep 5
done
