#!/usr/bin/env python3
"""Run with python3 tests/test_shortcut.py (requires zsh and jq)."""
import json
import os
import pathlib
import pty
import select
import subprocess
import tempfile
import time
import unittest

PLUGIN = pathlib.Path(__file__).resolve().parents[1] / "zsh-ai-complete.plugin.zsh"


class ShortcutTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.env = {**os.environ, "HOME": self.tmp.name, "TEST_PLUGIN": str(PLUGIN)}
        self.settings = pathlib.Path(self.tmp.name) / ".config/zsh-ai-complete/settings.json"

    def binding(self, key):
        script = 'source "$TEST_PLUGIN"; bindkey "$1"'
        return subprocess.run(["zsh", "-f", "-c", script, "zsh", key],
                              env=self.env, text=True, capture_output=True, check=True)

    def capture(self, key, confirmation=b"y\n", setup=""):
        master, slave = pty.openpty()
        script = 'source "$TEST_PLUGIN"; ' + (setup + '; ' if setup else '')
        proc = subprocess.Popen(["zsh", "-f", "-c",
                                 script + 'zsh-ai-complete config shortcut'],
                                stdin=slave, stdout=slave, stderr=slave, env=self.env,
                                start_new_session=True)
        os.close(slave)
        self.addCleanup(os.close, master)
        output = b""
        deadline = time.monotonic() + 5
        while b"Press the shortcut" not in output and time.monotonic() < deadline:
            ready, _, _ = select.select([master], [], [], 0.1)
            if ready:
                output += os.read(master, 4096)
        self.assertIn(b"Press the shortcut", output)
        os.write(master, key)
        deadline = time.monotonic() + 5
        answered = False
        while proc.poll() is None and time.monotonic() < deadline:
            ready, _, _ = select.select([master], [], [], 0.1)
            if ready:
                try:
                    output += os.read(master, 4096)
                except OSError:
                    break
            if not answered and b"Save this shortcut anyway?" in output:
                os.write(master, confirmation)
                answered = True
        try:
            status = proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            self.fail("Shortcut picker did not exit")
        try:
            while select.select([master], [], [], 0)[0]:
                output += os.read(master, 4096)
        except OSError:
            pass
        self.last_output = output.decode(errors="replace")
        return status

    def test_default_binding(self):
        self.assertIn("ai_complete_widget", self.binding("\x15").stdout)

    def test_capture_and_reload_control_key(self):
        self.assertEqual(self.capture(b"\x18"), 0)
        self.assertNotIn("Warning:", self.last_output)
        self.assertEqual(json.loads(self.settings.read_text())["shortcut"], "\x18")
        self.assertIn("ai_complete_widget", self.binding("\x18").stdout)

    def test_capture_escape_sequence(self):
        self.assertEqual(self.capture(b"\x1bx"), 0)
        self.assertEqual(json.loads(self.settings.read_text())["shortcut"], "\x1bx")
        self.assertIn("ai_complete_widget", self.binding("\x1bx").stdout)

    def test_cancel_and_printable_do_not_write(self):
        self.assertNotEqual(self.capture(b"\x07"), 0)
        self.assertNotEqual(self.capture(b"x"), 0)
        self.assertFalse(self.settings.exists())

    def test_warns_for_common_and_existing_binding_and_requires_confirmation(self):
        self.assertNotEqual(self.capture(b"\x12", b"n\n"), 0)
        self.assertIn("commonly searches command history", self.last_output)
        self.assertIn("history-incremental-search-backward", self.last_output)
        self.assertFalse(self.settings.exists())
        self.assertEqual(self.capture(b"\x12", b"y\n"), 0)
        self.assertEqual(json.loads(self.settings.read_text())["shortcut"], "\x12")
        self.assertNotEqual(self.capture(b"\x01", b"n\n"), 0)
        self.assertIn("GNU Screen", self.last_output)
        self.assertEqual(json.loads(self.settings.read_text())["shortcut"], "\x12")

    def test_warns_for_custom_binding(self):
        self.assertEqual(self.capture(b"\x18", b"y\n", "bindkey '^X' backward-char"), 0)
        self.assertIn("current Zsh main keymap binding", self.last_output)
        self.assertIn("backward-char", self.last_output)

    def test_wsl_guidance_and_possible_terminal_shortcut(self):
        self.assertNotEqual(self.capture(b"\x14", b"n\n", "_zsh_ai_is_wsl() { return 0; }"), 0)
        self.assertIn("WSL: Windows Terminal may intercept", self.last_output)
        self.assertIn("Win+L, Win+D, and Alt+Tab", self.last_output)
        self.assertIn("Ctrl+Shift+W can close", self.last_output)
        self.assertIn("may also represent Ctrl+Shift+T", self.last_output)
        self.assertFalse(self.settings.exists())
        self.assertNotEqual(self.capture(b"\x17", b"n\n", "_zsh_ai_is_wsl() { return 0; }"), 0)
        self.assertIn("may also represent Ctrl+Shift+W", self.last_output)

    def test_wsl_guidance_is_not_shown_on_other_systems(self):
        self.assertEqual(self.capture(b"\x18", setup="_zsh_ai_is_wsl() { return 1; }"), 0)
        self.assertNotIn("WSL: Windows Terminal", self.last_output)

    def test_preserves_existing_settings_and_rejects_invalid_json(self):
        self.settings.parent.mkdir(parents=True)
        self.settings.write_text('{"other": 12}')
        self.assertEqual(self.capture(b"\x18"), 0)
        self.assertEqual(json.loads(self.settings.read_text())["other"], 12)
        self.settings.write_text("not JSON")
        self.assertNotEqual(self.capture(b"\x18"), 0)
        self.assertEqual(self.settings.read_text(), "not JSON")
        result = self.binding("\x15")
        self.assertIn("ai_complete_widget", result.stdout)
        self.assertIn("Invalid shortcut settings", result.stderr)

    def test_noninteractive_rejected(self):
        result = subprocess.run(["zsh", "-f", "-c",
                                 'source "$TEST_PLUGIN"; zsh-ai-complete config shortcut'],
                                env=self.env, stdin=subprocess.DEVNULL, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.settings.exists())


if __name__ == "__main__":
    unittest.main()
