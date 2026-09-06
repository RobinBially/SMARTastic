#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERSION:?Set VERSION (x.y.z)}"
: "${BUILD_NUMBER:?Set BUILD_NUMBER}"
: "${CODE_SIGN_IDENTITY:?Set a Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set an existing notarytool profile}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
[[ "$CODE_SIGN_IDENTITY" == 'Developer ID Application: '* ]] || exit 1
OUTPUT="${1:-$PWD/.build/releases}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
ARCHIVE="SMARTastic-$VERSION.zip"
[[ ! -e "$OUTPUT/$ARCHIVE" ]] || { echo 'Final archive already exists; do not overwrite a release.' >&2; exit 1; }
git diff --quiet HEAD || { echo 'Commit source changes before releasing.' >&2; exit 1; }
[[ -z "$(git ls-files --others --exclude-standard)" ]] || { echo 'Untracked source files: commit or ignore them before releasing.' >&2; exit 1; }
STATE="$OUTPUT/.state-$VERSION"
mkdir -p "$STATE"
SOURCE_COMMIT="$(git rev-parse HEAD)"
if [[ -e "$STATE/source-commit" ]]; then
    [[ "$(cat "$STATE/source-commit")" == "$SOURCE_COMMIT" ]] || { echo 'Resume source differs from submission.' >&2; exit 1; }
else
    printf '%s\n' "$SOURCE_COMMIT" > "$STATE/source-commit"
fi
APP="$STATE/SMARTastic.app"
if [[ ! -e "$STATE/submission.zip" ]]; then
    ARCHS="arm64 x86_64" ./scripts/make-app.sh "$STATE"
    ./scripts/check-architectures.sh "$APP/Contents/MacOS/SMARTastic"
    ditto -c -k --keepParent "$APP" "$STATE/submission.zip"
    (cd "$STATE" && shasum -a 256 submission.zip > submission.sha256)
fi
notary_options=(--keychain-profile "$NOTARY_PROFILE")
if [[ -n "${NOTARY_KEYCHAIN:-}" ]]; then notary_options+=(--keychain "$NOTARY_KEYCHAIN"); fi
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$VERSION" ]] || exit 1
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")" == "$BUILD_NUMBER" ]] || { echo 'Resume build number differs.' >&2; exit 1; }
codesign --verify --deep --strict "$APP"
(cd "$STATE" && shasum -a 256 -c submission.sha256)
if [[ ! -s "$STATE/submission.json" ]]; then
    [[ ! -e "$STATE/submission-started" ]] || { echo 'Submission interrupted: recover its ID from notarytool history before retrying.' >&2; exit 1; }
    touch "$STATE/submission-started"
    xcrun notarytool submit "$STATE/submission.zip" "${notary_options[@]}" --output-format json > "$STATE/submission.json"
fi
SUBMISSION_ID="$(plutil -extract id raw -o - "$STATE/submission.json")"
xcrun notarytool wait "$SUBMISSION_ID" "${notary_options[@]}" --timeout 30m --output-format json > "$STATE/status.json"
[[ "$(plutil -extract status raw -o - "$STATE/status.json")" == Accepted ]] || {
    echo "Not accepted. Inspect notarytool log for $SUBMISSION_ID; submission state is preserved." >&2; exit 1;
}
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"
ditto -c -k --keepParent "$APP" "$STATE/$ARCHIVE"
(cd "$STATE" && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
python3 scripts/generate-cask.py --version "$VERSION" --archive "$STATE/$ARCHIVE" --output "$OUTPUT/Casks/smartastic.rb"
mv "$STATE/$ARCHIVE" "$STATE/$ARCHIVE.sha256" "$OUTPUT/"
echo "Verified release: $OUTPUT/$ARCHIVE"
