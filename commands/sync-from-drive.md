---
name: sync-from-drive
description: Restore local resource library from data drive
allowed-tools: Bash, Read
---

Read the resources skill at `${CLAUDE_PLUGIN_ROOT}/skills/resources/SKILL.md`,
then run the sync-from-drive script.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/sync-from-drive.sh" $ARGUMENTS
```

Present the results and remind the user to run `/claude-resources:sync` afterward
to update registry.yaml.
