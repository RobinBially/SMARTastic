#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-2}"
CONFIGURATION="${CONFIGURATION:-release}"
ARCHS="${ARCHS:-$(uname -m)}"
IDENTITY="${CODE_SIGN_IDENTITY:--}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'VERSION must be x.y.z' >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid BUILD_NUMBER' >&2; exit 1; }
[[ "$CONFIGURATION" == release || "$CONFIGURATION" == debug ]] || exit 1
OUTPUT="${1:-$PWD/.build/app}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
STAGING="$(mktemp -d "$OUTPUT/.bundle.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/SMARTastic.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
binaries=()
for arch in $ARCHS; do
    [[ "$arch" == arm64 || "$arch" == x86_64 ]] || exit 1
    swift build -c "$CONFIGURATION" --arch "$arch"
    bin_dir="$(swift build -c "$CONFIGURATION" --arch "$arch" --show-bin-path)"
    cp "$bin_dir/SMARTastic" "$STAGING/SMARTastic-$arch"
    binaries+=("$STAGING/SMARTastic-$arch")
    if [[ ! -d "$APP/Contents/Resources/SMARTastic_SMARTastic.bundle" ]]; then
        ditto "$bin_dir/SMARTastic_SMARTastic.bundle" "$APP/Contents/Resources/SMARTastic_SMARTastic.bundle"
    fi
done
lipo -create "${binaries[@]}" -output "$APP/Contents/MacOS/SMARTastic"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SMARTastic</string>
<key>CFBundleIdentifier</key><string>com.opencode.SMARTastic</string>
<key>CFBundleName</key><string>SMARTastic</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>de</string><string>es</string><string>fr</string><string>zh-Hans</string></array>
</dict></plist>
PLIST
sign_options=(--force --sign "$IDENTITY")
if [[ "$IDENTITY" != - ]]; then sign_options+=(--options runtime --timestamp); fi
if [[ -n "${CODE_SIGN_KEYCHAIN:-}" ]]; then sign_options+=(--keychain "$CODE_SIGN_KEYCHAIN"); fi
codesign "${sign_options[@]}" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
# Only replace the requested development bundle after all build/signing checks pass.
if [[ -e "$OUTPUT/SMARTastic.app" ]]; then mv "$OUTPUT/SMARTastic.app" "$STAGING/previous.app"; fi
mv "$APP" "$OUTPUT/SMARTastic.app"
echo "App ready: $OUTPUT/SMARTastic.app"
