#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JS="$SCRIPT_DIR/configure-openclaw.mjs"

ROOTS=(
  "$HOME/.openclaw"
  "$HOME/.qclaw"
  "$HOME/.openclaw-peer"
)

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd node

quit_known_port_conflict() {
  local port="$1"
  local pid command_line
  pid="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | head -n1 || true)"
  [[ -n "$pid" ]] || return 0
  command_line="$(ps -p "$pid" -ww -o command= 2>/dev/null || true)"
  if [[ "$command_line" == *"AutoClaw.app"* || "$command_line" == *"/Applications/AutoClaw.app/"* ]]; then
    echo "Quitting AutoClaw because it is occupying OpenClaw gateway port $port"
    osascript -e 'quit app "AutoClaw"' >/dev/null 2>&1 || true
    sleep 3
  fi
}

restart_gateway_if_present() {
  if launchctl list | rg -q '^.*ai\.openclaw\.gateway$'; then
    echo "Restarting ai.openclaw.gateway"
    launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway" || true
    sleep 2
  fi
  if launchctl list | rg -q '^.*ai\.openclaw\.node$'; then
    echo "Restarting ai.openclaw.node"
    launchctl kickstart -k "gui/$(id -u)/ai.openclaw.node" || true
    sleep 2
  fi
}

for root in "${ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  echo "Patching $root"
  node "$CONFIG_JS" patch "$root"
done

if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  runtime_json="$(node "$CONFIG_JS" runtime "$HOME/.openclaw")"
  port="$(printf '%s' "$runtime_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).port))')"
  quit_known_port_conflict "$port"
  restart_gateway_if_present
  echo "Primary runtime:"
  printf '%s\n' "$runtime_json"
fi

echo "OpenClaw Cron Doctor install completed."
