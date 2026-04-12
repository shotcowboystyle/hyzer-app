#!/bin/bash
# scripts/test-changed.sh
# Run tests only for changed Swift files (smart test selection)
# Usage: ./scripts/test-changed.sh [base-branch]

set -e

BASE_BRANCH=${1:-main}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Selective Test Runner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Base branch: $BASE_BRANCH"
echo ""

# Detect changed Swift files
CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || git diff --name-only HEAD)

if [ -z "$CHANGED_FILES" ]; then
  echo "No files changed. Nothing to test."
  exit 0
fi

echo "Changed files:"
echo "$CHANGED_FILES" | sed 's/^/  - /'
echo ""

# Determine what to run
RUN_KIT=false
RUN_APP=false
RUN_LINT=false

# Check for HyzerKit source changes
if echo "$CHANGED_FILES" | grep -qE '^HyzerKit/'; then
  RUN_KIT=true
fi

# Check for HyzerApp source changes
if echo "$CHANGED_FILES" | grep -qE '^(HyzerApp/|HyzerAppTests/)'; then
  RUN_APP=true
fi

# Check for lintable changes
if echo "$CHANGED_FILES" | grep -qE '\.swift$'; then
  RUN_LINT=true
fi

# Check for project config changes (run everything)
if echo "$CHANGED_FILES" | grep -qE '(project\.yml|Package\.swift|\.swiftlint\.yml)'; then
  RUN_KIT=true
  RUN_APP=true
  RUN_LINT=true
fi

# Execute selected tests
if [ "$RUN_LINT" = true ]; then
  echo "Running SwiftLint..."
  swiftlint lint --strict
  echo ""
fi

if [ "$RUN_KIT" = true ]; then
  echo "Running HyzerKit tests..."
  swift test --package-path HyzerKit
  echo ""
fi

if [ "$RUN_APP" = true ]; then
  echo "Running HyzerApp tests..."
  xcodegen generate --quiet 2>/dev/null || true
  xcodebuild test \
    -project HyzerApp.xcodeproj \
    -scheme HyzerApp \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -20
  echo ""
fi

if [ "$RUN_KIT" = false ] && [ "$RUN_APP" = false ] && [ "$RUN_LINT" = false ]; then
  echo "No Swift changes detected. Skipping tests."
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Selective tests complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
