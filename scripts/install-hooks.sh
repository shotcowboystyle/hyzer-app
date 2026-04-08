#!/bin/sh

# Install git hooks for xcodegen auto-generation
# This script creates symlinks from .git/hooks to the xcodegen-hook.sh script
# Safe to run multiple times (idempotent)

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
HOOK_SCRIPT="$REPO_ROOT/scripts/xcodegen-hook.sh"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

# Verify the hook script exists
if [ ! -f "$HOOK_SCRIPT" ]; then
    echo "❌ Error: Hook script not found at $HOOK_SCRIPT"
    exit 1
fi

# Create .git/hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Install post-checkout hook
POST_CHECKOUT="$HOOKS_DIR/post-checkout"
if [ -L "$POST_CHECKOUT" ]; then
    # Already a symlink, check if it points to the right place
    if [ "$(readlink "$POST_CHECKOUT")" = "$HOOK_SCRIPT" ]; then
        echo "✅ post-checkout hook already installed"
    else
        rm "$POST_CHECKOUT"
        ln -s "$HOOK_SCRIPT" "$POST_CHECKOUT"
        echo "✅ post-checkout hook updated"
    fi
elif [ -f "$POST_CHECKOUT" ]; then
    # Existing file (not a symlink), back it up and replace
    mv "$POST_CHECKOUT" "$POST_CHECKOUT.backup"
    ln -s "$HOOK_SCRIPT" "$POST_CHECKOUT"
    echo "✅ post-checkout hook installed (old hook backed up to .post-checkout.backup)"
else
    # Doesn't exist, create symlink
    ln -s "$HOOK_SCRIPT" "$POST_CHECKOUT"
    echo "✅ post-checkout hook installed"
fi

# Install post-merge hook
POST_MERGE="$HOOKS_DIR/post-merge"
if [ -L "$POST_MERGE" ]; then
    # Already a symlink, check if it points to the right place
    if [ "$(readlink "$POST_MERGE")" = "$HOOK_SCRIPT" ]; then
        echo "✅ post-merge hook already installed"
    else
        rm "$POST_MERGE"
        ln -s "$HOOK_SCRIPT" "$POST_MERGE"
        echo "✅ post-merge hook updated"
    fi
elif [ -f "$POST_MERGE" ]; then
    # Existing file (not a symlink), back it up and replace
    mv "$POST_MERGE" "$POST_MERGE.backup"
    ln -s "$HOOK_SCRIPT" "$POST_MERGE"
    echo "✅ post-merge hook installed (old hook backed up to .post-merge.backup)"
else
    # Doesn't exist, create symlink
    ln -s "$HOOK_SCRIPT" "$POST_MERGE"
    echo "✅ post-merge hook installed"
fi

# Make the hook script executable
chmod +x "$HOOK_SCRIPT"
chmod +x "$POST_CHECKOUT"
chmod +x "$POST_MERGE"

echo ""
echo "🎉 Git hooks installed successfully!"
echo "   xcodegen will now run automatically on checkout and merge if project.yml changed"
