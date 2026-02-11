#!/usr/bin/env bash
# Sync registry.yaml with what's actually on disk
#
# Scans the resources directory for cloned repos and reports:
#   add   — repo on disk but not in registry (adds it)
#   miss  — repo in registry but not on disk
#   ok    — repo in both (shown with --verbose)
#
# Usage: sync-registry.sh [--verbose|-v]

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
RESOURCES="$(cd "${PLUGIN_ROOT}/../.." && pwd)"
REGISTRY="${RESOURCES}/registry.yaml"
VERBOSE=false
[[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]] && VERBOSE=true

# Create registry if it doesn't exist
if [ ! -f "$REGISTRY" ]; then
  cat > "$REGISTRY" << 'HEADER'
# Resource Registry
#
# Lists all repos to clone into .claude/local/resources/.
# Each entry becomes {owner}/{repo}/ on disk.
#
# Restore all resources:  /claude-resources:restore
# Sync from disk:         /claude-resources:sync

HEADER
fi

added=0
missing=0
matched=0

# --- Forward scan: disk → registry ---

for owner_dir in "$RESOURCES"/*/; do
  [ -d "$owner_dir" ] || continue
  owner=$(basename "$owner_dir")

  for repo_dir in "$owner_dir"/*/; do
    [ -d "$repo_dir" ] || continue
    repo=$(basename "$repo_dir")

    # Skip if not a git repo
    [ -d "$repo_dir/.git" ] || continue

    # Check if already in registry
    in_registry=false
    if grep -q "url:.*/${owner}/${repo}\\.git" "$REGISTRY" 2>/dev/null || \
       grep -q "url:.*/${owner}/${repo}\$" "$REGISTRY" 2>/dev/null; then
      in_registry=true
    elif grep -qiP "^${owner}:" "$REGISTRY" 2>/dev/null && \
         grep -qP "^  ${repo}:" "$REGISTRY" 2>/dev/null; then
      in_registry=true
    fi

    if $in_registry; then
      $VERBOSE && echo "  ok  $owner/$repo"
      matched=$((matched + 1))
      continue
    fi

    # Get remote URL
    url=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || echo "")
    if [ -z "$url" ]; then
      echo "warn  $owner/$repo — no remote origin, skipping"
      continue
    fi

    # Ensure owner section exists
    if ! grep -qP "^${owner}:" "$REGISTRY" 2>/dev/null; then
      printf '\n%s:\n' "$owner" >> "$REGISTRY"
    fi

    # Append repo under owner
    sed -i "/^${owner}:$/a\\  ${repo}:\n    url: ${url}" "$REGISTRY"

    echo " add  $owner/$repo"
    added=$((added + 1))
  done
done

# --- Reverse scan: registry → disk ---

current_owner=""

while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue
  [[ "$line" =~ ^_orgs: ]] && break  # stop before metadata keys

  if [[ "$line" =~ ^([a-zA-Z0-9_.-]+):$ ]]; then
    current_owner="${BASH_REMATCH[1]}"
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z0-9_.-]+):$ ]]; then
    current_repo="${BASH_REMATCH[1]}"
    dest="$RESOURCES/$current_owner/$current_repo"
    if [ ! -d "$dest" ]; then
      echo "miss  $current_owner/$current_repo (in registry, not on disk)"
      missing=$((missing + 1))
    fi
    continue
  fi
done < "$REGISTRY"

# --- Summary ---
echo "---"
echo "$matched matched, $added added, $missing missing"
