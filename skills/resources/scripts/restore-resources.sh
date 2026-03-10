#!/usr/bin/env bash
# Restore resources from registry.yaml
#
# Clones repos listed in registry.yaml into the resources directory.
# Skips repos that already exist on disk.
#
# When a global store exists (~/.claude/local/resources/), clones there
# and symlinks into the project store.
#
# Usage: restore-resources.sh [--tag=<tag>]
#
# Flags:
#   --tag=<tag>    Only restore repos matching this tag in registry.yaml

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Parse arguments
TAG_FILTER=""
for arg in "$@"; do
  case "$arg" in
    --tag=*) TAG_FILTER="${arg#--tag=}" ;;
  esac
done

if [ ! -f "$REGISTRY" ]; then
  echo "Registry not found: $REGISTRY"
  exit 1
fi

# Build tag filter set if requested
declare -A TAG_REPOS=()
if [ -n "$TAG_FILTER" ]; then
  while IFS= read -r entry; do
    TAG_REPOS["$entry"]=1
  done < <(registry_list_by_tag "$REGISTRY" "$TAG_FILTER")
  if [ ${#TAG_REPOS[@]} -eq 0 ]; then
    echo "No repos found with tag: $TAG_FILTER"
    exit 0
  fi
  echo "Restoring repos with tag: $TAG_FILTER (${#TAG_REPOS[@]} repos)"
fi

cloned=0
skipped=0
filtered=0
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

    # Apply tag filter
    if [ -n "$TAG_FILTER" ] && [ -z "${TAG_REPOS[$current_owner/$current_repo]+x}" ]; then
      filtered=$((filtered + 1))
      continue
    fi

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
summary="$cloned cloned, $skipped skipped"
[ "$filtered" -gt 0 ] && summary="$summary, $filtered filtered out"
echo "$summary"
