# claude-resources

A Claude Code plugin for managing local resource repositories. Tracks repos in a
central registry, syncs disk state with the registry, and provides commands for
common operations across the collection.

@README.md

## Architecture

The skill is the workhorse. All logic, scripts, and workflows live inside
`skills/resources/`. Commands are thin interfaces that route to specific
workflows within the skill. The librarian agent loads the full skill and acts
as a general assistant for resource work.

```
skills/resources/SKILL.md          Master skill with workflow index
skills/resources/workflows/        Operation documentation
skills/resources/scripts/          Executable bash scripts
commands/                          Thin interfaces → skill workflows
agents/librarian.md                General assistant
```
