#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="SysMonitor"
APP_BUNDLE="${OUTPUT_DIR:-.}/${APP_NAME}.app"
CONFIGURATION="${CONFIGURATION:-release}"
ARCHITECTURES="${ARCHITECTURES:-universal}"
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || printf '1.0.0')}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "VERSION must be a numeric release version and BUILD_NUMBER must be an integer." >&2
    exit 1
fi
if [[ -n "${NOTARY_PROFILE:-}" && -z "${SIGNING_IDENTITY:-}" ]]; then
    echo "Set SIGNING_IDENTITY before requesting notarization." >&2
    exit 1
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/ModuleCache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$CLANG_MODULE_CACHE_PATH}"
BUILD_ARGS=(-c "$CONFIGURATION")
case "$ARCHITECTURES" in
    universal) BUILD_ARGS+=(--arch arm64 --arch x86_64) ;;
    native) ;;
    *) echo "ARCHITECTURES must be universal or native." >&2; exit 1 ;;
esac
if [[ "${SWIFTPM_DISABLE_SANDBOX:-0}" == 1 ]]; then BUILD_ARGS+=(--disable-sandbox); fi

echo "Building ${APP_NAME} (${CONFIGURATION}, ${ARCHITECTURES})…"
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
test -x "${BIN_DIR}/${APP_NAME}"

mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "${BIN_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
if [[ ! -f AppIcon.icns ]]; then bash ./generate_icns.sh; fi
if [[ -f AppIcon.icns ]]; then cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"; fi

cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.example.${APP_NAME}</string>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF
plutil -lint "${APP_BUNDLE}/Contents/Info.plist"

# Remove an old bundle signature before optionally signing the fresh executable.
rm -rf "${APP_BUNDLE}/Contents/_CodeSignature"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
else
    echo "Local unsigned bundle: set SIGNING_IDENTITY for a Developer ID release."
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    NOTARY_ZIP="$(mktemp -d)/SysMonitor.zip"
    trap 'rm -f "$NOTARY_ZIP"; rmdir "$(dirname "$NOTARY_ZIP")"' EXIT
    ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
    xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"
    spctl --assess --type execute --verbose=2 "$APP_BUNDLE"
fi

echo "Packaging complete: ${APP_BUNDLE}"
