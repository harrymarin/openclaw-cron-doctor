# Runtime Notes

## What The Installer Changes

- patches `agents.defaults.model.primary` toward `openai-codex/gpt-5.4` when that model exists
- adds practical fallbacks such as `openai/gpt-5.4` and `google/[官逆B]gemini-3.1-pro-preview` when available
- injects cron guidance into detected workspace `TOOLS.md`
- injects cron guidance into detected workspace `AGENTS.md`

## Why

The recurring failure pattern is usually not "cron never ran". It is one of:

- the gateway never owned the expected port
- cron spawned an isolated session but the default model failed to serve
- the job used cron plus proactive `message`, creating confusing delivery behavior

## Expected Success Signal

After `bash scripts/verify.sh` succeeds:

- `openclaw cron list` returns successfully
- the smoke file contains a `CRON_SMOKE_OK ...` line
- the one-shot smoke job no longer appears in the cron catalog
