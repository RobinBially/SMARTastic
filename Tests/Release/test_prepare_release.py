"""Offline regression tests for the release continuation decisions.

Run with: python3 -m unittest discover -s Tests/Release -v
"""
import io
import json
import os
from pathlib import Path
import plistlib
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import urllib.error


SCRIPT = Path(__file__).resolve().parents[2] / "scripts/prepare-release.py"
SOURCE = "a" * 40
VERSION = "1.1.0"
REPOSITORY = "example/SMARTastic"


class PrepareReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        old_cwd = Path.cwd()
        os.chdir(self.root)
        self.addCleanup(os.chdir, old_cwd)
        self.environment = {
            "VERSION": VERSION,
            "GITHUB_REPOSITORY": REPOSITORY,
            "GITHUB_SHA": SOURCE,
            "GH_TOKEN": "offline-test-placeholder",
            "GITHUB_RUN_ATTEMPT": "1",
            "GITHUB_RUN_ID": "123",
            "GITHUB_RUN_NUMBER": "15",
            "GITHUB_ENV": str(self.root / "github-env"),
            "GITHUB_OUTPUT": str(self.root / "github-output"),
        }
        self.release = None
        self.tag_commit = None
        self.previous = {"head_sha": SOURCE, "run_number": 8}
        self.artifacts = []
        self.build_conclusions = ["skipped"]
        self.commands = []
        self.restore = lambda: None

    def urlopen(self, request):
        self.assertEqual(request.full_url,
                         f"https://api.github.com/repos/{REPOSITORY}/releases/tags/v{VERSION}")
        if self.release is None:
            raise urllib.error.HTTPError(request.full_url, 404, "Not Found", {}, None)
        return io.BytesIO(json.dumps(self.release).encode())

    def check_output(self, arguments, **kwargs):
        self.commands.append(list(arguments))
        if arguments[:2] == ("git", "ls-remote"):
            return f"{self.tag_commit}\trefs/tags/v{VERSION}\n" if self.tag_commit else ""
        if arguments[:2] == ("git", "rev-parse"):
            return self.tag_commit + "\n"
        if arguments[:2] == ("gh", "api"):
            endpoint = arguments[2]
            if endpoint.endswith("/artifacts"):
                return json.dumps({"artifacts": self.artifacts})
            if endpoint.endswith("/jobs?filter=all"):
                return json.dumps({"jobs": [{"steps": [
                    {"name": "Build Universal app and notarize", "conclusion": conclusion}
                    for conclusion in self.build_conclusions
                ]}]})
            self.assertEqual(endpoint, f"repos/{REPOSITORY}/actions/runs/123")
            return json.dumps(self.previous)
        self.fail(f"Unexpected subprocess.check_output: {arguments!r}")

    def run_command(self, arguments, **kwargs):
        self.commands.append(list(arguments))
        allowed = {"git", "gh", "shasum", "ditto", "python3"}
        self.assertIn(arguments[0], allowed)
        if arguments[:3] == ["gh", "run", "download"]:
            self.restore()
        return subprocess.CompletedProcess(arguments, 0)

    def execute(self):
        with patch.dict(os.environ, self.environment, clear=True), \
                patch("urllib.request.urlopen", side_effect=self.urlopen), \
                patch("subprocess.check_output", side_effect=self.check_output), \
                patch("subprocess.run", side_effect=self.run_command):
            runpy.run_path(str(SCRIPT), run_name="__main__")

    def assert_result(self, mode, build=None):
        self.assertEqual((self.root / "github-output").read_text(), f"mode={mode}\n")
        env_file = self.root / "github-env"
        if build is None:
            self.assertFalse(env_file.exists())
        else:
            self.assertEqual(env_file.read_text(), f"BUILD_NUMBER={build}\n")

    def has_command(self, *prefix):
        return any(command[:len(prefix)] == list(prefix) for command in self.commands)

    def resume_with_artifact(self, *, archive=True, final=False, submitted=True):
        self.environment["RESUME_RUN_ID"] = "123"
        self.artifacts = [{"name": "smartastic-notarization-123", "expired": False}]

        def restore():
            output = self.root / ".build/releases"
            state = output / f".state-{VERSION}"
            state.mkdir(parents=True)
            (state / "source-commit").write_text(SOURCE + "\n")
            if submitted:
                (state / "submission-started").touch()
                (state / "submission.json").write_text('{"id":"existing-apple-submission"}')
            if archive:
                (state / "submission.zip").touch()
                (state / "submission.sha256").write_text("fixture checksum checked by mocked shasum")
                contents = state / "SMARTastic.app/Contents"
                contents.mkdir(parents=True)
                (contents / "Info.plist").write_bytes(plistlib.dumps({
                    "CFBundleShortVersionString": VERSION,
                    "CFBundleVersion": "7",
                }))
            if final:
                (output / f"SMARTastic-{VERSION}.zip").touch()
                (output / f"SMARTastic-{VERSION}.zip.sha256").touch()

        self.restore = restore

    def test_new_release_builds_with_new_build_number(self):
        self.execute()
        self.assert_result("build", 16)
        self.assertFalse(self.has_command("gh", "run", "download"))

    def test_existing_matching_release_continues_at_tap(self):
        self.tag_commit = SOURCE
        self.release = {"draft": False}
        self.execute()
        self.assert_result("tap")
        self.assertTrue(self.has_command("gh", "release", "download"))
        self.assertTrue(self.has_command("shasum", "-a", "256", "-c", f"SMARTastic-{VERSION}.zip.sha256"))
        self.assertFalse(self.has_command("gh", "run", "download"))

    def test_mismatching_tag_stops_before_downloading_artifacts(self):
        self.tag_commit = "b" * 40
        self.release = {"draft": False}
        with self.assertRaisesRegex(SystemExit, "another source commit"):
            self.execute()
        self.assertFalse(self.has_command("gh", "release", "download"))
        self.assertFalse((self.root / "github-output").exists())

    def test_saved_submission_preserves_bundle_build_number(self):
        self.resume_with_artifact()
        self.execute()
        self.assert_result("build", 7)
        self.assertTrue(self.has_command("gh", "run", "download", "123"))
        self.assertTrue(self.has_command("shasum", "-a", "256", "-c", "submission.sha256"))
        self.assertTrue(self.has_command("ditto", "-x", "-k"))

    def test_saved_final_archive_continues_at_publish(self):
        self.resume_with_artifact(final=True)
        self.execute()
        self.assert_result("publish", 7)
        self.assertTrue(self.has_command("shasum", "-a", "256", "-c", f"SMARTastic-{VERSION}.zip.sha256"))

    def test_pre_build_failure_rerun_without_artifact_is_safe(self):
        self.environment["GITHUB_RUN_ATTEMPT"] = "2"
        self.execute()
        self.assert_result("build", 9)
        self.assertFalse(self.has_command("gh", "run", "download"))

    def test_possible_submission_without_artifact_stops(self):
        self.environment["GITHUB_RUN_ATTEMPT"] = "2"
        self.build_conclusions = ["failure", "skipped"]
        with self.assertRaisesRegex(SystemExit, "possible submission"):
            self.execute()
        self.assertFalse((self.root / "github-output").exists())

    def test_partial_build_without_submission_is_safe(self):
        self.resume_with_artifact(archive=False, submitted=False)
        self.execute()
        self.assert_result("build", 9)
        self.assertFalse(self.has_command("ditto"))

    def test_submission_marker_without_archive_requires_recovery(self):
        self.resume_with_artifact(archive=False)
        with self.assertRaisesRegex(SystemExit, "lacks its archive"):
            self.execute()

    def test_unknown_prior_build_status_does_not_allow_new_submission(self):
        self.environment["GITHUB_RUN_ATTEMPT"] = "2"
        self.build_conclusions = []
        with self.assertRaisesRegex(SystemExit, "possible submission"):
            self.execute()

    def test_resume_from_another_commit_stops_before_download(self):
        self.resume_with_artifact()
        self.previous["head_sha"] = "b" * 40
        with self.assertRaisesRegex(SystemExit, "another source commit"):
            self.execute()
        self.assertFalse(self.has_command("gh", "run", "download"))


if __name__ == "__main__":
    unittest.main()
