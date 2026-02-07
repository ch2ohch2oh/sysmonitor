#!/bin/bash

# Configuration
APP_NAME="SysMonitor"
BUILD_DIR=".build/release"
OUTPUT_DIR="."
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

echo "🚀 Building ${APP_NAME} in release mode..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed."
    exit 1
fi

echo "📦 Creating bundle structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "🎨 Checking for app icon..."
if [ -f "generate_icns.sh" ]; then
    ./generate_icns.sh
    if [ -f "AppIcon.icns" ]; then
        echo "✨ Copying AppIcon.icns to bundle..."
        cp "AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    fi
fi

echo "📋 Generating Info.plist..."
# Determine version
if [ -z "$VERSION" ]; then
    VERSION=$(git describe --tags --always | sed 's/^v//')
fi

echo "🔢 Version: ${VERSION}"

# ... existing build commands ...

# Update Info.plist generation
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "🚚 Copying executable..."
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

echo "✅ Packaging complete: ${APP_BUNDLE}"
echo "You can now zip '${APP_NAME}.app' and share it!"
