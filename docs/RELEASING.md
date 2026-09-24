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
VERSION=1.1.0 ./scripts/release.sh              # build the notarized artifacts
VERSION=1.1.0 ./scripts/release.sh --publish    # also publish release and cask
```

`BUILD_NUMBER` defaults to the commit count, `CODE_SIGN_IDENTITY` to the first
Developer ID identity in the keychain, `NOTARY_PROFILE` to `localfoundry-notary`
and `RELEASE_REPOSITORY` to `RobinBially/SMARTastic`. `--dry-run` checks the
prerequisites without building, `--force` tolerates a dirty working tree and
`--draft` creates the GitHub release as a draft.

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

## Publishing a release

Releases run locally and from this checkout alone:

```bash
VERSION=1.1.1 ./scripts/release.sh --publish
```

Without `--publish` the script writes the artifacts and stops. With `--publish` it creates the GitHub release for the tagged commit and copies `Casks/smartastic.rb` into `localfoundry/homebrew-tap` — cloned temporarily when `TAP_DIR` is not a checkout — refusing a downgrade or a same-version cask with different bytes, then runs `brew audit --cask --strict --online`. `SKIP_AUDIT=1` skips that audit.

The shared driver `~/.agents/skills/macos-sign-release/scripts/release.sh --project smartastic --version x.y.z` is a convenience wrapper: it checks the prerequisites, resolves the signing identity, team ID and notary profile from `~/.config/macos-sign-release/config.json`, and then calls this same script with `--publish`.

Add `--dry-run` to check the prerequisites without building anything. The script requires a clean working tree (unless `--force`), a free version tag locally and remotely, and a usable notary profile; it runs the release and unit tests before it builds. Missing credentials, a failed test or an existing version tag stop the release before anything is published. No signing secret lives in GitHub.

For manual verification, download the published ZIP, check its checksum and launch the app on Apple Silicon and Intel.


## Artwork

`assets/logo.svg` is the editable vector source. The PNG previews and ICNS app
icon are committed so normal builds need no image tooling. To regenerate after
editing the SVG, install the optional `librsvg` Homebrew package and run
`./scripts/make-icons.sh`. It uses the standard 16–1024 pixel macOS icon sizes.
