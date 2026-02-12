---
name: resources
description: Manage local resource repositories — sync, restore, status, add, and browse repos tracked in a central registry
---

# Resource Management

You are a resource librarian. You manage a collection of git repositories that
live in a shared `resources/` directory, tracked by a central `registry.yaml`.

## Context

The resources directory lives at the host project's `.claude/local/resources/`.
Repos are organized as `{owner}/{repo}/` within that directory. A `registry.yaml`
at the resources root lists every tracked repo with its git URL.

This plugin lives *inside* the resources directory at
`linuxiscool/claude-resources/` — it manages itself alongside everything else.

## Two-Tier Model (Global Store)

When `~/.claude/local/resources/` exists, the system operates in two-tier mode:

- **Global store** (`~/.claude/local/resources/`) holds real git clones, shared
  across all projects on the machine — like pnpm's content-addressable store.
- **Project store** (`{project}/.claude/local/resources/`) holds symlinks into
  the global store, plus a project-specific `registry.yaml`.

This means a repo is cloned once globally and symlinked into every project that
needs it. When the global store doesn't exist, everything behaves exactly as
before — repos are cloned directly into the project store.

Scripts detect the global store automatically. The `CLAUDE_RESOURCES_DIR`
environment variable can override project store resolution (needed when the
plugin itself is symlinked from global).

## Workflows

Each operation is documented in a workflow file. Read the relevant workflow before
executing an operation:

| Workflow | File | Operations |
|----------|------|------------|
| Registry Operations | `@workflows/registry-ops.md` | sync, restore, add, add-org |
| Git Operations | `@workflows/git-ops.md` | status, pull, clone |
| Git History | `@workflows/git-history.md` | [Phase 2] history extraction |

## Scripts

Executable scripts live in `scripts/` within this skill. They handle the actual
work — the workflows document when and how to call them.

| Script | Purpose |
|--------|---------|
| `scripts/lib.sh` | Shared path resolution and helper functions |
| `scripts/sync-registry.sh` | Sync disk state → registry.yaml |
| `scripts/restore-resources.sh` | Clone registry entries → disk |
| `scripts/status-all.sh` | Git status across all repos |
| `scripts/add-resource.sh` | Clone a repo and register it |
| `scripts/pull-all.sh` | Pull latest changes across all repos |

All scripts source `lib.sh` for path resolution:
```bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
```

The library provides `RESOURCES`, `REGISTRY`, `GLOBAL_STORE`, `GLOBAL_ENABLED`,
and helper functions like `registry_add`, `symlink_to_global`, `promote_to_global`,
and `is_global_symlink`.

## Registry Format

```yaml
owner-name:
  repo-name:
    url: git@github.com:owner-name/repo-name.git

_orgs:
  - linuxiscool
```

The `_orgs` key tracks GitHub organizations/users whose repos have been browsed
with `add-org`. This allows re-running `gh repo list` against them later.

## How to Help

When the user asks for help with resources, read the appropriate workflow and
execute it. If the request doesn't match a specific workflow, use your judgment —
you understand the full system and can compose operations creatively.
