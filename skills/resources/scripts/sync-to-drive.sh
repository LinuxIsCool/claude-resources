#!/usr/bin/env bash
# Mirror local resource library to data drive
#
# Uses rsync with --delete to make the drive an exact mirror of the local library.
# Excludes .claude/ directories (plugin caches, not repo data).
#
# Usage: sync-to-drive.sh [--dry-run|-n]

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DRY_RUN=""
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN="--dry-run" ;;
  esac
done

# Determine source — prefer global store, fall back to project store
if [ -d "$GLOBAL_STORE" ]; then
  SOURCE="$GLOBAL_STORE"
else
  SOURCE="$RESOURCES"
fi

if [ ! -d "$SOURCE" ]; then
  echo "error: source directory not found: $SOURCE"
  exit 1
fi

ensure_drive_store || exit 1

echo "Syncing: $SOURCE → $DRIVE_STORE"
[ -n "$DRY_RUN" ] && echo "(dry run)"

rsync -av --delete \
  --exclude='.claude/' \
  $DRY_RUN \
  "$SOURCE/" "$DRIVE_STORE/"

echo "---"
echo "Drive mirror complete: $DRIVE_STORE"
