# Git Operations

Operations that work across multiple repos simultaneously.

All scripts support `--tag=<tag>` to filter by registry tag.


## Status

Show git status for every repo in the resources directory.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/status-all.sh"
```

Flags:
- `--short`, `-s` — only show dirty repos and those out of sync with upstream
- `--fetch`, `-f` — run `git fetch` before checking ahead/behind (reveals staleness against remote)
- `--tag=<tag>` — only show repos matching this tag in registry.yaml

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

Flags:
- `owner/repo` — optional, pull only this specific repo
- `--tag=<tag>` — only pull repos matching this tag

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


## Drive Sync

Mirror the local resource library to/from the data drive for backup and
cross-machine bootstrapping.

### Sync to Drive

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/sync-to-drive.sh"
```

- Uses `rsync --delete` — drive is an exact mirror of the local library
- Source: global store if exists, else project store
- Excludes `.claude/` directories
- Supports `--dry-run` / `-n` for preview

### Sync from Drive

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/sync-from-drive.sh"
```

- **NO `--delete`** — safety, never removes local repos not on the drive
- Target: always the global store (`~/.claude/local/resources/`)
- Supports `--dry-run` / `-n` for preview
- After restoring, run `/claude-resources:sync` to update registry.yaml

### Safety Asymmetry

The two directions are intentionally asymmetric:
- **To drive**: `--delete` ensures the drive is a clean mirror
- **From drive**: no `--delete` preserves any local-only repos

### Drive Path

Default: `/mnt/data-24tb/52_Libraries/git/`

Override with `CLAUDE_RESOURCES_DRIVE` environment variable.
