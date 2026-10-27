"""Exercise native setup without downloads or touching the user's configuration."""
import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import sys
import tempfile
import unittest


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nvim setup ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo with spaces"
        shutil.copytree(Path(__file__).resolve().parents[1] / "scripts", self.repo / "scripts")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.root), NVIM_APPNAME="jose-nvim",
                        XDG_CONFIG_HOME=str(self.root / "config"),
                        XDG_DATA_HOME=str(self.root / "data"),
                        XDG_STATE_HOME=str(self.root / "state"),
                        XDG_CACHE_HOME=str(self.root / "cache"),
                        PATH=f"{self.bin}:{os.defpath}",
                        NVIM_TEST_LOG=str(self.root / "calls.jsonl"))
        self.env.pop("NVIM_WORKSPACE", None)
        self.env.pop("NVIM_REDUCED_MOTION", None)
        for tool in ("git", "cc", "curl", "rg", "node", "tree-sitter", "unzip", "fdfind"):
            self.executable(tool, "#!/bin/sh\nexit 0\n")
        self.executable("nvim", f"#!{sys.executable}\n" + '''import json, os, sys
with open(os.environ["NVIM_TEST_LOG"], "a") as log:
    log.write(json.dumps({"args": sys.argv[1:], "app": os.environ["NVIM_APPNAME"],
                          "motion": os.getenv("NVIM_REDUCED_MOTION"),
                          "cwd": os.getcwd()}) + "\\n")
sys.exit(int(os.getenv("NVIM_TEST_VERSION_EXIT" if "--clean" in sys.argv else "NVIM_TEST_SETUP_EXIT", "0")))
''')

    def executable(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def run_script(self, *args, script="bootstrap.sh", interactive=False):
        command = [str(self.repo / "scripts" / script), *args]
        if interactive:
            master, slave = pty.openpty()
            try:
                return subprocess.run(command, cwd=self.root, env=self.env, stdin=slave,
                                      stdout=slave, stderr=subprocess.PIPE, timeout=10)
            finally:
                os.close(master)
                os.close(slave)
        return subprocess.run(command, cwd=self.root, env=self.env, input="",
                              capture_output=True, text=True, timeout=10)

    def calls(self):
        log = self.root / "calls.jsonl"
        return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

    def destination(self):
        return Path(self.env["XDG_CONFIG_HOME"]) / self.env["NVIM_APPNAME"]

    def test_help_does_not_need_neovim(self):
        (self.bin / "nvim").unlink()
        self.assertEqual(self.run_script("--help").returncode, 0)
        self.assertFalse(self.destination().exists())

    def test_doctor_checks_without_installing(self):
        self.assertEqual(self.run_script("doctor").returncode, 0)
        self.assertFalse(self.destination().exists())
        self.assertEqual(len(self.calls()), 1)

    def test_missing_dependency_and_old_neovim_fail_before_install(self):
        for env, text in (({}, "Missing dependency: tree-sitter"),
                          ({"NVIM_TEST_VERSION_EXIT": "1"}, "Neovim 0.11.5")):
            with self.subTest(env=env):
                if not env:
                    (self.bin / "tree-sitter").unlink()
                self.env.update(env)
                result = self.run_script("install")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(text, result.stderr)
                self.assertFalse(self.destination().exists())
                self.executable("tree-sitter", "#!/bin/sh\nexit 0\n")

    def test_install_is_repeatable_and_uses_same_profile(self):
        self.env["NVIM_APPNAME"] = "custom-profile"
        for _ in range(2):
            self.assertEqual(self.run_script("install").returncode, 0)
            self.assertEqual(self.destination().resolve(), self.repo)
        setups = [call for call in self.calls() if "--clean" not in call["args"]]
        self.assertEqual(len(setups), 2)
        for call in setups:
            self.assertEqual(call["app"], "custom-profile")
            self.assertEqual(call["motion"], "1")
            self.assertIn("+Lazy! restore", call["args"])
            self.assertIn("/scripts/check.lua", call["args"][-1])

    def test_existing_configuration_and_dangling_link_are_preserved(self):
        self.destination().mkdir(parents=True)
        marker = self.destination() / "init.lua"
        marker.write_text("existing config")
        self.assertNotEqual(self.run_script("install").returncode, 0)
        self.assertEqual(marker.read_text(), "existing config")
        marker.unlink()
        self.destination().rmdir()
        self.destination().symlink_to(self.root / "missing")
        self.assertNotEqual(self.run_script("install").returncode, 0)
        self.assertEqual(os.readlink(self.destination()), str(self.root / "missing"))
        self.assertTrue(all("--clean" in call["args"] for call in self.calls()))

    def test_invalid_profile_is_rejected(self):
        self.env["NVIM_APPNAME"] = "../unsafe"
        for script in ("install.sh", "bootstrap.sh"):
            self.assertNotEqual(self.run_script("install", script=script).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_noninteractive_edit_does_not_install(self):
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertFalse(self.destination().exists())

    def test_test_command_runs_headlessly(self):
        self.assertEqual(self.run_script("test").returncode, 0)
        self.assertEqual(len(self.calls()), 2)

    def test_setup_failure_is_propagated(self):
        self.env["NVIM_TEST_SETUP_EXIT"] = "3"
        self.assertEqual(self.run_script("install").returncode, 3)

    def test_edit_preserves_workspace_arguments_and_motion(self):
        workspace = self.root / "project with spaces"
        workspace.mkdir()
        self.env.update(NVIM_WORKSPACE=str(workspace), NVIM_REDUCED_MOTION="0")
        self.assertEqual(self.run_script("file with spaces.lua", interactive=True).returncode, 0)
        call = self.calls()[-1]
        self.assertEqual(call["cwd"], str(workspace))
        self.assertEqual(call["args"], ["file with spaces.lua"])
        self.assertEqual(call["motion"], "0")

    def test_edit_defaults_to_callers_directory(self):
        self.assertEqual(self.run_script(interactive=True).returncode, 0)
        self.assertEqual(self.calls()[-1]["cwd"], str(self.root))

    def test_invalid_workspace_and_extra_command_arguments_fail_before_install(self):
        self.env["NVIM_WORKSPACE"] = str(self.root / "missing")
        self.assertNotEqual(self.run_script(interactive=True).returncode, 0)
        self.assertNotEqual(self.run_script("install", "extra").returncode, 0)
        self.assertFalse(self.destination().exists())


if __name__ == "__main__":
    unittest.main()
