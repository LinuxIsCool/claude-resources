# Git Operations

Operations that work across multiple repos simultaneously.


## Status

Show git status for every repo in the resources directory.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/status-all.sh"
```

Flags:
- `--short`, `-s` — only show dirty repos and those out of sync with upstream
- `--fetch`, `-f` — run `git fetch` before checking ahead/behind (reveals staleness against remote)

Reports per-repo:
- `clean` / `dirty` — working tree state
- `→` / ` ` — symlinked from global store / local clone
- `ahead N` — local commits not pushed
- `behind N` — remote commits not pulled
- `no upstream` — no tracking branch configured

Also detects and reports broken symlinks.


## Pull All

Pull latest changes across all repos using fast-forward only.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/pull-all.sh"
```

Accepts an optional `owner/repo` argument to pull only one specific repo.

When the global store exists, pull operates there — one pull updates the repo
for all projects that symlink to it. Otherwise operates on the project store.

Behavior:
- Skips dirty repos (report them so the user can handle manually)
- Skips repos without an upstream tracking branch
- Uses `git pull --ff-only` for safety (no merge commits)
- Reports pulled, skipped, and failed counts


## Clone

Clone a specific repo. This is the underlying operation used by add and restore.

```bash
git clone <url> <resources-dir>/<owner>/<repo>
```

Always create the owner directory first with `mkdir -p`.
