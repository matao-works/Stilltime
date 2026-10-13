#!/bin/sh
set -eu
cd "$(dirname "$0")"
APP="Stilltime.app"
VERSION=$(cat VERSION)
BUILD_DIR=".build"
mkdir -p "$BUILD_DIR" "$APP/Contents/MacOS" "$APP/Contents/Resources"
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/private/tmp}/stilltime-clang-cache"
case "${1:---universal}" in
  --universal) ARCHITECTURES="arm64 x86_64" ;;
  --native) ARCHITECTURES="$(uname -m)" ;;
  *) printf 'Usage: %s [--universal|--native]\n' "$0" >&2; exit 2 ;;
esac
for ARCH in $ARCHITECTURES; do
  swiftc -target "$ARCH-apple-macos13.0" -parse-as-library -swift-version 6 -O \
    -framework SwiftUI -framework AppKit -framework Combine \
    Sources/WorkingTime/main.swift -o "$BUILD_DIR/Stilltime-$ARCH"
done
if [ "$ARCHITECTURES" = "arm64 x86_64" ]; then
  lipo -create "$BUILD_DIR/Stilltime-arm64" "$BUILD_DIR/Stilltime-x86_64" -output "$APP/Contents/MacOS/Stilltime"
else
  cp "$BUILD_DIR/Stilltime-$ARCHITECTURES" "$APP/Contents/MacOS/Stilltime"
fi
if [ ! -f Assets/AppIcon.icns ]; then
  swift scripts/make-icon.swift Assets/AppIcon.iconset
  python3 scripts/make-icns.py Assets/AppIcon.iconset Assets/AppIcon.icns
fi
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Stilltime</string>
<key>CFBundleIdentifier</key><string>com.stilltime.WorkingTime</string>
<key>CFBundleName</key><string>Stilltime</string>
<key>CFBundleDisplayName</key><string>Stilltime</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built %s (%s), version %s\n' "$APP" "$ARCHITECTURES" "$VERSION"
