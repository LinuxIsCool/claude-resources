---
name: add-org
description: Browse a GitHub org's repos and select which to clone
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
args: org
---

Read the resources skill at `${CLAUDE_PLUGIN_ROOT}/skills/resources/SKILL.md`,
then follow the **Add Org** section in the registry-ops workflow.

The org name is: `$ARGUMENTS`

If no argument is provided, ask the user which GitHub org or user to browse.

This is an interactive workflow:
1. Fetch repos with `gh repo list <org> --json name,description,url --limit 100`
2. Present repos to the user with `AskUserQuestion` using `multiSelect: true`
3. Clone each selected repo using the add script
4. Add the org to `_orgs` in registry.yaml if not already present
