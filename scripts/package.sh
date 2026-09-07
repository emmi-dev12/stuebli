#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PWD/dist/Stübli.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/StuebliApp" "$APP_DIR/Contents/MacOS/StuebliApp"
cp "$BIN_DIR/stubli" "$APP_DIR/Contents/MacOS/stubli"
RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 -type d -name '*StubliCore*.bundle' -print -quit)"
if [ -z "$RESOURCE_BUNDLE" ]; then
  RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 -type d -name '*StubliCore*.resources' -print -quit)"
fi
if [ -z "$RESOURCE_BUNDLE" ]; then
  echo 'Missing catalog resource bundle' >&2
  exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
# SwiftPM locates command-line resources next to the executable too.
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/MacOS/"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Stübli</string>
<key>CFBundleDisplayName</key><string>Stübli</string>
<key>CFBundleIdentifier</key><string>dev.emmi.stuebli</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleExecutable</key><string>StuebliApp</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHumanReadableCopyright</key><string>Stübli contributors</string>
</dict></plist>
PLIST
swift scripts/make-icon.swift "$APP_DIR/Contents/Resources"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
printf 'Built %s\n' "$APP_DIR"
