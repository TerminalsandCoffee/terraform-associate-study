"""Exercise git-night against disposable local repos; never push to GitHub."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "git-night.ps1"


@unittest.skipUnless(shutil.which("pwsh") and shutil.which("git"), "requires pwsh and git")
class GitNightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / "remote.git"
        self.work = self.root / "work"
        self.work.mkdir()
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_TERMINAL_PROMPT="0")
        # Isolate identity, global hooks, URL rewrites, signing, and credential config.
        self.config = self.root / "gitconfig"
        self.config.write_text("[user]\n name = Test\n email = test@example.invalid\n")
        self.env["GIT_CONFIG_GLOBAL"] = str(self.config)
        self.git("init", "--bare", "--initial-branch=main", str(self.remote))
        self.git("init", "--initial-branch=main")
        (self.work / "tracked.txt").write_text("base\n")
        self.git("add", ".")
        self.git("commit", "-m", "Initial")
        self.git("remote", "add", "origin", "https://github.com/example/study.guide.git")
        self.git("config", f"url.{self.remote.as_posix()}.insteadOf", "https://github.com/example/study.guide.git")
        self.git("push", "-u", "origin", "main")
        self.git("symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
        self.original = self.git("rev-parse", "main")
        self.browser = self.root / "opened-url.txt"

    def git(self, *args, cwd=None):
        result = subprocess.run(["git", *args], cwd=cwd or self.work, env=self.env,
                                text=True, capture_output=True, check=True)
        return result.stdout.strip()

    def run_helper(self, *args, native_errors=False):
        # Browser launch is the only stub; Git, hooks, branches, and pushes are real.
        wrapper = self.root / "run.ps1"
        wrapper.write_text(
            ("$PSNativeCommandUseErrorActionPreference = $true\n" if native_errors else "") +
            "function Start-Process { param($FilePath, $WindowStyle) "
            "Set-Content -LiteralPath $env:TEST_BROWSER_PATH -Value $FilePath }\n"
            "& $env:TEST_SCRIPT_PATH -Message 'Review changes' @args\n"
            "exit $LASTEXITCODE\n",
            encoding="utf-8")
        env = dict(self.env, TEST_BROWSER_PATH=str(self.browser), TEST_SCRIPT_PATH=str(SCRIPT))
        return subprocess.run(["pwsh", "-NoProfile", "-File", str(wrapper), *args],
                              cwd=self.work, env=env, text=True, capture_output=True)

    def change(self):
        (self.work / "tracked.txt").write_text("local change\n")

    def test_success_preserves_main_and_pushes_feature_branch(self):
        self.change()
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git("rev-parse", "main"), self.original)
        branch = self.git("branch", "--show-current")
        self.assertNotEqual(branch, "main")
        self.assertEqual(self.git("rev-parse", "HEAD"),
                         self.git("rev-parse", f"refs/heads/{branch}", cwd=self.remote))
        self.assertIn("example/study.guide/compare/main...", self.browser.read_text())

    def test_failed_checkout_never_commits_on_main(self):
        peer = self.root / "peer"
        self.git("clone", str(self.remote), str(peer))
        (peer / "tracked.txt").write_text("remote change\n")
        self.git("add", ".", cwd=peer)
        self.git("commit", "-m", "Remote change", cwd=peer)
        self.git("push", cwd=peer)
        self.change()
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("rev-parse", "main"), self.original)
        self.assertEqual((self.work / "tracked.txt").read_text(), "local change\n")
        self.assertFalse(self.browser.exists())

    def test_staged_changes_work_with_native_error_preference_enabled(self):
        self.change()
        result = self.run_helper(native_errors=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotEqual(self.git("rev-parse", "HEAD"), self.original)
        self.assertEqual(self.git("rev-parse", "main"), self.original)
        self.assertTrue(self.browser.exists())

    def test_commit_hooks_run_by_default(self):
        hook = self.work / ".git" / "hooks" / "pre-commit"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        self.change()
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.original)
        self.assertFalse(self.browser.exists())

    def test_push_failure_does_not_open_compare_or_report_success(self):
        hook = self.remote / "hooks" / "pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        self.change()
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.browser.exists())

    def test_force_with_no_changes_exits_cleanly(self):
        result = self.run_helper("-Force")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.original)
        self.assertFalse(self.browser.exists())

    def test_detached_head_fails_without_committing(self):
        self.git("checkout", "--detach")
        self.change()
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.original)
        self.assertFalse(self.browser.exists())

    def test_unpushed_main_commits_are_not_left_behind(self):
        (self.work / "local.txt").write_text("unpublished work\n")
        self.git("add", ".")
        self.git("commit", "-m", "Unpublished")
        local_head = self.git("rev-parse", "HEAD")
        self.change()
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), local_head)
        self.assertEqual(self.git("branch", "--show-current"), "main")
        self.assertTrue((self.work / "local.txt").exists())


if __name__ == "__main__":
    unittest.main()
