#!/usr/bin/env bash
# Clone a repo and add it to registry.yaml in one step
#
# Accepts either a full git URL or an owner/repo shorthand.
# Clones into the resources directory and adds the entry to the registry.
#
# Usage: add-resource.sh <owner/repo | git-url>
#
# Examples:
#   add-resource.sh linuxiscool/new-project
#   add-resource.sh git@github.com:linuxiscool/new-project.git
#   add-resource.sh https://github.com/linuxiscool/new-project.git

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
RESOURCES="$(cd "${PLUGIN_ROOT}/../.." && pwd)"
REGISTRY="${RESOURCES}/registry.yaml"

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

dest="$RESOURCES/$owner/$repo"

# Check if already exists
if [ -d "$dest" ]; then
  echo "skip  $owner/$repo already exists on disk"
  exit 0
fi

# Clone
echo "clone $owner/$repo"
mkdir -p "$RESOURCES/$owner"
git clone "$url" "$dest"

# Add to registry if not already present
if ! grep -qP "^  ${repo}:" "$REGISTRY" 2>/dev/null; then
  # Ensure owner section exists
  if ! grep -qP "^${owner}:" "$REGISTRY" 2>/dev/null; then
    printf '\n%s:\n' "$owner" >> "$REGISTRY"
  fi
  sed -i "/^${owner}:$/a\\  ${repo}:\n    url: ${url}" "$REGISTRY"
  echo " add  $owner/$repo → registry"
else
  echo "  ok  $owner/$repo already in registry"
fi
