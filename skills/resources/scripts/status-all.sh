#!/usr/bin/env bash
# Git status across all resource repos
#
# Walks every git repo in the resources directory and reports:
#   clean  — working tree is clean
#   dirty  — uncommitted changes exist
#   ahead  — local is ahead of remote
#   behind — local is behind remote
#   →      — repo is symlinked from global store
#
# Usage: status-all.sh [--short|-s] [--fetch|-f]
#
# Flags:
#   --short, -s   Only show dirty repos and those out of sync
#   --fetch, -f   Run git fetch before checking ahead/behind (shows staleness)

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SHORT=false
FETCH=false
for arg in "$@"; do
  case "$arg" in
    --short|-s) SHORT=true ;;
    --fetch|-f) FETCH=true ;;
  esac
done

clean=0
dirty=0
total=0
broken=0

for owner_dir in "$RESOURCES"/*/; do
  [ -d "$owner_dir" ] || continue
  owner=$(basename "$owner_dir")

  for repo_dir in "$owner_dir"/*/; do
    repo_path="${repo_dir%/}"  # strip trailing slash for reliable -L checks
    # Handle broken symlinks
    if [ -L "$repo_path" ] && [ ! -e "$repo_path" ]; then
      echo "broke  $owner/$(basename "$repo_path") (broken symlink)"
      broken=$((broken + 1))
      continue
    fi

    [ -d "$repo_dir" ] || continue
    [ -d "$repo_dir/.git" ] || continue
    repo=$(basename "$repo_dir")
    total=$((total + 1))

    # Symlink indicator
    if is_global_symlink "${repo_dir%/}"; then
      link_indicator="→"
    else
      link_indicator=" "
    fi

    # Fetch if requested (before checking ahead/behind)
    if $FETCH; then
      git -C "$repo_dir" fetch --quiet 2>/dev/null || true
    fi

    # Check for uncommitted changes
    if git -C "$repo_dir" diff --quiet HEAD 2>/dev/null && \
       git -C "$repo_dir" diff --cached --quiet HEAD 2>/dev/null && \
       [ -z "$(git -C "$repo_dir" ls-files --others --exclude-standard 2>/dev/null)" ]; then
      status="clean"
      clean=$((clean + 1))
    else
      status="dirty"
      dirty=$((dirty + 1))
    fi

    # Check ahead/behind (if tracking branch exists)
    tracking=$(git -C "$repo_dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
    if [ -n "$tracking" ]; then
      ahead=$(git -C "$repo_dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "0")
      behind=$(git -C "$repo_dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo "0")
      if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        track_status=" (ahead $ahead, behind $behind)"
      elif [ "$ahead" -gt 0 ]; then
        track_status=" (ahead $ahead)"
      elif [ "$behind" -gt 0 ]; then
        track_status=" (behind $behind)"
      else
        track_status=""
      fi
    else
      track_status=" (no upstream)"
    fi

    if $SHORT; then
      [ "$status" == "dirty" ] || [ -n "$track_status" ] && echo "$status $link_indicator $owner/$repo$track_status"
    else
      printf "%-6s %s %s%s\n" "$status" "$link_indicator" "$owner/$repo" "$track_status"
    fi
  done
done

echo "---"
summary="$total repos: $clean clean, $dirty dirty"
[ "$broken" -gt 0 ] && summary="$summary, $broken broken"
echo "$summary"
