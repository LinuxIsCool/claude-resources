---
name: status
description: Show git status across all resource repos
allowed-tools: Bash, Read
---

Read the resources skill at `${CLAUDE_PLUGIN_ROOT}/skills/resources/SKILL.md`,
then follow the **Status** section in the git-ops workflow.

Run the status script and present the results to the user.

Pass `--tag=<tag>` to filter by registry tag (e.g., `--tag=active`).
Forward any flags from `$ARGUMENTS` to the script.
