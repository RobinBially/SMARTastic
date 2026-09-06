#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v rsvg-convert >/dev/null || { echo 'Install the optional SVG renderer: brew install librsvg' >&2; exit 1; }
mkdir -p .build/AppIcon.iconset
rsvg-convert -w 1024 -h 1024 assets/logo.svg -o assets/logo.png
sips -z 256 256 assets/logo.png --out Sources/SMARTastic/Resources/logo.png >/dev/null
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" assets/logo.png --out ".build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" assets/logo.png --out ".build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns .build/AppIcon.iconset -o assets/AppIcon.icns
