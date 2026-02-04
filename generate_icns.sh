#!/bin/bash

# Check if source icon exists
ICON_SOURCE="icon_source.png"
ICON_SET="SysMonitor.iconset"
OUTPUT_ICNS="AppIcon.icns"

if [ ! -f "$ICON_SOURCE" ]; then
    echo "⚠️  No source icon found at $ICON_SOURCE. Skipping icon generation."
    exit 0
fi

echo "🎨 Generating app icon..."

# Create iconset directory
mkdir -p "$ICON_SET"

# Generate various sizes
sips -z 16 16     -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_16x16.png" > /dev/null
sips -z 32 32     -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_16x16@2x.png" > /dev/null
sips -z 32 32     -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_32x32.png" > /dev/null
sips -z 64 64     -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_32x32@2x.png" > /dev/null
sips -z 128 128   -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_128x128.png" > /dev/null
sips -z 256 256   -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_128x128@2x.png" > /dev/null
sips -z 256 256   -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_256x256.png" > /dev/null
sips -z 512 512   -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_256x256@2x.png" > /dev/null
sips -z 512 512   -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_512x512.png" > /dev/null
sips -z 1024 1024 -s format png "$ICON_SOURCE" --out "${ICON_SET}/icon_512x512@2x.png" > /dev/null

# Create .icns file
iconutil -c icns "$ICON_SET" -o "$OUTPUT_ICNS"

# Cleanup
rm -rf "$ICON_SET"

echo "✅ Icon generated: $OUTPUT_ICNS"
