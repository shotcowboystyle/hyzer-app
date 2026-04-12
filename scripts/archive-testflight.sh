#!/usr/bin/env bash
# archive-testflight.sh — Build, archive, and export HyzerApp for TestFlight upload.
#
# Usage:
#   ./scripts/archive-testflight.sh [--upload]
#
# Prerequisites:
#   - Xcode CLI tools installed
#   - Valid Apple Developer account signed in to Xcode
#   - Automatic signing configured for com.shotcowboystyle.hyzerapp
#   - xcodegen installed (brew install xcodegen)
#
# The --upload flag uses `xcrun altool` to upload to App Store Connect automatically.
# Without it, the .ipa is exported to build/ for manual upload via Transporter or Xcode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/HyzerApp.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="$PROJECT_ROOT/ExportOptions.plist"
SCHEME="HyzerApp"
PROJECT="$PROJECT_ROOT/HyzerApp.xcodeproj"

UPLOAD=false
if [[ "${1:-}" == "--upload" ]]; then
    UPLOAD=true
fi

echo "=== HyzerApp TestFlight Build ==="
echo ""

# Step 0: Regenerate Xcode project
echo "[1/5] Regenerating Xcode project..."
cd "$PROJECT_ROOT"
xcodegen generate --quiet
echo "  ✓ project.pbxproj regenerated"

# Step 1: Clean build directory
echo "[2/5] Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 2: Run tests
echo "[3/5] Running HyzerKit tests..."
swift test --package-path "$PROJECT_ROOT/HyzerKit" 2>&1 | tail -5
echo "  ✓ HyzerKit tests passed"

# Step 3: Archive
echo "[4/5] Archiving $SCHEME..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    CODE_SIGN_STYLE=Automatic \
    COMPILER_INDEX_STORE_ENABLE=NO \
    | grep -E '^(Archive Succeeded|error:|warning:|\*\*)' || true

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    echo "ERROR: Archive failed. Check Xcode signing configuration."
    exit 1
fi
echo "  ✓ Archive created at $ARCHIVE_PATH"

# Step 4: Export IPA
echo "[5/5] Exporting IPA for TestFlight..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    | grep -E '^(Export Succeeded|error:|warning:|\*\*)' || true

IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" -type f | head -1)
if [[ -z "$IPA_FILE" ]]; then
    echo "ERROR: Export failed. Check ExportOptions.plist and signing configuration."
    exit 1
fi
echo "  ✓ IPA exported: $IPA_FILE"

# Step 5: Optional upload
if [[ "$UPLOAD" == true ]]; then
    echo ""
    echo "Uploading to App Store Connect..."
    xcrun altool --upload-app \
        --file "$IPA_FILE" \
        --type ios \
        --apiKey "${APP_STORE_API_KEY:-}" \
        --apiIssuer "${APP_STORE_API_ISSUER:-}"
    echo "  ✓ Upload complete. Check App Store Connect for processing status."
else
    echo ""
    echo "=== Build Complete ==="
    echo "IPA: $IPA_FILE"
    echo ""
    echo "To upload manually:"
    echo "  1. Open Transporter.app and drag the .ipa file"
    echo "  2. Or run: ./scripts/archive-testflight.sh --upload"
    echo "     (requires APP_STORE_API_KEY and APP_STORE_API_ISSUER env vars)"
fi
