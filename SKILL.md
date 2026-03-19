---
name: openclaw-cron-doctor
description: Use when OpenClaw cron jobs seem not to trigger, isolated cron runs never deliver results, the gateway port is occupied by another local app, or scheduled jobs start but fail because the default agent model is unavailable.
---

# OpenClaw Cron Doctor

## Overview

Repair the common local causes behind "cron does not trigger" in OpenClaw, then prove the fix with a real isolated one-shot cron smoke test.

This skill is for automatic repair first, verification second. Use it when the user wants the machine fixed, not just diagnosed.

## What It Fixes

- cron guidance missing from workspace `TOOLS.md` and `AGENTS.md`
- gateway port conflicts caused by a local GUI app occupying the OpenClaw port
- weak default agent model selection for cron execution
- false positives where cron actually schedules, but isolated execution fails silently

## Quick Start

Install and repair:

```bash
bash scripts/install.sh
```

Verify with a real smoke job:

```bash
bash scripts/verify.sh
```

## Workflow

1. Patch all detected OpenClaw roots with safer cron defaults.
2. Update workspace guidance files so future agent behavior matches the repaired runtime.
3. Detect a local app occupying the primary gateway port and politely quit it when it matches the known conflict pattern.
4. Restart the OpenClaw gateway when launchd exposes the standard `ai.openclaw.gateway` service.
5. Run a silent one-shot isolated cron job that writes a local marker file and auto-deletes after success.

## Files

- `scripts/install.sh`: idempotent repair entrypoint
- `scripts/verify.sh`: runtime smoke test
- `scripts/configure-openclaw.mjs`: safe config and workspace patcher
- `references/runtime-notes.md`: what the repair changes
- `references/troubleshooting.md`: what to check when verification still fails

## Guardrails

- Do not delete user data.
- Do not hardcode `timeoutSeconds=604800` as a magic fix.
- Do not force heartbeat where exact schedule or isolated execution is required.
- Do not claim cron is repaired until the smoke job succeeds.
