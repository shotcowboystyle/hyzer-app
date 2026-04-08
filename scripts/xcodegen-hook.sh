#!/bin/sh

# Post-checkout and post-merge hook to automatically regenerate Xcode project
# This script checks if project.yml changed and runs `xcodegen generate` if needed.
# It never blocks git operations (always exits 0).

# Get the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Determine what changed based on which hook called us
if [ "$1" = "1" ]; then
    # post-checkout hook: $1=old-head, $2=new-head, $3=0|1 (file|branch checkout)
    OLD_HEAD=$1
    NEW_HEAD=$2
else
    # post-merge hook: ORIG_HEAD environment variable contains the previous HEAD
    OLD_HEAD="${ORIG_HEAD:-HEAD~1}"
    NEW_HEAD="HEAD"
fi

# Check if project.yml was modified
if git diff-index --quiet --cached "$OLD_HEAD" "$NEW_HEAD" -- "$REPO_ROOT/project.yml" 2>/dev/null; then
    # project.yml didn't change
    exit 0
fi

# project.yml changed, try to regenerate the Xcode project
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "⚠️  Warning: xcodegen not found in PATH"
    echo "   Install it with: brew install xcodegen"
    echo "   Then run: xcodegen generate"
    exit 0
fi

echo "🔄 project.yml changed, regenerating Xcode project..."
if cd "$REPO_ROOT" && xcodegen generate >/dev/null 2>&1; then
    echo "✅ Xcode project regenerated successfully"
else
    echo "⚠️  Warning: xcodegen generate failed"
    echo "   Run 'xcodegen generate' manually to fix"
fi

exit 0
