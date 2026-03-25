#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.local/bin"

mkdir -p "$TARGET_DIR"

ln -sfn "$SCRIPT_DIR/bin/git-create-worktree" "$TARGET_DIR/git-create-worktree"
ln -sfn "$SCRIPT_DIR/bin/git-remove-worktree" "$TARGET_DIR/git-remove-worktree"
ln -sfn "$SCRIPT_DIR/bin/git-update-worktree" "$TARGET_DIR/git-update-worktree"

echo "Installed symlinks:"
echo "  $TARGET_DIR/git-create-worktree -> $SCRIPT_DIR/bin/git-create-worktree"
echo "  $TARGET_DIR/git-remove-worktree -> $SCRIPT_DIR/bin/git-remove-worktree"
echo "  $TARGET_DIR/git-update-worktree -> $SCRIPT_DIR/bin/git-update-worktree"
echo ""
echo "If needed, add to PATH:"
echo "  export PATH=\"$HOME/.local/bin:\$PATH\""
