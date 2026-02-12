#!/usr/bin/env bash
# Clone a repo and add it to registry.yaml in one step
#
# Accepts either a full git URL or an owner/repo shorthand.
# Clones into the resources directory and adds the entry to the registry.
#
# When a global store exists (~/.claude/local/resources/), clones there
# and symlinks into the project store.
#
# Usage: add-resource.sh <owner/repo | git-url>
#
# Examples:
#   add-resource.sh linuxiscool/new-project
#   add-resource.sh git@github.com:linuxiscool/new-project.git
#   add-resource.sh https://github.com/linuxiscool/new-project.git

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [ -z "${1:-}" ]; then
  echo "Usage: add-resource.sh <owner/repo | git-url>"
  exit 1
fi

input="$1"

# Parse input into owner, repo, and url
if [[ "$input" =~ ^([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
  url="git@github.com:${owner}/${repo}.git"
elif [[ "$input" =~ github\.com[:/]([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)(\.git)?$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
  url="$input"
else
  echo "Cannot parse: $input"
  echo "Use owner/repo or a GitHub URL"
  exit 1
fi

# Check if already exists (handles both real dirs and symlinks)
if [ -e "$RESOURCES/$owner/$repo" ]; then
  echo "skip  $owner/$repo already exists on disk"
  exit 0
fi

clone_or_link "$owner" "$repo" "$url"
echo " add  $owner/$repo → registry"
