# Git Operations

Operations that work across multiple repos simultaneously.


## Status

Show git status for every repo in the resources directory.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/status-all.sh"
```

Use `--short` to only show dirty repos and those out of sync with upstream.

Reports per-repo:
- `clean` / `dirty` — working tree state
- `ahead N` — local commits not pushed
- `behind N` — remote commits not pulled
- `no upstream` — no tracking branch configured


## Pull All

Pull latest changes across all repos. This is a Claude-driven workflow, not a
script, because it benefits from judgment about conflicts and errors.

### Procedure

1. Run status-all.sh to identify repos with upstream tracking
2. For each clean repo with a tracking branch, run `git -C <path> pull --ff-only`
3. Skip dirty repos — report them so the user can handle manually
4. Report results: pulled, skipped, failed


## Clone

Clone a specific repo. This is the underlying operation used by add and restore.

```bash
git clone <url> <resources-dir>/<owner>/<repo>
```

Always create the owner directory first with `mkdir -p`.
