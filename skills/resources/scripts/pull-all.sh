#!/usr/bin/env bash
# Pull latest changes across all resource repos
#
# When a global store exists, operates there (one pull updates all projects).
# Otherwise operates on the project store.
#
# Skips dirty repos. Uses --ff-only for safety (no merge commits).
#
# Usage: pull-all.sh [owner/repo]
#
# Arguments:
#   owner/repo   Optional filter — only pull this specific repo

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Determine which store to operate on
if $GLOBAL_ENABLED; then
  PULL_ROOT="$GLOBAL_STORE"
  echo "Pulling from global store: $PULL_ROOT"
else
  PULL_ROOT="$RESOURCES"
  echo "Pulling from project store: $PULL_ROOT"
fi

# Optional filter
FILTER="${1:-}"

pulled=0
skipped=0
failed=0
total=0

for owner_dir in "$PULL_ROOT"/*/; do
  [ -d "$owner_dir" ] || continue
  owner=$(basename "$owner_dir")

  for repo_dir in "$owner_dir"/*/; do
    # Skip broken symlinks
    [ -e "$repo_dir" ] || continue
    [ -d "$repo_dir" ] || continue
    [ -d "$repo_dir/.git" ] || continue
    repo=$(basename "$repo_dir")

    # Apply filter if given
    if [ -n "$FILTER" ] && [ "$owner/$repo" != "$FILTER" ]; then
      continue
    fi

    total=$((total + 1))

    # Skip dirty repos
    if ! git -C "$repo_dir" diff --quiet HEAD 2>/dev/null || \
       ! git -C "$repo_dir" diff --cached --quiet HEAD 2>/dev/null || \
       [ -n "$(git -C "$repo_dir" ls-files --others --exclude-standard 2>/dev/null)" ]; then
      echo "skip  $owner/$repo (dirty)"
      skipped=$((skipped + 1))
      continue
    fi

    # Skip repos without a tracking branch
    tracking=$(git -C "$repo_dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
    if [ -z "$tracking" ]; then
      echo "skip  $owner/$repo (no upstream)"
      skipped=$((skipped + 1))
      continue
    fi

    # Pull
    if git -C "$repo_dir" pull --ff-only --quiet 2>/dev/null; then
      echo "pull  $owner/$repo"
      pulled=$((pulled + 1))
    else
      echo "FAIL  $owner/$repo"
      failed=$((failed + 1))
    fi
  done
done

echo "---"
echo "$total repos: $pulled pulled, $skipped skipped, $failed failed"
