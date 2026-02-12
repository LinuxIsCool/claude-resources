# Registry Operations

Operations that keep `registry.yaml` and the resources directory in agreement.

All scripts are global-store aware. When `~/.claude/local/resources/` exists,
they clone to the global store and symlink into the project. When it doesn't
exist, they operate on the project store directly (original behavior).


## Sync

Scan disk for repos not in the registry and add them. Also report registry entries
with no corresponding directory on disk.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/sync-registry.sh"
```

Use `--verbose` to see every repo, not just additions and gaps.

When the global store is enabled, sync automatically **promotes** real clones: it
moves them to the global store and replaces them with symlinks. This is safe and
idempotent — the remote URL is preserved, and the global registry is updated.

Sync also detects and reports broken symlinks (repos that were removed from the
global store but still have symlinks in the project).

After syncing, review the output. If repos were added, check that the URLs look
correct. If repos are missing, the user may want to run restore.


## Restore

Clone every repo in the registry that isn't already on disk.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/restore-resources.sh"
```

This is the primary way to set up a fresh machine or recover after deletions. It
reads `registry.yaml` top to bottom and clones each missing repo.

When the global store exists, restore clones into the global store and symlinks
into the project. If a repo already exists in the global store (cloned by another
project), it just creates the symlink — no redundant clone.


## Add

Clone a single repo and register it in one step.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/add-resource.sh" <owner/repo>
```

Accepts `owner/repo` shorthand or full git URLs. When the global store exists,
clones there and symlinks into the project. Registers in both project and global
registries.


## Add Org

Browse a GitHub organization's repos and interactively select which to clone.
This workflow is driven by Claude, not by a script.

### Procedure

1. Accept a GitHub org/user name as argument
2. Fetch repos: `gh repo list <org> --json name,description,url --limit 100`
3. Present the list to the user via `AskUserQuestion` with `multiSelect: true`
4. For each selected repo, run the add script
5. Add the org to the `_orgs` list in `registry.yaml` for future re-scanning

### Org Tracking

The `_orgs` key in `registry.yaml` tracks organizations that have been browsed:

```yaml
_orgs:
  - linuxiscool
  - gaiaaiagent
```

This enables re-running `add-org` against known orgs to discover new repos.
When adding an org, check if it's already in the list before appending.
