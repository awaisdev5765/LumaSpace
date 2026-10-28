#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   LumaSpace — Xcode Project Setup   ║"
echo "╚══════════════════════════════════════╝"
echo ""

# 1. Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Install Xcode from the App Store first."
    exit 1
fi
XCODE_VER=$(xcodebuild -version | head -1 | awk '{print $2}' | cut -d. -f1)
echo "✅ Xcode $XCODE_VER detected"

# 2. Check for XcodeGen — install if missing
if ! command -v xcodegen &> /dev/null; then
    echo "▶ Installing XcodeGen via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Install from https://brew.sh then re-run."
        exit 1
    fi
    brew install xcodegen
fi
echo "✅ XcodeGen $(xcodegen --version)"

# 3. Generate .xcodeproj
echo ""
echo "▶ Generating LumaSpace.xcodeproj..."
cd "$(dirname "$0")"
xcodegen generate
echo "✅ LumaSpace.xcodeproj generated"

# 4. Open in Xcode
echo "▶ Opening in Xcode..."
open LumaSpace.xcodeproj

echo ""
echo "══════════════════════════════════════════"
echo " Next steps inside Xcode:"
echo ""
echo "  1. Signing & Capabilities → Team:"
echo "     Select your Apple Developer team"
echo ""
echo "  2. Add your OpenAI API key:"
echo "     Run the app → Profile → AI Settings"
echo ""
echo "  3. StoreKit testing (already configured):"
echo "     Edit Scheme → Run → Options → StoreKit"
echo "     Config: LumaSpace/Resources/LumaSpace.storekit"
echo ""
echo "  4. AR requires a real device (iPhone 12 Pro+)"
echo "     All other screens work in Simulator"
echo "══════════════════════════════════════════"
echo ""
