#!/usr/bin/env bash
# Restore resources from registry.yaml
#
# Clones repos listed in registry.yaml into the resources directory.
# Skips repos that already exist on disk.
#
# When a global store exists (~/.claude/local/resources/), clones there
# and symlinks into the project store.
#
# Usage: restore-resources.sh

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [ ! -f "$REGISTRY" ]; then
  echo "Registry not found: $REGISTRY"
  exit 1
fi

cloned=0
skipped=0
current_owner=""
current_repo=""

while IFS= read -r line; do
  # Skip comments and blank lines
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue
  [[ "$line" =~ ^_orgs: ]] && break  # stop before metadata keys

  # Owner line: no leading whitespace, ends with colon
  if [[ "$line" =~ ^([a-zA-Z0-9_.-]+):$ ]]; then
    current_owner="${BASH_REMATCH[1]}"
    continue
  fi

  # Repo line: 2-space indent, ends with colon
  if [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z0-9_.-]+):$ ]]; then
    current_repo="${BASH_REMATCH[1]}"
    continue
  fi

  # URL line: 4-space indent, url: value
  if [[ "$line" =~ ^[[:space:]]{4}url:[[:space:]]+(.+)$ ]]; then
    url="${BASH_REMATCH[1]}"

    if [ -e "$RESOURCES/$current_owner/$current_repo" ]; then
      echo "skip  $current_owner/$current_repo (exists)"
      skipped=$((skipped + 1))
      continue
    fi

    clone_or_link "$current_owner" "$current_repo" "$url"
    cloned=$((cloned + 1))
  fi
done < "$REGISTRY"

echo "---"
echo "$cloned cloned, $skipped skipped"
