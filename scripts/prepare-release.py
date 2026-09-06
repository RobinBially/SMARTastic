#!/usr/bin/env python3
"""Resolve a new release, an interrupted submission, or a published release to finish."""
import json
import os
import re
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

version = os.environ['VERSION']
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('Version must be x.y.z')
repository = os.environ['GITHUB_REPOSITORY']
source = os.environ['GITHUB_SHA']
output = Path('.build/releases')
output.mkdir(parents=True, exist_ok=True)

def run(*args):
    return subprocess.check_output(args, text=True).strip()

request = urllib.request.Request(f'https://api.github.com/repos/{repository}/releases/tags/v{version}',
                                 headers={'Authorization': f'Bearer {os.environ["GH_TOKEN"]}', 'Accept': 'application/vnd.github+json'})
try:
    with urllib.request.urlopen(request) as response:
        release = json.load(response)
except urllib.error.HTTPError as error:
    if error.code != 404:
        raise
    release = None

refs = run('git', 'ls-remote', '--tags', 'origin', f'refs/tags/v{version}', f'refs/tags/v{version}^{{}}')
if refs:
    subprocess.run(['git', 'fetch', 'origin', f'refs/tags/v{version}:refs/tags/v{version}'], check=True)
    if run('git', 'rev-parse', f'v{version}^{{commit}}') != source:
        raise SystemExit('Existing version tag belongs to another source commit.')

mode = 'build'
if release:
    if release['draft'] or not refs:
        raise SystemExit('Existing release is a draft or has no public version tag; resolve it explicitly.')
    subprocess.run(['gh', 'release', 'download', f'v{version}', '--repo', repository,
                    '--pattern', f'SMARTastic-{version}.zip*', '--dir', str(output)], check=True)
    subprocess.run(['shasum', '-a', '256', '-c', f'SMARTastic-{version}.zip.sha256'], cwd=output, check=True)
    subprocess.run(['python3', 'scripts/generate-cask.py', '--version', version,
                    '--archive', str(output / f'SMARTastic-{version}.zip'),
                    '--output', str(output / 'Casks/smartastic.rb')], check=True)
    mode = 'tap'
else:
    resume = os.environ.get('RESUME_RUN_ID', '')
    if not resume and int(os.environ.get('GITHUB_RUN_ATTEMPT', '1')) > 1:
        resume = os.environ['GITHUB_RUN_ID']
    if resume:
        if not resume.isdecimal():
            raise SystemExit('Resume run ID must be numeric.')
        previous = json.loads(run('gh', 'api', f'repos/{repository}/actions/runs/{resume}'))
        if previous['head_sha'] != source:
            raise SystemExit('Resume run belongs to another source commit.')
        build = str(int(previous['run_number']) + 1)
        artifacts = json.loads(run('gh', 'api', f'repos/{repository}/actions/runs/{resume}/artifacts'))['artifacts']
        artifact_exists = any(item['name'] == f'smartastic-notarization-{resume}' and not item['expired'] for item in artifacts)
        if not artifact_exists:
            jobs = json.loads(run('gh', 'api', f'repos/{repository}/actions/runs/{resume}/jobs?filter=all'))['jobs']
            build_steps = [step for job in jobs for step in job.get('steps', [])
                           if step['name'] == 'Build Universal app and notarize']
            if not build_steps or any(step.get('conclusion') != 'skipped' for step in build_steps):
                raise SystemExit('No saved state after a possible submission. Recover the Apple submission manually.')
            # Tests or credential setup failed before the build/submit step; a fresh build is safe.
        else:
            subprocess.run(['gh', 'run', 'download', resume, '--repo', repository,
                            '--name', f'smartastic-notarization-{resume}', '--dir', str(output)], check=True)
            state = output / f'.state-{version}'
            if (state / 'source-commit').read_text().strip() != source:
                raise SystemExit('Saved notarization state belongs to another source commit.')
            if (state / 'submission.zip').exists():
                # Artifact files lose executable modes; restore the bundle from its ZIP.
                subprocess.run(['shasum', '-a', '256', '-c', 'submission.sha256'], cwd=state, check=True)
                subprocess.run(['ditto', '-x', '-k', str(state / 'submission.zip'), str(state)], check=True)
                import plistlib
                with (state / 'SMARTastic.app/Contents/Info.plist').open('rb') as file:
                    plist = plistlib.load(file)
                if plist['CFBundleShortVersionString'] != version:
                    raise SystemExit('Saved bundle version differs.')
                build = plist['CFBundleVersion']
            elif (state / 'submission-started').exists() or (state / 'submission.json').exists():
                raise SystemExit('Submission state lacks its archive. Recover it before continuing.')
            # A partial build with no submission marker can be safely rebuilt.
            if (output / f'SMARTastic-{version}.zip').exists():
                subprocess.run(['shasum', '-a', '256', '-c', f'SMARTastic-{version}.zip.sha256'], cwd=output, check=True)
                mode = 'publish'
    else:
        build = str(int(os.environ['GITHUB_RUN_NUMBER']) + 1)
    with open(os.environ['GITHUB_ENV'], 'a') as file:
        file.write(f'BUILD_NUMBER={build}\n')

with open(os.environ['GITHUB_OUTPUT'], 'a') as file:
    file.write(f'mode={mode}\n')
