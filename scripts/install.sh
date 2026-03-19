#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JS="$SCRIPT_DIR/configure-openclaw.mjs"
REPAIR_JS="$SCRIPT_DIR/repair-runtime.mjs"

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

for root in "${ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  echo "Patching $root"
  node "$CONFIG_JS" patch "$root"
done

if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  echo "Repairing primary runtime"
  node "$REPAIR_JS" repair "$HOME/.openclaw"
fi

echo "OpenClaw Cron Doctor install completed."
