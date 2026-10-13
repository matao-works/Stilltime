#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./build.sh --universal
VERSION=$(cat VERSION)
mkdir -p dist .build/dmg
DITTO=/usr/bin/ditto
$DITTO -c -k --sequesterRsrc --keepParent Stilltime.app "dist/Stilltime-$VERSION-universal.zip"
$DITTO Stilltime.app .build/dmg/Stilltime.app
ln -sfn /Applications .build/dmg/Applications
cp docs/INSTALL.txt .build/dmg/安装说明.txt
if hdiutil create -ov -volname "Stilltime" -srcfolder .build/dmg -format UDZO "dist/Stilltime-$VERSION-universal.dmg"; then
  (cd dist && shasum -a 256 "Stilltime-$VERSION-universal.zip" "Stilltime-$VERSION-universal.dmg" > SHA256SUMS.txt)
else
  printf 'Disk image unavailable in this environment; ZIP installer is ready.\n'
  (cd dist && shasum -a 256 "Stilltime-$VERSION-universal.zip" > SHA256SUMS.txt)
fi
printf 'Release files ready in dist/\n'
