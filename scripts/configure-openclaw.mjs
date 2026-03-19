#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const TOOL_SECTION = `
## OpenClaw Cron Defaults

- Cron tasks should default to \`agentTurn\` with an isolated run.
- Let cron delivery handle output. The task body should directly return results instead of proactively calling the \`message\` tool.
- Prefer delivery modes such as \`announce\` when you want the result sent back to the channel.
- If the task needs main-session context or only does lightweight periodic checks, use heartbeat instead of cron.
- Do not cargo-cult \`timeoutSeconds=604800\`. Set an explicit timeout only when the job is truly long-running.
`;

const AGENT_INSERT_BLOCK = `
**Cron defaults:**

- Default to \`agentTurn\` plus an isolated run.
- Let cron delivery send the result. The task body should directly output the answer instead of proactively calling \`message\`.
- Prefer delivery modes such as \`announce\` when you want the result sent back to the user.
- If the task only needs lightweight polling or depends on live main-session context, use heartbeat instead.
- Do not assume \`timeoutSeconds=604800\` is a magic fix. Set a timeout intentionally only when the job is truly long-running.
`;

const AGENT_APPEND_BLOCK = `
## OpenClaw Cron Notes

- If this workspace is used by a cron task, default to \`agentTurn\` with an isolated run.
- Cron tasks should directly output results and let delivery handle sending them. Do not proactively call \`message\` unless a workflow explicitly requires it.
- Use cron for exact timing, one-shot reminders, or heavier isolated work. Use heartbeat for lightweight checks or tasks that depend on main-session context.
- Set \`timeoutSeconds\` intentionally for truly long jobs instead of assuming \`604800\` is the default fix.
`;

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function nowStamp() {
  return new Date().toISOString().replace(/[:.]/g, "-");
}

function backup(file) {
  const backupPath = `${file}.bak-${nowStamp()}-cron-doctor`;
  fs.copyFileSync(file, backupPath);
  return backupPath;
}

function collectModelNames(config) {
  const names = new Set();
  const providers = config?.models?.providers ?? {};
  for (const [providerId, provider] of Object.entries(providers)) {
    const models = Array.isArray(provider?.models) ? provider.models : [];
    for (const model of models) {
      if (typeof model?.id === "string" && model.id.trim()) {
        names.add(`${providerId}/${model.id.trim()}`);
      }
    }
  }
  return names;
}

function firstExisting(candidates, available) {
  for (const candidate of candidates) {
    if (available.has(candidate)) return candidate;
  }
  return null;
}

function patchConfig(root) {
  const file = path.join(root, "openclaw.json");
  if (!fs.existsSync(file)) {
    return { changed: false, reason: "missing openclaw.json" };
  }
  const config = readJson(file);
  const available = collectModelNames(config);
  const preferred = firstExisting(
    [
      "openai-codex/gpt-5.4",
      "openai/gpt-5.4",
      "google/[官逆B]gemini-3.1-pro-preview",
      "mama/[官逆B]gemini-3.1-pro-preview",
      "gemai-proxy/[官逆C]gemini-3-flash-preview"
    ],
    available
  );
  if (!preferred) {
    return { changed: false, reason: "no preferred runtime model found" };
  }

  config.agents ??= {};
  config.agents.defaults ??= {};
  config.agents.defaults.model ??= {};
  config.agents.defaults.models ??= {};

  const fallbackCandidates = [
    "openai/gpt-5.4",
    "google/[官逆B]gemini-3.1-pro-preview",
    "mama/[官逆B]gemini-3.1-pro-preview",
    "gemai-proxy/[官逆C]gemini-3-flash-preview"
  ].filter((item) => available.has(item) && item !== preferred);

  const before = JSON.stringify(config.agents.defaults.model);
  config.agents.defaults.model.primary = preferred;
  config.agents.defaults.model.fallbacks = [...new Set(fallbackCandidates)].slice(0, 3);

  if (available.has("openai-codex/gpt-5.4")) {
    config.agents.defaults.models["openai-codex/gpt-5.4"] ??= { params: { transport: "sse" } };
  }
  config.agents.defaults.models[preferred] ??= {};

  const after = JSON.stringify(config.agents.defaults.model);
  if (before === after) {
    return { changed: false, reason: "default model already patched", primary: preferred };
  }

  const backupPath = backup(file);
  writeJson(file, config);
  return { changed: true, primary: preferred, backupPath };
}

function patchTools(workspace) {
  const file = path.join(workspace, "TOOLS.md");
  if (!fs.existsSync(file)) return { changed: false, reason: "missing TOOLS.md" };
  const content = fs.readFileSync(file, "utf8");
  if (content.includes("## OpenClaw Cron Defaults")) return { changed: false, reason: "already patched" };
  const marker = "\n## Why Separate?";
  if (!content.includes(marker)) return { changed: false, reason: "marker not found" };
  const next = content.replace(marker, `\n${TOOL_SECTION}${marker}`);
  fs.writeFileSync(file, next);
  return { changed: true };
}

function patchAgents(workspace) {
  const file = path.join(workspace, "AGENTS.md");
  if (!fs.existsSync(file)) return { changed: false, reason: "missing AGENTS.md" };
  const content = fs.readFileSync(file, "utf8");
  if (content.includes("**Cron defaults:**") || content.includes("## OpenClaw Cron Notes")) {
    return { changed: false, reason: "already patched" };
  }
  const tipMarker =
    "\n**Tip:** Batch similar periodic checks into `HEARTBEAT.md` instead of creating multiple cron jobs. Use cron for precise schedules and standalone tasks.";
  let next;
  if (content.includes(tipMarker)) {
    next = content.replace(tipMarker, `\n${AGENT_INSERT_BLOCK}${tipMarker}`);
  } else {
    next = `${content.trimEnd()}\n\n${AGENT_APPEND_BLOCK}\n`;
  }
  fs.writeFileSync(file, next);
  return { changed: true };
}

function workspaceDirs(root) {
  const dirs = [];
  if (!fs.existsSync(root)) return dirs;
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    if (entry.name === "workspace" || entry.name.startsWith("workspace-")) {
      dirs.push(path.join(root, entry.name));
    }
  }
  return dirs.sort();
}

function patchRoot(root) {
  const result = {
    root,
    config: patchConfig(root),
    workspaces: []
  };
  for (const workspace of workspaceDirs(root)) {
    result.workspaces.push({
      workspace,
      tools: patchTools(workspace),
      agents: patchAgents(workspace)
    });
  }
  return result;
}

function printRuntime(root) {
  const file = path.join(root, "openclaw.json");
  const config = readJson(file);
  const port = config?.gateway?.port ?? 18789;
  const token = config?.gateway?.auth?.token ?? "";
  const primary = config?.agents?.defaults?.model?.primary ?? "";
  process.stdout.write(`${JSON.stringify({ root, port, token, primary }, null, 2)}\n`);
}

const [, , command, rootArg] = process.argv;

if (!command || !rootArg) {
  console.error("Usage: configure-openclaw.mjs <patch|runtime> <root>");
  process.exit(1);
}

const root = path.resolve(rootArg.replace(/^~(?=$|\/)/, process.env.HOME ?? "~"));

if (command === "patch") {
  process.stdout.write(`${JSON.stringify(patchRoot(root), null, 2)}\n`);
} else if (command === "runtime") {
  printRuntime(root);
} else {
  console.error(`Unknown command: ${command}`);
  process.exit(1);
}
