"""Check disposable sessions and cleanup without installing anything on the host."""
import json
import os
from pathlib import Path
import pty
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

REPO = Path(__file__).resolve().parents[1]


class RemoteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nvim remote ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        shutil.copytree(REPO / "scripts", self.repo / "scripts")
        shutil.copytree(REPO / "lua", self.repo / "lua")
        for name in ("init.lua", "lazy-lock.json", "lazyvim.json"):
            shutil.copy2(REPO / name, self.repo / name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.temp_sessions = self.root / "sessions"
        self.temp_sessions.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        (self.home / "keep.txt").write_text("existing user data")
        self.log = self.root / "calls.jsonl"
        self.env = dict(os.environ, HOME=str(self.home), PATH=f"{self.bin}:{os.defpath}",
                        TMPDIR=str(self.temp_sessions), NVIM_TEST_LOG=str(self.log),
                        NVIM_APPNAME="existing-profile", XDG_CONFIG_HOME=str(self.home / "config"))
        self.executable("nvim", f"#!{sys.executable}\n" + '''import json, os, pathlib, sys, time
clean = "--clean" in sys.argv
config = pathlib.Path(os.environ["XDG_CONFIG_HOME"]) / os.environ["NVIM_APPNAME"]
with open(os.environ["NVIM_TEST_LOG"], "a") as log:
    log.write(json.dumps({"args": sys.argv[1:], "app": os.environ["NVIM_APPNAME"],
                          "server": os.getenv("NVIM_SERVER_MODE"), "cwd": os.getcwd(),
                          "config": str(config), "data": os.environ["XDG_DATA_HOME"],
                          "state": os.environ["XDG_STATE_HOME"], "cache": os.environ["XDG_CACHE_HOME"],
                          "runtime": os.environ["XDG_RUNTIME_DIR"], "tmp": os.environ["TMPDIR"],
                          "extras": json.loads((config / "lazyvim.json").read_text())["extras"],
                          "private": oct(config.parent.parent.stat().st_mode & 0o777)}) + "\\n")
if not clean:
    if os.getenv("NVIM_TEST_WAIT"):
        time.sleep(30)
    pathlib.Path(os.getenv("NVIM_TEST_FILE", str(config / "edited"))).write_text("saved work")
sys.exit(int(os.getenv("NVIM_TEST_VERSION_EXIT" if clean else "NVIM_TEST_EXIT", "0")))
''')
        # These tools must never be needed by the disposable server profile.
        for tool in ("sudo", "npm", "cc", "tree-sitter"):
            self.executable(tool, "#!/bin/sh\nexit 99\n")

    def executable(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def run_session(self, *args, script="remote.sh", interactive=True):
        command = [str(self.repo / "scripts" / script), *args]
        if not interactive:
            return subprocess.run(command, env=self.env, cwd=self.root, input="",
                                  capture_output=True, text=True, timeout=10)
        master, slave = pty.openpty()
        try:
            return subprocess.run(command, env=self.env, cwd=self.root, stdin=slave,
                                  stdout=slave, stderr=subprocess.PIPE, timeout=10)
        finally:
            os.close(master)
            os.close(slave)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def assert_cleaned(self):
        self.assertEqual(list(self.temp_sessions.iterdir()), [])
        self.assertEqual((self.home / "keep.txt").read_text(), "existing user data")
        self.assertEqual(sorted(p.name for p in self.home.iterdir()), ["keep.txt"])

    def test_isolation_saved_files_and_cleanup(self):
        edited = self.root / "work file"
        self.env["NVIM_TEST_FILE"] = str(edited)
        before = (self.repo / "lazyvim.json").read_bytes()
        self.assertEqual(self.run_session(str(edited)).returncode, 0)
        call = self.calls()[-1]
        self.assertEqual(call["args"][-1], str(edited))
        self.assertEqual(call["cwd"], str(self.root))
        self.assertEqual(call["app"], "jose-nvim")
        self.assertEqual(call["server"], "1")
        self.assertEqual(call["private"], "0o700")
        self.assertEqual(call["extras"], [])
        for key in ("config", "data", "state", "cache", "runtime", "tmp"):
            self.assertTrue(Path(call[key]).is_relative_to(self.temp_sessions))
        self.assertEqual(edited.read_text(), "saved work")
        self.assertEqual((self.repo / "lazyvim.json").read_bytes(), before)
        self.assert_cleaned()

    def test_nonzero_editor_exit_cleans_up_and_preserves_status(self):
        self.env["NVIM_TEST_EXIT"] = "7"
        self.assertEqual(self.run_session().returncode, 7)
        self.assert_cleaned()

    def test_relative_temp_directory_is_made_absolute(self):
        self.env["TMPDIR"] = "sessions"
        self.assertEqual(self.run_session().returncode, 0)
        self.assertTrue(Path(self.calls()[-1]["config"]).is_absolute())
        self.assert_cleaned()

    def test_download_failure_cleans_up(self):
        self.env["NVIM_TEST_VERSION_EXIT"] = "1"
        self.executable("curl", "#!/bin/sh\nexit 22\n")
        self.assertEqual(self.run_session().returncode, 22)
        self.assert_cleaned()

    def test_downloads_private_neovim_for_old_host_version(self):
        self.env["NVIM_TEST_VERSION_EXIT"] = "1"
        self.executable("curl", "#!/bin/sh\nexit 0\n")
        # Use the same fake Neovim in the simulated extracted archive, now current.
        script = (self.bin / "nvim").read_text().replace('int(os.getenv("NVIM_TEST_VERSION_EXIT" if clean else "NVIM_TEST_EXIT", "0"))', '0')
        self.env["NVIM_TEST_DOWNLOADED"] = script
        self.executable("tar", f"#!{sys.executable}\n" + '''import os, pathlib, sys
root = pathlib.Path(sys.argv[sys.argv.index("-C") + 1])
for platform in ("linux", "macos"):
    for arch in ("x86_64", "arm64"):
        binary = root / f"nvim-{platform}-{arch}" / "bin" / "nvim"
        binary.parent.mkdir(parents=True)
        binary.write_text(os.environ["NVIM_TEST_DOWNLOADED"])
        binary.chmod(0o755)
''')
        self.assertEqual(self.run_session().returncode, 0)
        self.assertEqual(len(self.calls()), 2)
        self.assert_cleaned()

    def test_standalone_downloads_configuration(self):
        # A script fetched through process substitution has no adjacent checkout.
        standalone = self.root / "standalone" / "scripts"
        standalone.mkdir(parents=True)
        shutil.copy2(REPO / "scripts" / "remote.sh", standalone / "remote.sh")
        self.repo = standalone.parent
        self.executable("curl", f"#!{sys.executable}\n" + '''import os, pathlib, sys
pathlib.Path(sys.argv[sys.argv.index("-o") + 1]).write_text("archive")
''')
        self.executable("tar", f"#!{sys.executable}\n" + f'''import pathlib, shutil, sys
root = pathlib.Path(sys.argv[sys.argv.index("-C") + 1])
source = pathlib.Path({str(REPO)!r})
for name in ("init.lua", "lazy-lock.json"):
    shutil.copy2(source / name, root / name)
shutil.copytree(source / "lua", root / "lua")
''')
        self.assertEqual(self.run_session().returncode, 0)
        self.assert_cleaned()

    def test_bootstrap_remote_dispatches_before_full_dependency_checks(self):
        self.assertEqual(self.run_session("remote", script="bootstrap.sh").returncode, 0)
        self.assertEqual(len(self.calls()), 2)
        self.assert_cleaned()

    def test_help_and_noninteractive_failure_do_not_create_a_session(self):
        self.assertEqual(self.run_session("--help", interactive=False).returncode, 0)
        self.assertNotEqual(self.run_session(interactive=False).returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assert_cleaned()

    def test_hangup_and_termination_cleanup(self):
        self.env["NVIM_TEST_WAIT"] = "1"
        for sig in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=sig):
                self.log.unlink(missing_ok=True)
                master, slave = pty.openpty()
                process = subprocess.Popen([str(self.repo / "scripts" / "remote.sh")],
                                           env=self.env, cwd=self.root, stdin=slave,
                                           stdout=slave, stderr=subprocess.DEVNULL, start_new_session=True)
                try:
                    deadline = time.monotonic() + 5
                    while len(self.calls()) < 2 and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertEqual(len(self.calls()), 2)
                    os.killpg(process.pid, sig)
                    self.assertEqual(process.wait(timeout=5), 128 + sig)
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                    os.close(master)
                    os.close(slave)
                self.assert_cleaned()


if __name__ == "__main__":
    unittest.main()
