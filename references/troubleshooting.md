# Troubleshooting

## Verification Still Fails

### `gateway token mismatch`

- confirm the process listening on the OpenClaw gateway port is actually the OpenClaw gateway
- check whether another GUI app is occupying the same port
- restart the launchd service if `ai.openclaw.gateway` exists

### Cron starts but session errors

- inspect the newest session file under `~/.openclaw/agents/main/sessions/*.jsonl`
- look for model-distributor errors, invalid auth tokens, or tool failures

### Smoke job stays in `runningAtMs`

- the scheduler worked; isolated execution is now the problem
- inspect the newest cron child session and gateway logs

### Plugins warn during checks

Non-fatal plugin warnings do not block cron verification unless they crash the gateway or break model execution.
