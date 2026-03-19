[![中文](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-E5E7EB?style=flat-square)](./README.md)
[![English](https://img.shields.io/badge/README-English-0F172A?style=flat-square)](./README.en.md)
[![Install](https://img.shields.io/badge/Install-Codex%20Skill-2563EB?style=flat-square)](#installation)
[![Structure](https://img.shields.io/badge/Docs-Structure-0891B2?style=flat-square)](#structure)
[![Release](https://img.shields.io/github/v/release/harrymarin/openclaw-cron-doctor?style=flat-square)](https://github.com/harrymarin/openclaw-cron-doctor/releases)
[![License](https://img.shields.io/github/license/harrymarin/openclaw-cron-doctor?style=flat-square)](./LICENSE)

# OpenClaw Cron Doctor

Auto-fix and verify the most common local causes behind "OpenClaw cron does not trigger".

## Quick Navigation

- [What It Fixes](#what-it-fixes)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage Example](#usage-example)
- [Runtime Rules](#runtime-rules)
- [Structure](#structure)

## What It Fixes

- missing cron guidance that keeps agent behavior misconfigured
- gateway port conflicts caused by another local GUI app
- unavailable default models that make isolated cron runs fail after scheduling
- false negatives where cron actually executed but logs or stale state make it look broken

## Quick Start

1. Clone the repo or download the release zip.
2. Put the skill under `~/.codex/skills/openclaw-cron-doctor`.
3. Run the installer for your platform.
4. Run the matching verifier to prove cron really executes.

```bash
bash scripts/install.sh
bash scripts/verify.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
```

## Installation

Copy this repository into your Codex skills directory:

```bash
cp -R openclaw-cron-doctor ~/.codex/skills/openclaw-cron-doctor
```

If you install from the release zip, keep the extracted folder name as `openclaw-cron-doctor/`.

Windows users can run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
```

## Usage Example

Repair the local OpenClaw / QClaw / peer runtime:

```bash
bash scripts/install.sh
```

Run a real silent one-shot isolated cron smoke test:

```bash
bash scripts/verify.sh
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
```

Typical success output:

```text
Smoke verification succeeded.
CRON_SMOKE_OK 2026-03-19T12:37:00Z
```

## Runtime Rules

- default cron shape is `agentTurn + isolated`
- cron tasks should return results directly instead of proactively calling `message`
- use heartbeat when main-session context or lightweight polling matters
- do not treat `timeoutSeconds=604800` as a magic fix

## What It Does

1. scans `~/.openclaw`, `~/.qclaw`, and `~/.openclaw-peer`
2. patches safer primary and fallback models in `openclaw.json`
3. writes stronger cron guidance into workspace `TOOLS.md` and `AGENTS.md`
4. detects the known local port-conflict pattern on macOS and Windows
5. creates a silent one-shot cron to verify scheduling, isolated execution, and result delivery
6. cleans up a stale cron entry if `deleteAfterRun` state refresh lags

## Structure

```text
.
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   ├── runtime-notes.md
│   └── troubleshooting.md
└── scripts/
    ├── configure-openclaw.mjs
    ├── install.sh
    ├── install.ps1
    ├── repair-runtime.mjs
    └── verify.sh
    └── verify.ps1
```

## License

MIT
