#!/usr/bin/env python3
"""Generate a cask only from the final, verified release ZIP."""
import argparse
import hashlib
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--version', required=True)
parser.add_argument('--archive', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
if not re.fullmatch(r'\d+\.\d+\.\d+', args.version):
    parser.error('Version must be x.y.z')
if args.archive.name != f'SMARTastic-{args.version}.zip':
    parser.error('Archive name must match version')
sha = hashlib.sha256(args.archive.read_bytes()).hexdigest()
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(f'''cask "smartastic" do
  version "{args.version}"
  sha256 "{sha}"

  url "https://github.com/RobinBially/SMARTastic/releases/download/v#{{version}}/SMARTastic-#{{version}}.zip"
  name "SMARTastic"
  desc "Native SSD and HDD health monitor"
  homepage "https://github.com/RobinBially/SMARTastic"

  depends_on formula: "smartmontools"
  depends_on macos: :sonoma

  app "SMARTastic.app"
end
''')
