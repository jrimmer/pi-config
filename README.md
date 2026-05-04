# pi-config

Personal pi coding agent configuration — skills, models, and preferences.

## What's Here

| Path | Description |
|------|-------------|
| `skills/` | Custom pi skills (e.g., `supe-*`, `pr-review`, etc.) |
| `models.json` | Custom model providers and configurations |
| `settings.json` | Pi preferences and installed packages |
| `install.sh` | One-command symlink installer |

## Skills Inventory

| Skill | Description |
|-------|-------------|
| `go-ts-contract` | Validates API contract alignment between Go backend handlers and TypeScript frontend callers |
| `migration-audit` | Audits "delete TS / create Go" migration PRs for behavioral regressions and lost side effects |
| `pr-review` | Automated PR review pipeline — fetches diffs, analyzes for adverse findings, posts via `gh` |
| `supe-design` | Design-first hard gate — explores requirements, produces approved spec before any code |
| `supe-plan` | Breaks approved spec into bite-sized tasks with exact file paths and verification steps |
| `supe-implement` | Orchestrates parallel workers (TDD discipline) → tests → dual-model review → merge/PR options |

**Inspired by [obra/superpowers](https://github.com/obra/superpowers)** — a software development methodology that shapes agent behavior through rigid workflows. These skills are ported to pi's native tooling (subagents, taskplan, orchestration) rather than being a 1:1 copy.

**Light vs Dark mode:**
- **Light** — manual gates between phases. Each step waits for your approval before continuing. Good for complex, uncertain, or high-stakes work where you want to steer direction.
- **Dark** — auto-flow from plan → implement → review with no human-in-the-loop until the final merge/PR decision. Good for well-understood tasks where you trust the process and want to minimize interruptions.

## Extensions Inventory

| Extension | Link |
|-----------|------|
| `npm:pi-subagents` | [npmjs.com/package/pi-subagents](https://www.npmjs.com/package/pi-subagents) |
| `npm:context-mode` | [npmjs.com/package/context-mode](https://www.npmjs.com/package/context-mode) |
| `npm:@a5c-ai/babysitter-pi` | [npmjs.com/package/@a5c-ai/babysitter-pi](https://www.npmjs.com/package/@a5c-ai/babysitter-pi) |
| `npm:taskplane` | [npmjs.com/package/taskplane](https://www.npmjs.com/package/taskplane) |
| `npm:pi-web-access` | [npmjs.com/package/pi-web-access](https://www.npmjs.com/package/pi-web-access) |
| `npm:pi-markdown-preview` | [npmjs.com/package/pi-markdown-preview](https://www.npmjs.com/package/pi-markdown-preview) |
| `npm:@samfp/pi-memory` | [npmjs.com/package/@samfp/pi-memory](https://www.npmjs.com/package/@samfp/pi-memory) |
| `npm:pi-lens` | [npmjs.com/package/pi-lens](https://www.npmjs.com/package/pi-lens) |
| `npm:@juicesharp/rpiv-ask-user-question` | [npmjs.com/package/@juicesharp/rpiv-ask-user-question](https://www.npmjs.com/package/@juicesharp/rpiv-ask-user-question) |
| `npm:@juicesharp/rpiv-advisor` | [npmjs.com/package/@juicesharp/rpiv-advisor](https://www.npmjs.com/package/@juicesharp/rpiv-advisor) |
| `npm:@juicesharp/rpiv-btw` | [npmjs.com/package/@juicesharp/rpiv-btw](https://www.npmjs.com/package/@juicesharp/rpiv-btw) |

## Prerequisites

This repo uses **environment variable references** for API keys. Before running pi, export:

```bash
export OLLAMA_CLOUD_API_KEY="your-key-here"
export ZAI_API_KEY="your-key-here"
```

Add these to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.) so they're always available.

**Never commit literal API keys.** `models.json` references env vars by name. The `.gitignore` blocks `auth.json` and has explicit warnings about secrets.

## Installation

```bash
git clone <this-repo> ~/pi-config
cd ~/pi-config
./install.sh
```

Then restart pi if it's running.

## Adding a New Skill

1. Create the skill directory under `skills/`
2. Add `SKILL.md` following pi's skill format
3. Commit and push
4. Run `./install.sh` (or just let the symlink do its work)

## Editing Live

Skills are **symlinked** into `~/.pi/agent/skills/`, so edits in this repo are live immediately. No reinstall needed after the initial setup.

## What's NOT Tracked

| File | Why |
|------|-----|
| `auth.json` | Contains API keys and tokens |
| `sessions/` | Transient session state |
| `run-history.jsonl` | Logs |
| `taskplane/` | Project-specific staged tasks |

These live only in `~/.pi/agent/` and are excluded by `.gitignore`.
