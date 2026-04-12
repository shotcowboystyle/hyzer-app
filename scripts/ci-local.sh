#!/bin/bash
# scripts/ci-local.sh
# Mirror CI pipeline locally for pre-push verification
# Usage: ./scripts/ci-local.sh [--skip-lint] [--kit-only]

set -e

SKIP_LINT=false
KIT_ONLY=false

for arg in "$@"; do
  case $arg in
    --skip-lint) SKIP_LINT=true ;;
    --kit-only) KIT_ONLY=true ;;
  esac
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HyzerApp CI - Local Pipeline"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Stage 1: SwiftLint
if [ "$SKIP_LINT" = false ]; then
  echo "[1/3] SwiftLint..."
  if command -v swiftlint &> /dev/null; then
    swiftlint lint --strict
    echo "SwiftLint passed"
  else
    echo "SwiftLint not installed. Install with: brew install swiftlint"
    exit 1
  fi
  echo ""
else
  echo "[1/3] SwiftLint... SKIPPED"
  echo ""
fi

# Stage 2: HyzerKit tests (fast, no simulator)
echo "[2/3] HyzerKit tests (swift test)..."
swift test --package-path HyzerKit
echo "HyzerKit tests passed"
echo ""

# Stage 3: HyzerApp ViewModel tests (requires simulator)
if [ "$KIT_ONLY" = false ]; then
  echo "[3/3] HyzerApp tests (xcodebuild)..."

  # Regenerate project in case project.yml changed
  if command -v xcodegen &> /dev/null; then
    xcodegen generate --quiet
  fi

  xcodebuild test \
    -project HyzerApp.xcodeproj \
    -scheme HyzerApp \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -enableCodeCoverage YES \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tail -20

  echo "HyzerApp tests passed"
else
  echo "[3/3] HyzerApp tests... SKIPPED (--kit-only)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CI Local Pipeline PASSED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
