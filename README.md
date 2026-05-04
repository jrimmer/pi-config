# pi-config

Personal pi coding agent configuration — skills, models, and preferences.

## What's Here

| Path | Description |
|------|-------------|
| `skills/` | Custom pi skills (e.g., `supe-*`, `pr-review`, etc.) |
| `models.json` | Custom model providers and configurations |
| `settings.json` | Pi preferences and installed packages |
| `install.sh` | One-command symlink installer |

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
