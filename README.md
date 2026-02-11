# claude-resources

A Claude Code plugin for managing local resource repositories.

Resources are git repositories cloned into a shared directory and tracked by a
central `registry.yaml`. This plugin provides commands to sync, restore, inspect,
and add resources — replacing ad-hoc scripts with a structured, self-hosting
plugin that lives inside the directory it manages.


## Commands

| Command | Description |
|---------|-------------|
| `/claude-resources:sync` | Sync registry with repos on disk |
| `/claude-resources:restore` | Clone all repos listed in registry |
| `/claude-resources:status` | Git status across all repos |
| `/claude-resources:add` | Clone a repo and add it to registry |
| `/claude-resources:add-org` | Browse an org's repos and select which to clone |


## How It Works

A `registry.yaml` file at the resources root lists every tracked repository by
owner and name. Scripts scan the disk and the registry to keep them in agreement:

- **sync** finds repos on disk that aren't in the registry and adds them
- **restore** clones repos from the registry that aren't on disk
- **status** runs `git status` across every repo for a quick health check
- **add** clones a single repo and registers it in one step
- **add-org** fetches an org's repo list via `gh` and lets you pick which to clone


## Architecture

```
skills/resources/
├── SKILL.md                    Master skill — workflow index and context
├── workflows/
│   ├── registry-ops.md         Sync, restore, add operations
│   ├── git-ops.md              Status, pull, clone across repos
│   └── git-history.md          [Phase 2] History extraction for visualizations
└── scripts/
    ├── sync-registry.sh        Sync disk → registry
    ├── restore-resources.sh    Clone registry → disk
    ├── status-all.sh           Git status across all repos
    └── add-resource.sh         Clone + register in one step
```

The skill contains everything. Commands are 5-line markdown files that load the
appropriate workflow and execute it. The librarian agent loads the full skill and
helps with whatever you need.


## Self-Hosting

This plugin is itself a resource. It appears in `registry.yaml` as
`linuxiscool/claude-resources` and is cloned alongside everything else during
`restore`. The plugin manages itself.


## Phase 2 (Planned)

Git history extraction for force-directed graph temporal visualizations. A SQLite
database will store commits, file changes, and co-modification patterns across all
tracked repos.
