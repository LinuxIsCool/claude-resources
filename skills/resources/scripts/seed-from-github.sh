#!/usr/bin/env bash
# Populate registry.yaml from GitHub orgs/users
#
# Registry only — does NOT clone repos. Run restore afterward to clone.
# Uses gh api --paginate for reliable pagination (no 200-repo cap).
#
# Usage: seed-from-github.sh [org1 org2 ...]
#
# Default orgs: linuxiscool bonding-curves longtailfinancial gaiaaiagent commonsbuild

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DEFAULT_ORGS="linuxiscool bonding-curves longtailfinancial gaiaaiagent commonsbuild"
ORGS="${*:-$DEFAULT_ORGS}"

if ! command -v gh &>/dev/null; then
  echo "error: gh CLI not found — install with: pacman -S github-cli"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "error: not authenticated — run: gh auth login"
  exit 1
fi

# Ensure registry exists
if [ ! -f "$REGISTRY" ]; then
  mkdir -p "$(dirname "$REGISTRY")"
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

total_added=0
total_skipped=0

for org in $ORGS; do
  echo "=== $org ==="

  # Fetch all repos via REST API with pagination
  repos_json=$(gh api --paginate "/users/${org}/repos?per_page=100" 2>/dev/null || true)

  if [ -z "$repos_json" ]; then
    echo "  warn: no repos found (org may not exist or API error)"
    continue
  fi

  added=0
  skipped=0

  # Process each repo
  while IFS=$'\t' read -r name clone_url is_fork is_archived; do
    [ -z "$name" ] && continue

    # Build tags
    tags=""
    add_tag() { [ -n "$tags" ] && tags="$tags,$1" || tags="$1"; }

    # Fork/archived flags
    [ "$is_fork" = "true" ] && add_tag "fork"
    [ "$is_archived" = "true" ] && add_tag "archived"

    # Owner-based tags
    case "$org" in
      linuxiscool) add_tag "owned" ;;
      bonding-curves|longtailfinancial|gaiaaiagent) add_tag "venture" ;;
      commonsbuild) add_tag "reference" ;;
    esac

    # Active = not fork and not archived
    if [ "$is_fork" != "true" ] && [ "$is_archived" != "true" ]; then
      add_tag "active"
    fi

    # Convert HTTPS URL to SSH
    ssh_url="git@github.com:${org}/${name}.git"

    # registry_add is idempotent — returns 0 if already exists
    if registry_add "$REGISTRY" "$org" "$name" "$ssh_url" "$tags"; then
      # Check if it was actually added (registry_add returns 0 for both cases)
      # We detect "already exists" by checking before/after — but simpler to
      # just count and let the summary be approximate. The idempotency is the
      # important part.
      added=$((added + 1))
    fi
  done < <(echo "$repos_json" | jq -r '.[] | [.name, .clone_url, .fork, .archived] | @tsv' 2>/dev/null)

  echo "  $added repos processed"
  total_added=$((total_added + added))

  # Track org in _orgs list
  if ! grep -q "^_orgs:" "$REGISTRY" 2>/dev/null; then
    printf '\n_orgs:\n  - %s\n' "$org" >> "$REGISTRY"
  elif ! grep -q "  - ${org}$" "$REGISTRY" 2>/dev/null; then
    sed -i "/^_orgs:$/a\\  - ${org}" "$REGISTRY"
  fi
done

echo "---"
echo "$total_added repos processed across $(echo $ORGS | wc -w) orgs"
echo "Run restore to clone: restore-resources.sh [--tag=owned]"
