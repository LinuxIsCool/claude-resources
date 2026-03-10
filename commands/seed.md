---
name: seed
description: Populate registry from GitHub orgs (registry only, no cloning)
allowed-tools: Bash, Read
args: orgs
---

Read the resources skill at `${CLAUDE_PLUGIN_ROOT}/skills/resources/SKILL.md`,
then run the seed script.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/resources/scripts/seed-from-github.sh" $ARGUMENTS
```

If no arguments are provided, the script uses default orgs.
Present the summary and suggest running `/claude-resources:restore --tag=owned` next.
