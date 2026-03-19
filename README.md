[![中文](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-0F172A?style=flat-square)](./README.md)
[![English](https://img.shields.io/badge/README-English-E5E7EB?style=flat-square&logoColor=111827)](./README.en.md)
[![Install](https://img.shields.io/badge/Install-Codex%20Skill-2563EB?style=flat-square)](#安装)
[![Structure](https://img.shields.io/badge/Docs-目录结构-0891B2?style=flat-square)](#目录结构)
[![Release](https://img.shields.io/github/v/release/harrymarin/openclaw-cron-doctor?style=flat-square)](https://github.com/harrymarin/openclaw-cron-doctor/releases)
[![License](https://img.shields.io/github/license/harrymarin/openclaw-cron-doctor?style=flat-square)](./LICENSE)

# OpenClaw Cron Doctor

一键修复并验证 OpenClaw 定时任务“不触发”的常见本地问题。

## 快速导航

- [它解决什么](#它解决什么)
- [快速开始](#快速开始)
- [安装](#安装)
- [使用示例](#使用示例)
- [运行规则](#运行规则)
- [目录结构](#目录结构)

## 它解决什么

- 工作区缺少 cron 约定，导致 agent 行为持续配错
- 本地 GUI 应用抢占 OpenClaw gateway 端口
- 默认模型不可用，导致 cron 明明调度了却执行失败
- cron 实际执行了，但因为本地状态刷新或日志噪音，看起来像“没触发”

## 快速开始

1. 把仓库拷到本地，或者下载 release zip 解压。
2. 把 skill 放到 `~/.codex/skills/openclaw-cron-doctor`。
3. 运行安装脚本修复本机。
4. 运行验证脚本确认 cron 真的能执行。

```bash
bash scripts/install.sh
bash scripts/verify.sh
```

## 安装

把本仓库复制到 Codex skills 目录：

```bash
cp -R openclaw-cron-doctor ~/.codex/skills/openclaw-cron-doctor
```

如果你是从 release zip 安装，解压后保持目录名为 `openclaw-cron-doctor/` 即可。

## 使用示例

修复当前机器上的 OpenClaw / QClaw / peer 运行态：

```bash
bash scripts/install.sh
```

挂一个真实的 one-shot isolated cron 做 smoke test：

```bash
bash scripts/verify.sh
```

成功时你会看到类似输出：

```text
Smoke verification succeeded.
CRON_SMOKE_OK 2026-03-19T12:37:00Z
```

## 运行规则

- cron 默认使用 `agentTurn + isolated`
- cron 任务体直接输出结果，不主动调 `message`
- 需要主会话上下文或轻量轮询时优先用 heartbeat
- 不把 `timeoutSeconds=604800` 当成通用修复公式

## 它具体做了什么

1. 扫描 `~/.openclaw`、`~/.qclaw`、`~/.openclaw-peer`
2. 修补 `openclaw.json` 里的默认模型和回退模型
3. 把更稳的 cron 规则写进工作区 `TOOLS.md` / `AGENTS.md`
4. 识别已知端口冲突并重启标准 gateway
5. 创建静默 one-shot cron，验证“调度 + 隔离执行 + 结果落地”完整链路
6. 如果 `deleteAfterRun` 状态刷新慢，自动清理 stale job

## 目录结构

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
    └── verify.sh
```

## License

MIT
