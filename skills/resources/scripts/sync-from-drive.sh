#!/usr/bin/env bash
# Restore local resource library from data drive
#
# Uses rsync WITHOUT --delete for safety — never removes local repos
# not present on the drive. Only adds/updates from the drive.
#
# Usage: sync-from-drive.sh [--dry-run|-n]

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DRY_RUN=""
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN="--dry-run" ;;
  esac
done

# Always target the global store
TARGET="$GLOBAL_STORE"
mkdir -p "$TARGET"

ensure_drive_store || exit 1

if [ ! -d "$DRIVE_STORE" ]; then
  echo "error: drive store not found: $DRIVE_STORE"
  exit 1
fi

echo "Restoring: $DRIVE_STORE → $TARGET"
[ -n "$DRY_RUN" ] && echo "(dry run)"

rsync -av \
  --exclude='.claude/' \
  $DRY_RUN \
  "$DRIVE_STORE/" "$TARGET/"

echo "---"
echo "Local library restored from drive"
echo "Run /claude-resources:sync to update registry.yaml"
