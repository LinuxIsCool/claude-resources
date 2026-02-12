#!/usr/bin/env bash
# Shared library for claude-resources scripts
#
# Provides path resolution, global store detection, and helper functions.
# Source this at the top of every script:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# Two-tier model:
#   Global store:  ~/.claude/local/resources/     (shared across projects)
#   Project store: {project}/.claude/local/resources/  (per-project)
#
# When the global store exists, repos are cloned there once and symlinked
# into project stores. When it doesn't exist, everything works as before.

# --- Path Resolution ---

GLOBAL_STORE="$HOME/.claude/local/resources"
GLOBAL_REGISTRY="$GLOBAL_STORE/registry.yaml"

# Project store resolution — three strategies, in priority order:
#
# 1. Explicit env var (set by wrapper scripts or CI)
# 2. Relative to calling script via BASH_SOURCE[1] (works when plugin
#    lives inside the resources directory, e.g. linuxiscool/claude-resources/)
# 3. Relative to working directory (fallback for plugin cache, where
#    CLAUDE_PLUGIN_ROOT points to ~/.claude/plugins/cache/ instead of
#    the resources directory)
#
_resolve_project_store() {
  # Strategy 1: explicit env var
  if [ -n "${CLAUDE_RESOURCES_DIR:-}" ]; then
    echo "$CLAUDE_RESOURCES_DIR"
    return
  fi

  # Strategy 2: navigate from calling script's location
  # Only works when the plugin lives inside the resources directory
  # (not when running from the plugin cache at ~/.claude/plugins/)
  if [ -n "${BASH_SOURCE[1]:-}" ]; then
    local _caller_dir _plugin_root _candidate
    _caller_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    _plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$_caller_dir/../../.." && pwd)}"
    _candidate="$(cd "$_plugin_root/../.." && pwd)"
    if [ -f "$_candidate/registry.yaml" ] && [[ "$_candidate" != *"/.claude/plugins/"* ]]; then
      echo "$_candidate"
      return
    fi
  fi

  # Strategy 3: relative to working directory
  if [ -f "$PWD/.claude/local/resources/registry.yaml" ]; then
    echo "$PWD/.claude/local/resources"
    return
  fi

  # Last resort: global store (if it exists) or pwd
  if [ -d "$GLOBAL_STORE" ]; then
    echo "$GLOBAL_STORE"
  else
    echo "$PWD/.claude/local/resources"
  fi
}

PROJECT_STORE="$(_resolve_project_store)"

# Backward-compatible aliases
RESOURCES="$PROJECT_STORE"
REGISTRY="$PROJECT_STORE/registry.yaml"

# Global store is enabled when it exists AND differs from the project store
# (avoids double operations when global IS the project store)
GLOBAL_ENABLED=false
if [ -d "$GLOBAL_STORE" ]; then
  _global_real="$(cd "$GLOBAL_STORE" && pwd)"
  _project_real="$(cd "$PROJECT_STORE" && pwd)"
  if [ "$_global_real" != "$_project_real" ]; then
    GLOBAL_ENABLED=true
  fi
  unset _global_real _project_real
fi

# --- Helper Functions ---

ensure_global_store() {
  # Create global store directory and registry header if needed
  mkdir -p "$GLOBAL_STORE"
  if [ ! -f "$GLOBAL_REGISTRY" ]; then
    cat > "$GLOBAL_REGISTRY" << 'HEADER'
# Global Resource Registry
#
# Shared clone store at ~/.claude/local/resources/.
# Projects symlink into this directory instead of cloning independently.
#
# This file is managed automatically by claude-resources scripts.

HEADER
  fi
}

registry_add() {
  # Idempotent registry entry addition
  # Usage: registry_add <registry_file> <owner> <repo> <url>
  local file="$1" owner="$2" repo="$3" url="$4"

  # Check if this repo already exists under this specific owner section
  # (section-aware: only matches repo lines between this owner header
  # and the next owner header, avoiding false matches across owners)
  if [ -f "$file" ] && awk -v o="$owner" -v r="$repo" '
    $0 == o":" { in_owner=1; next }
    in_owner && /^[^ ]/ { in_owner=0 }
    in_owner && $0 == "  "r":" { found=1; exit }
    END { exit !found }
  ' "$file" 2>/dev/null; then
    return 0
  fi

  # Ensure owner section exists
  if ! grep -qF "${owner}:" "$file" 2>/dev/null; then
    printf '\n%s:\n' "$owner" >> "$file"
  fi

  sed -i "/^${owner}:$/a\\  ${repo}:\n    url: ${url}" "$file"
}

symlink_to_global() {
  # Create project → global symlink for a repo
  # Usage: symlink_to_global <owner> <repo>
  local owner="$1" repo="$2"
  local project_dest="$PROJECT_STORE/$owner/$repo"
  local global_dest="$GLOBAL_STORE/$owner/$repo"

  # Remove existing project clone if it's a real directory (shouldn't happen
  # in normal flow, but handles edge cases)
  if [ -d "$project_dest" ] && [ ! -L "$project_dest" ]; then
    echo "warn  $owner/$repo — project dir is real, not symlinking over it"
    return 1
  fi

  mkdir -p "$PROJECT_STORE/$owner"
  # Remove stale symlink if present
  [ -L "$project_dest" ] && rm "$project_dest"
  ln -s "$global_dest" "$project_dest"
}

is_global_symlink() {
  # Check if a path is a symlink pointing into the global store
  # Usage: is_global_symlink <path>
  local path="$1"
  if [ -L "$path" ]; then
    local target
    target="$(readlink -f "$path" 2>/dev/null || readlink "$path")"
    [[ "$target" == "$GLOBAL_STORE"* ]]
  else
    return 1
  fi
}

clone_or_link() {
  # Clone a repo, respecting the two-tier model
  # When global is enabled: clone to global if needed, symlink into project
  # Otherwise: clone directly to project
  # Usage: clone_or_link <owner> <repo> <url>
  local owner="$1" repo="$2" url="$3"
  local dest="$RESOURCES/$owner/$repo"

  if $GLOBAL_ENABLED; then
    ensure_global_store
    local global_dest="$GLOBAL_STORE/$owner/$repo"

    if [ ! -d "$global_dest" ]; then
      echo "clone $owner/$repo → global store"
      mkdir -p "$GLOBAL_STORE/$owner"
      git clone "$url" "$global_dest"
      registry_add "$GLOBAL_REGISTRY" "$owner" "$repo" "$url"
    else
      echo "  ok  $owner/$repo already in global store"
    fi

    echo "link  $owner/$repo → project"
    symlink_to_global "$owner" "$repo"
  else
    echo "clone $owner/$repo"
    mkdir -p "$RESOURCES/$owner"
    git clone "$url" "$dest"
  fi

  registry_add "$REGISTRY" "$owner" "$repo" "$url"
}

promote_to_global() {
  # Move a real clone from project to global store, symlink back, register
  # Usage: promote_to_global <owner> <repo>
  local owner="$1" repo="$2"
  local project_dest="$PROJECT_STORE/$owner/$repo"
  local global_dest="$GLOBAL_STORE/$owner/$repo"

  # Only promote real directories, not symlinks
  if [ -L "$project_dest" ]; then
    return 0
  fi
  if [ ! -d "$project_dest/.git" ]; then
    return 1
  fi

  ensure_global_store

  if [ -d "$global_dest" ]; then
    # Global already has it — verify it's a real git repo before removing project copy
    if [ ! -d "$global_dest/.git" ]; then
      echo "warn  $owner/$repo — global path exists but is not a git repo, skipping"
      return 1
    fi
    rm -rf "$project_dest"
  else
    # Move to global
    mkdir -p "$GLOBAL_STORE/$owner"
    mv "$project_dest" "$global_dest"
  fi

  # Symlink back
  ln -s "$global_dest" "$project_dest"

  # Register in global registry
  local url
  url=$(git -C "$global_dest" remote get-url origin 2>/dev/null || echo "")
  if [ -n "$url" ]; then
    registry_add "$GLOBAL_REGISTRY" "$owner" "$repo" "$url"
  fi

  echo "  ↑   $owner/$repo promoted to global store"
}
