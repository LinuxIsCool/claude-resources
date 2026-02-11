---
name: add
description: Clone a repo and add it to registry
allowed-tools: Bash, Read, Edit, Write
args: repo
---

Read the resources skill at `${CLAUDE_PLUGIN_ROOT}/skills/resources/SKILL.md`,
then follow the **Add** section in the registry-ops workflow.

Run the add script with the user's argument: `$ARGUMENTS`

If no argument is provided, ask the user for an `owner/repo` or git URL.
