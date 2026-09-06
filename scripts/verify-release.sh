#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERSION:?Set VERSION}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
OUTPUT="$PWD/.build/releases"
(cd "$OUTPUT" && shasum -a 256 -c "SMARTastic-$VERSION.zip.sha256")
CHECK="$(mktemp -d "$PWD/.build/verify.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
ditto -x -k "$OUTPUT/SMARTastic-$VERSION.zip" "$CHECK"
APP="$CHECK/SMARTastic.app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "$VERSION"
./scripts/check-architectures.sh "$APP/Contents/MacOS/SMARTastic"
codesign --verify --deep --strict --verbose=2 "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=4 "$APP"
python3 scripts/generate-cask.py --version "$VERSION" --archive "$OUTPUT/SMARTastic-$VERSION.zip" --output "$OUTPUT/Casks/smartastic.rb"
