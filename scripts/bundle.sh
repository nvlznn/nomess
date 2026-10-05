#!/bin/sh
# Builds NoMess.app into build/ with an ad-hoc signature (local use only;
# distribution needs a Developer ID signature and notarization).
set -eu

cd "$(dirname "$0")/.."

swift build -c release --product NoMess
BIN="$(swift build -c release --show-bin-path)/NoMess"

APP=build/NoMess.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/NoMess"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>dev.noky.nomess</string>
    <key>CFBundleName</key>
    <string>NoMess</string>
    <key>CFBundleExecutable</key>
    <string>NoMess</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"
