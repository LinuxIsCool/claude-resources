---
name: resources
description: Manage local resource repositories — sync, restore, status, add, seed, and drive-sync repos tracked in a central registry
---

# Resource Management

You are a resource librarian. You manage a collection of git repositories that
live in a shared `resources/` directory, tracked by a central `registry.yaml`.

## Context

The resources directory lives at the host project's `.claude/local/resources/`.
Repos are organized as `{owner}/{repo}/` within that directory. A `registry.yaml`
at the resources root lists every tracked repo with its git URL and optional tags.

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

## Drive Sync

The local library can be mirrored to a data drive for backup and cross-machine
bootstrapping. See the Drive Sync section in `@workflows/git-ops.md`.

Default drive path: `/mnt/data-24tb/52_Libraries/git/`
Override: `CLAUDE_RESOURCES_DRIVE` environment variable.

## Workflows

Each operation is documented in a workflow file. Read the relevant workflow before
executing an operation:

| Workflow | File | Operations |
|----------|------|------------|
| Registry Operations | `@workflows/registry-ops.md` | sync, restore, add, add-org, seed |
| Git Operations | `@workflows/git-ops.md` | status, pull, clone, drive sync |
| Git History | `@workflows/git-history.md` | [Phase 2] history extraction |

## Scripts

Executable scripts live in `scripts/` within this skill. They handle the actual
work — the workflows document when and how to call them.

| Script | Purpose |
|--------|---------|
| `scripts/lib.sh` | Shared path resolution, tags, drive store helpers |
| `scripts/sync-registry.sh` | Sync disk state → registry.yaml |
| `scripts/restore-resources.sh` | Clone registry entries → disk |
| `scripts/status-all.sh` | Git status across all repos |
| `scripts/add-resource.sh` | Clone a repo and register it |
| `scripts/pull-all.sh` | Pull latest changes across all repos |
| `scripts/seed-from-github.sh` | Bulk populate registry from GitHub orgs |
| `scripts/sync-to-drive.sh` | rsync local library → data drive |
| `scripts/sync-from-drive.sh` | rsync data drive → local library |

All scripts source `lib.sh` for path resolution:
```bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
```

The library provides `RESOURCES`, `REGISTRY`, `GLOBAL_STORE`, `GLOBAL_ENABLED`,
`DRIVE_STORE`, and helper functions like `registry_add`, `registry_list_by_tag`,
`symlink_to_global`, `promote_to_global`, `is_global_symlink`, and
`ensure_drive_store`.

## Registry Format

```yaml
owner-name:
  repo-name:
    url: git@github.com:owner-name/repo-name.git
    tags: [active, owned]

_orgs:
  - linuxiscool
```

The `tags` field is an inline YAML list at 4-space indent (same level as `url:`).
Tags are optional — repos without tags work exactly as before.

The `_orgs` key tracks GitHub organizations/users whose repos have been browsed
with `add-org` or seeded with `seed`. This allows re-running against them later.

## Tag Filtering

Scripts that iterate over repos support `--tag=<tag>`:
- `status-all.sh --tag=active` — only show active repos
- `pull-all.sh --tag=owned` — only pull owned repos
- `restore-resources.sh --tag=venture` — only clone venture repos

## How to Help

When the user asks for help with resources, read the appropriate workflow and
execute it. If the request doesn't match a specific workflow, use your judgment —
you understand the full system and can compose operations creatively.
