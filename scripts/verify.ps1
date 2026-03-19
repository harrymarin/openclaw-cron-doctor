$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigJs = Join-Path $ScriptDir "configure-openclaw.mjs"
$Root = if ($args.Count -gt 0) { $args[0] } else { (Join-Path $HOME ".openclaw") }

function Need-Cmd([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

Need-Cmd "node"
Need-Cmd "openclaw"

$runtimeJson = node $ConfigJs runtime $Root
$runtime = $runtimeJson | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($runtime.token)) {
  throw "Gateway token missing in $Root/openclaw.json"
}

$smokeFile = Join-Path $Root "workspace\memory\cron-smoke.md"
$jobName = "cron-smoke-verify-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$message = "Create or update $smokeFile with a single new line in the format: CRON_SMOKE_OK <ISO8601 timestamp>. Then output exactly that same line as the final response. Do not call the message tool."
$previousLastLine = ""
$previousLineCount = 0

Write-Host "Runtime primary model: $($runtime.primary)"
Write-Host "Smoke file: $smokeFile"

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $smokeFile) | Out-Null
if (Test-Path $smokeFile) {
  $lines = Get-Content $smokeFile
  if ($lines.Count -gt 0) {
    $previousLastLine = $lines[-1]
    $previousLineCount = $lines.Count
  }
}

$addOutput = openclaw cron add --json --url "ws://127.0.0.1:$($runtime.port)" --token $runtime.token --name $jobName --description "Silent one-shot cron smoke test from OpenClaw Cron Doctor" --at 70s --session isolated --no-deliver --delete-after-run --message $message
$jobId = $addOutput | node -e @'
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
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === "\"") inString = false;
      continue;
    }
    if (ch === "\"") { inString = true; continue; }
    if (ch === "{") { if (depth === 0) start = i; depth += 1; continue; }
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
});
'@

$start = Get-Date
while (((Get-Date) - $start).TotalSeconds -lt 180) {
  if (Test-Path $smokeFile) {
    $lines = Get-Content $smokeFile
    if ($lines.Count -gt 0 -and $lines[-1] -match '^CRON_SMOKE_OK ') {
      $currentLastLine = $lines[-1]
      $currentLineCount = $lines.Count
      if ($currentLastLine -ne $previousLastLine -or $currentLineCount -gt $previousLineCount) {
        $listOutput = openclaw cron list --json --url "ws://127.0.0.1:$($runtime.port)" --token $runtime.token
        if ($listOutput -match [regex]::Escape($jobId)) {
          openclaw cron rm $jobId --json --url "ws://127.0.0.1:$($runtime.port)" --token $runtime.token *> $null
          Write-Host "Smoke verification succeeded. Job executed and stale cron entry was cleaned up."
        } else {
          Write-Host "Smoke verification succeeded."
        }
        $lines | Select-Object -Last 5 | ForEach-Object { Write-Host $_ }
        exit 0
      }
    }
  }
  Start-Sleep -Seconds 5
}

Write-Error "Smoke verification timed out. Cleaning up $jobId"
openclaw cron rm $jobId --json --url "ws://127.0.0.1:$($runtime.port)" --token $runtime.token *> $null
exit 1
