#!/usr/bin/env bash
# Restore resources from registry.yaml
#
# Clones repos listed in registry.yaml into the resources directory.
# Skips repos that already exist on disk.
#
# Usage: restore-resources.sh

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
RESOURCES="$(cd "${PLUGIN_ROOT}/../.." && pwd)"
REGISTRY="${RESOURCES}/registry.yaml"

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
    dest="$RESOURCES/$current_owner/$current_repo"

    if [ -d "$dest" ]; then
      echo "skip  $current_owner/$current_repo (exists)"
      skipped=$((skipped + 1))
    else
      echo "clone $current_owner/$current_repo"
      mkdir -p "$RESOURCES/$current_owner"
      git clone "$url" "$dest"
      cloned=$((cloned + 1))
    fi
  fi
done < "$REGISTRY"

echo "---"
echo "$cloned cloned, $skipped skipped"
