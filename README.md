# OpenClaw Cron Doctor

Auto-fix and verify the most common local causes behind "OpenClaw cron does not trigger".

## What It Fixes

- missing cron guidance in workspace `TOOLS.md` and `AGENTS.md`
- gateway port conflicts caused by another local app occupying the OpenClaw port
- weak default model selection that makes isolated cron runs fail after scheduling
- false positives where cron schedules correctly but execution silently fails

## What It Does

1. Patches detected OpenClaw roots such as `~/.openclaw`, `~/.qclaw`, and `~/.openclaw-peer`
2. Writes safer cron guidance into workspace docs
3. Detects the common local GUI port-conflict pattern and restarts the standard launchd gateway
4. Runs a real silent one-shot isolated cron smoke test
5. Cleans up a stale cron entry if the job executed but `deleteAfterRun` state refresh lags

## Install

Copy this folder into your Codex skills directory:

```bash
cp -R openclaw-cron-doctor-release ~/.codex/skills/openclaw-cron-doctor
```

Or keep the repo checked out anywhere and run the scripts directly.

## Usage

Repair and patch the local machine:

```bash
bash scripts/install.sh
```

Verify with a real cron smoke job:

```bash
bash scripts/verify.sh
```

## Notes

- This skill does not treat `timeoutSeconds=604800` as a magic fix.
- It prefers `agentTurn + isolated` for cron and expects the task body to return results directly instead of proactively calling `message`.
- It treats heartbeat as the better tool for lightweight polling or tasks that depend on main-session context.

## Repository Layout

```text
.
├── SKILL.md
├── agents/
├── references/
└── scripts/
```

## License

MIT
