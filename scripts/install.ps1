$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigJs = Join-Path $ScriptDir "configure-openclaw.mjs"
$RepairJs = Join-Path $ScriptDir "repair-runtime.mjs"
$Roots = @(
  (Join-Path $HOME ".openclaw"),
  (Join-Path $HOME ".qclaw"),
  (Join-Path $HOME ".openclaw-peer")
)

function Need-Cmd([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

Need-Cmd "node"
Need-Cmd "openclaw"

foreach ($root in $Roots) {
  if (Test-Path $root) {
    Write-Host "Patching $root"
    node $ConfigJs patch $root
  }
}

$PrimaryRoot = Join-Path $HOME ".openclaw"
if (Test-Path (Join-Path $PrimaryRoot "openclaw.json")) {
  Write-Host "Repairing primary runtime"
  node $RepairJs repair $PrimaryRoot
}

Write-Host "OpenClaw Cron Doctor install completed."
