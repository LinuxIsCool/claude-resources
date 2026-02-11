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
| `scripts/sync-registry.sh` | Sync disk state → registry.yaml |
| `scripts/restore-resources.sh` | Clone registry entries → disk |
| `scripts/status-all.sh` | Git status across all repos |
| `scripts/add-resource.sh` | Clone a repo and register it |

All scripts resolve paths using:
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
RESOURCES="$(cd "${PLUGIN_ROOT}/../.." && pwd)"
REGISTRY="${RESOURCES}/registry.yaml"
```

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
