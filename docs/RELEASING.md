# Releasing SMARTastic

SMARTastic requires macOS 14 or later. The stable bundle identifier remains
`com.opencode.SMARTastic`. Releases use semantic versions; this overhaul is 1.1.0,
build 2. The release ZIP contains a Universal app (arm64 and x86_64).

## Development and verification

Use full Xcode 26.3 or later. If `xcode-select -p` selects Command Line Tools,
set `DEVELOPER_DIR` to the installed Xcode's `Contents/Developer` directory for
these commands. The standalone macOS 27 Command Line Tools currently lack the
SwiftUI macro plugin needed by that SDK; the full Xcode toolchain works.

```sh
swift test
ARCHS="arm64 x86_64" ./scripts/make-app.sh
open .build/app/SMARTastic.app
```

The script defaults to a release build with an ad-hoc signature, which is only
for local development. `CONFIGURATION=debug` makes a debug bundle. The optional
first argument is an output directory. Existing bundles at that destination are
replaced only after the new bundle passes signature verification.

The resource bundle lives inside `Contents/Resources`. AppResources resolves it
there before trying SwiftPM's development resolver. Test the app after copying
it outside the checkout; it must not depend on `.build` at runtime.

## Signed, notarized release

A valid Developer ID Application identity and an authenticated notarytool
keychain profile are required. Keep private keys and passwords out of this repo.

```sh
VERSION=1.1.0 BUILD_NUMBER=2 \
CODE_SIGN_IDENTITY='Developer ID Application: NAME (TEAMID)' \
NOTARY_PROFILE='PROFILE_NAME' \
./scripts/release.sh .build/releases
```

The script builds Universal, signs with Hardened Runtime and a secure timestamp,
submits to Apple, requires `Accepted`, staples the app, verifies its signature and
Gatekeeper assessment, then produces:

- `SMARTastic-VERSION.zip`
- `SMARTastic-VERSION.zip.sha256`
- `Casks/smartastic.rb`, with the final archive's SHA-256

`CODE_SIGN_KEYCHAIN` and `NOTARY_KEYCHAIN` optionally select a temporary CI
keychain. No special entitlements, helper daemon, sudo, or bundled smartctl are
required. Homebrew installs smartmontools as a separate dependency.

Submission ID, source commit, archive digest and the submitted bundle remain in
`.build/releases/.state-VERSION`. A timeout can be resumed from the same source
and state directory without another submission. If submission was interrupted
before its ID was saved, recover the matching ID with `notarytool history`; do
not submit again blindly. Invalid submissions require fixing the cause and a
fresh version/state directory. Never overwrite a published release archive.

## GitHub Actions and Homebrew

`build.yml` tests and builds both architectures without signing secrets.
`release.yml` is manually dispatched with a version, validates release/tap access,
runs tests, signs and notarizes, publishes the immutable GitHub release, and then
updates `localfoundry/homebrew-tap`.

A rerun of an interrupted job restores the saved artifact for that run. A new
workflow dispatch can specify `resume_run_id` to restore an older submission;
use the same source commit. The original bundle build number is retained.
If the matching public release already exists, the workflow checks the tag's
source commit and archive checksum, then resumes directly at tap distribution.
Notary artifacts are retained for seven days; download them before expiry if
manual follow-up is needed. Resume stops if the original state is unavailable.

Required secrets in the repository running the signing job:

| Secret | Purpose |
| --- | --- |
| `CSC_LINK` | Base64 PKCS#12 containing Developer ID certificate and private key |
| `CSC_KEY_PASSWORD` | Password for the PKCS#12 |
| `APPLE_ID` | Notarization Apple ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | Notarization app-specific password |
| `APPLE_TEAM_ID` | Apple Developer team |
| `TAP_GITHUB_TOKEN` | Write access to localfoundry/homebrew-tap |

Secrets are imported after tests into a temporary keychain and cleaned up even
on failure. Local identities and profile names do not exist on a fresh runner.
A separate existing signing repository may run the same build against a pinned
SMARTastic commit and return only the artifacts; secrets must stay there.

Publish only after all checks pass, verify the public download against its
checksum, then update the tap's cask and package list. The tap must reference the
versioned download URL, never `latest` or `sha256 :no_check`. Validate with:

```sh
brew style localfoundry/tap/smartastic
brew audit --cask --strict --online localfoundry/tap/smartastic
brew install --cask localfoundry/tap/smartastic
codesign --verify --deep --strict /Applications/SMARTastic.app
xcrun stapler validate /Applications/SMARTastic.app
spctl --assess --type execute --verbose=4 /Applications/SMARTastic.app
```

Respect branch protection. A release with an unmerged tap update is not fully
shipped. Use GitHub noreply metadata for commits and tags. Intel execution needs
an Intel Mac; a Universal build and `lipo` check alone do not prove that runtime.

## Artwork

`assets/logo.svg` is the editable vector source. The PNG previews and ICNS app
icon are committed so normal builds need no image tooling. To regenerate after
editing the SVG, install the optional `librsvg` Homebrew package and run
`./scripts/make-icons.sh`. It uses the standard 16–1024 pixel macOS icon sizes.
