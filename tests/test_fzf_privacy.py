#!/usr/bin/env python3
"""Exercise a real fzf reload against a local server (Linux, fzf >= 0.47)."""
import fcntl
import http.server
import json
import os
import pathlib
import pty
import re
import select
import shutil
import struct
import subprocess
import tempfile
import termios
import threading
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
FZF = os.environ.get("FZF_TEST_BIN") or shutil.which("fzf")


class FzfPrivacyTest(unittest.TestCase):
    def test_query_is_not_in_process_arguments(self):
        if not FZF:
            self.skipTest("fzf is not installed")
        version = subprocess.check_output([FZF, "--version"], text=True)
        match = re.match(r"(\d+)\.(\d+)\.(\d+)", version)
        if not match or tuple(map(int, match.groups())) < (0, 47, 0):
            self.skipTest("fzf 0.47.0 or newer is required")
        if not pathlib.Path("/proc/self/task").exists():
            self.skipTest("Linux procfs is required to inspect process arguments")

        query = "PRIVACY_TEST_MARKER_7139"
        request_received = threading.Event()
        release_response = threading.Event()
        requests = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                requests.append(payload)
                request_received.set()
                release_response.wait(10)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{"message":{"content":"echo safe"}}')

            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.addCleanup(release_response.set)

        with tempfile.TemporaryDirectory() as temp:
            base = pathlib.Path(temp)
            bin_dir = base / "bin"
            bin_dir.mkdir()
            (bin_dir / "fzf").symlink_to(pathlib.Path(FZF).resolve())
            config_dir = base / ".config/zsh-ai-complete"
            config_dir.mkdir(parents=True)
            (config_dir / "selected-provider.txt").write_text("ollama\n")
            config = {"ollama": {"url": f"http://127.0.0.1:{server.server_port}/api/chat",
                "model": "local", "system_message": "test", "token": "",
                "output_path": ".message.content"}}
            (config_dir / "ai-providers.json").write_text(json.dumps(config))
            env = {**os.environ, "HOME": temp, "TERM": "xterm-256color",
                   "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
                   "PLUGIN_TEST_ROOT": str(ROOT)}
            master, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
            script = ('PLUGIN_DIR=$PLUGIN_TEST_ROOT; source "$PLUGIN_DIR/run.sh"; '
                      'LBUFFER="before "; ai_complete_widget; print -r -- "RESULT:$LBUFFER"')
            def attach_terminal():
                fcntl.ioctl(0, termios.TIOCSCTTY, 0)
            proc = subprocess.Popen(["zsh", "-f", "-c", script], stdin=slave,
                                    stdout=slave, stderr=slave, env=env, start_new_session=True,
                                    preexec_fn=attach_terminal)
            os.close(slave)
            try:
                time.sleep(0.5)
                os.write(master, query.encode())
                output = b""
                deadline = time.monotonic() + 10
                while not request_received.is_set() and time.monotonic() < deadline:
                    if select.select([master], [], [], 0.1)[0]:
                        output += os.read(master, 65536)
                self.assertTrue(request_received.is_set(), "No request received from fzf")
                self.assertEqual(requests[-1]["messages"][1]["content"], query)

                # Walk only this test's process tree; do not inspect unrelated processes.
                pending, seen = [proc.pid], set()
                while pending:
                    pid = pending.pop()
                    if pid in seen:
                        continue
                    seen.add(pid)
                    try:
                        cmdline = pathlib.Path(f"/proc/{pid}/cmdline").read_bytes()
                        child_files = list(pathlib.Path(f"/proc/{pid}/task").glob("*/children"))
                    except (FileNotFoundError, ProcessLookupError):
                        continue
                    self.assertNotIn(query.encode(), cmdline)
                    for child_file in child_files:
                        try:
                            pending.extend(map(int, child_file.read_text().split()))
                        except FileNotFoundError:
                            pass
                self.assertGreaterEqual(len(seen), 3)

                release_response.set()
                deadline = time.monotonic() + 10
                while b"echo safe" not in output and time.monotonic() < deadline:
                    if select.select([master], [], [], 0.1)[0]:
                        output += os.read(master, 65536)
                self.assertIn(b"echo safe", output)
                os.write(master, b"\r")
                self.assertEqual(proc.wait(timeout=5), 0)
                while select.select([master], [], [], 0)[0]:
                    try:
                        output += os.read(master, 65536)
                    except OSError:
                        break
                self.assertIn(b"RESULT:before echo safe", output)
            finally:
                release_response.set()
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
                os.close(master)


if __name__ == "__main__":
    unittest.main()
