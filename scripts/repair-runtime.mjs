#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

function run(cmd, args, options = {}) {
  const result = spawnSync(cmd, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    ...options
  });
  return {
    ok: result.status === 0,
    status: result.status ?? 1,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? ""
  };
}

function needCmd(cmd) {
  const probe = process.platform === "win32"
    ? run("where", [cmd], { shell: true })
    : run("sh", ["-lc", `command -v ${cmd}`]);
  if (!probe.ok) {
    console.error(`Missing required command: ${cmd}`);
    process.exit(1);
  }
}

function loadRuntime(root) {
  const file = path.join(root, "openclaw.json");
  const config = JSON.parse(fs.readFileSync(file, "utf8"));
  return {
    root,
    port: config?.gateway?.port ?? 18789,
    token: config?.gateway?.auth?.token ?? "",
    primary: config?.agents?.defaults?.model?.primary ?? ""
  };
}

function maybeQuitMacConflict(port) {
  const pidProbe = run("sh", ["-lc", `lsof -tiTCP:${port} -sTCP:LISTEN | head -n1`]);
  const pid = pidProbe.stdout.trim();
  if (!pid) return { changed: false, reason: "no listener" };
  const cmdProbe = run("ps", ["-p", pid, "-ww", "-o", "command="]);
  const commandLine = cmdProbe.stdout.trim();
  if (!/AutoClaw\.app/i.test(commandLine)) {
    return { changed: false, reason: "listener is not AutoClaw", listener: commandLine || pid };
  }
  run("osascript", ["-e", 'quit app "AutoClaw"']);
  return { changed: true, action: "quit AutoClaw.app", pid, listener: commandLine };
}

function maybeQuitWindowsConflict(port) {
  const script = [
    `$conn = Get-NetTCPConnection -LocalPort ${port} -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1`,
    "if (-not $conn) { return }",
    "$pid = $conn.OwningProcess",
    '$proc = Get-CimInstance Win32_Process -Filter "ProcessId = $pid" -ErrorAction SilentlyContinue',
    "if (-not $proc) {",
    "  [Console]::WriteLine($pid)",
    "  return",
    "}",
    "$name = $proc.Name",
    "$exe = $proc.ExecutablePath",
    '[Console]::WriteLine("$pid`t$name`t$exe")'
  ].join("\n");
  const probe = run("powershell", ["-NoProfile", "-Command", script], { shell: true });
  const line = probe.stdout.trim();
  if (!line) return { changed: false, reason: "no listener" };
  const [pid, name = "", exe = ""] = line.split("\t");
  if (!/autoclaw/i.test(`${name} ${exe}`)) {
    return { changed: false, reason: "listener is not AutoClaw", listener: `${name} ${exe}`.trim() || pid };
  }
  run("taskkill", ["/PID", pid, "/F"], { shell: true });
  return { changed: true, action: "killed AutoClaw process", pid, listener: `${name} ${exe}`.trim() };
}

function maybeQuitKnownConflict(port) {
  if (process.platform === "darwin") return maybeQuitMacConflict(port);
  if (process.platform === "win32") return maybeQuitWindowsConflict(port);
  return { changed: false, reason: `no platform-specific conflict handler for ${process.platform}` };
}

function restartService(args) {
  const result = run("openclaw", args, { shell: process.platform === "win32" });
  return {
    ok: result.ok,
    command: `openclaw ${args.join(" ")}`,
    stdout: result.stdout.trim(),
    stderr: result.stderr.trim()
  };
}

function repair(root) {
  needCmd("node");
  needCmd("openclaw");
  const runtime = loadRuntime(root);
  const conflict = maybeQuitKnownConflict(runtime.port);
  const gateway = restartService(["gateway", "restart"]);
  const node = restartService(["node", "restart"]);
  let doctor = { ok: false, skipped: true };
  if (!gateway.ok && !node.ok) {
    doctor = restartService(["doctor", "--repair", "--non-interactive", "--yes"]);
  }
  return { runtime, conflict, gateway, node, doctor, platform: process.platform, host: os.hostname() };
}

const [, , command, rootArg] = process.argv;
if (command !== "repair" || !rootArg) {
  console.error("Usage: repair-runtime.mjs repair <root>");
  process.exit(1);
}

const root = path.resolve(rootArg.replace(/^~(?=$|\/)/, process.env.HOME ?? "~"));
process.stdout.write(`${JSON.stringify(repair(root), null, 2)}\n`);
