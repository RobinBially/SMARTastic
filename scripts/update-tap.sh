#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERSION:?Set VERSION}"
: "${GH_TOKEN:?Set a token authorized for the tap}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
CASK="$PWD/.build/releases/Casks/smartastic.rb"
test -f "$CASK"
# This script runs on a disposable runner, after the release is public.
gh auth setup-git
gh repo clone localfoundry/homebrew-tap .build/tap
# Never let recovery of an old release downgrade the currently distributed app.
python3 - "$VERSION" "$CASK" <<'PYTHON'
import re, sys
from pathlib import Path
current=Path('.build/tap/Casks/smartastic.rb')
if current.exists():
    old=current.read_text()
    match=re.search(r'version "([0-9]+\.[0-9]+\.[0-9]+)"', old)
    if not match: raise SystemExit('Cannot safely compare the existing cask version.')
    previous=tuple(map(int, match[1].split('.')))
    incoming=tuple(map(int, sys.argv[1].split('.')))
    if previous > incoming:
        raise SystemExit('A newer SMARTastic release is already in the tap; refusing a downgrade.')
    if previous == incoming:
        new=Path(sys.argv[2]).read_text()
        for field in ['sha256','url']:
            pattern=field+r' "([^"\n]+)"'
            if re.search(pattern, old).group(1) != re.search(pattern, new).group(1):
                raise SystemExit('Existing version has different release bytes or URL; refusing replacement.')
PYTHON
cp "$CASK" .build/tap/Casks/smartastic.rb
python3 - <<'PY'
from pathlib import Path
p=Path('.build/tap/README.md')
s=p.read_text()
if '| `smartastic` |' not in s:
    anchor='|---|---|---|'
    assert anchor in s, 'Tap package table changed; update README explicitly.'
    s=s.replace(anchor, anchor+'\n| `smartastic` | Cask · Native macOS drive health monitor | [RobinBially/SMARTastic](https://github.com/RobinBially/SMARTastic) |', 1)
    s+='\n## Install SMARTastic\n\n```sh\nbrew install --cask localfoundry/tap/smartastic\n```\n\nRequires macOS 14+. The Universal app is signed and notarized. Homebrew also installs smartmontools.\n'
p.write_text(s)
PY
git -C .build/tap config user.name 'Robin Bially'
git -C .build/tap config user.email '7304732+RobinBially@users.noreply.github.com'
git -C .build/tap add Casks/smartastic.rb README.md
if ! git -C .build/tap diff --cached --quiet; then
    git -C .build/tap commit -m "Release SMARTastic $VERSION"
fi

brew tap localfoundry/tap "$PWD/.build/tap"
brew style localfoundry/tap/smartastic
brew audit --cask --strict --online localfoundry/tap/smartastic
brew install --cask localfoundry/tap/smartastic
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/SMARTastic.app/Contents/Info.plist)" = "$VERSION"
lipo /Applications/SMARTastic.app/Contents/MacOS/SMARTastic -verify_arch arm64 x86_64
codesign --verify --deep --strict /Applications/SMARTastic.app
xcrun stapler validate /Applications/SMARTastic.app
spctl --assess --type execute --verbose=4 /Applications/SMARTastic.app

git -C .build/tap push origin HEAD
