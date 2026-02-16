#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Building warhawk-tool..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

BINARY="$PROJECT_DIR/.build/release/WarhawkTool"

if [ ! -f "$BINARY" ]; then
    echo "Error: Build produced no binary"
    exit 1
fi

echo ""
echo "Signing with debugger entitlement..."
codesign -s - --entitlements "$PROJECT_DIR/entitlements.plist" --force "$BINARY"

echo ""
echo "Build complete!"
echo "Binary: $BINARY"
echo ""
echo "Usage: sudo $BINARY attach"
echo "       sudo $BINARY interactive"
