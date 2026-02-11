# Git History Extraction

**Status: Phase 2 — not yet implemented.**

This workflow will extract git history from all tracked repos into a SQLite
database for force-directed graph temporal visualizations.

## Planned Capabilities

- Extract commits, authors, timestamps, and file changes from all repos
- Build co-modification graphs (files that change together)
- Track author collaboration patterns across repos
- Generate temporal snapshots for animation

## Database

Schema will live in `db/schema.sql`. The database file itself will be gitignored.

## Visualization

The extracted data is intended for force-directed graph visualizations that show
how the resource collection evolves over time — which repos are active, which
files change together, and how authors move between projects.
