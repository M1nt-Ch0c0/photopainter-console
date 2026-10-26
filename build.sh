#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP="$ROOT/dist/PhotoPainter Console.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -parse-as-library -target arm64-apple-macosx14.0 \
  "$ROOT/Sources/Models.swift" \
  "$ROOT/Sources/ConsoleSocket.swift" \
  "$ROOT/Sources/OperationsView.swift" \
  "$ROOT/Sources/ConsoleApp.swift" \
  -o "$APP/Contents/MacOS/PhotoPainterConsole"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.m1ntch0c0.photopainter-console</string>
<key>CFBundleName</key><string>PhotoPainter Console</string>
<key>CFBundleDisplayName</key><string>PhotoPainter 控制台</string>
<key>CFBundleExecutable</key><string>PhotoPainterConsole</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>5</string>
<key>CFBundleShortVersionString</key><string>0.4.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier com.m1ntch0c0.photopainter-console "$APP"
printf '%s\n' "$APP"
