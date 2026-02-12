#!/usr/bin/env bash
# Sync registry.yaml with what's actually on disk
#
# Scans the resources directory for cloned repos and reports:
#   add   — repo on disk but not in registry (adds it)
#   miss  — repo in registry but not on disk
#   ok    — repo in both (shown with --verbose)
#   ↑     — real clone promoted to global store
#
# When a global store exists, real clones are auto-promoted: moved to
# the global store and replaced with symlinks.
#
# Usage: sync-registry.sh [--verbose|-v]

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

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
promoted=0
broken=0

# --- Forward scan: disk → registry ---

for owner_dir in "$RESOURCES"/*/; do
  [ -d "$owner_dir" ] || continue
  owner=$(basename "$owner_dir")

  for repo_dir in "$owner_dir"/*/; do
    repo_path="${repo_dir%/}"  # strip trailing slash for reliable -L checks
    # Handle broken symlinks (exist as symlink but target is gone)
    if [ -L "$repo_path" ] && [ ! -e "$repo_path" ]; then
      echo "broke $owner/$(basename "$repo_path") (broken symlink)"
      broken=$((broken + 1))
      continue
    fi

    [ -d "$repo_dir" ] || continue
    repo=$(basename "$repo_dir")

    # Skip if not a git repo
    [ -d "$repo_dir/.git" ] || continue

    # Auto-promote real clones to global store
    if $GLOBAL_ENABLED && [ ! -L "${repo_dir%/}" ]; then
      promote_to_global "$owner" "$repo"
      promoted=$((promoted + 1))
    fi

    # Check if already in registry (section-aware: repo must be under correct owner)
    in_registry=false
    if [ -f "$REGISTRY" ] && awk -v o="$owner" -v r="$repo" '
      $0 == o":" { in_owner=1; next }
      in_owner && /^[^ ]/ { in_owner=0 }
      in_owner && $0 == "  "r":" { found=1; exit }
      END { exit !found }
    ' "$REGISTRY" 2>/dev/null; then
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

    # Add to project registry
    registry_add "$REGISTRY" "$owner" "$repo" "$url"

    # Also register in global if enabled
    if $GLOBAL_ENABLED; then
      registry_add "$GLOBAL_REGISTRY" "$owner" "$repo" "$url"
    fi

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
    if [ ! -e "$dest" ]; then
      echo "miss  $current_owner/$current_repo (in registry, not on disk)"
      missing=$((missing + 1))
    fi
    continue
  fi
done < "$REGISTRY"

# --- Summary ---
echo "---"
summary="$matched matched, $added added, $missing missing"
[ "$promoted" -gt 0 ] && summary="$summary, $promoted promoted"
[ "$broken" -gt 0 ] && summary="$summary, $broken broken"
echo "$summary"
