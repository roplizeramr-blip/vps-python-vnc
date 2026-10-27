#!/usr/bin/env python3
"""Probe: report the runtime environment the platform gives a non-Docker app.

Serves the report at every path so we can read it with a single HTTP request.
"""

import http.server
import json
import os
import platform
import shutil
import subprocess
import sys


def sh(cmd):
    try:
        p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=20)
        return (p.stdout + p.stderr).strip()[:800]
    except Exception as exc:  # noqa: BLE001
        return f"ERR {exc}"


def report():
    env_keys = sorted(
        k for k in os.environ
        if k in {"PORT", "HOST", "PYTHON_VERSION", "NODE_VERSION", "PATH", "HOME", "USER",
                 "RENDER", "FLY_APP_NAME", "RAILWAY_ENVIRONMENT", "DYNO", "CNG_"}
    )
    data = {
        "python": sys.version.split()[0],
        "platform": platform.platform(),
        "machine": platform.machine(),
        "uid": os.getuid(),
        "euid": os.geteuid(),
        "whoami": sh("id 2>&1"),
        "cwd": os.getcwd(),
        "listen_port": os.environ.get("PORT", "?"),
        "env": {k: os.environ.get(k) for k in env_keys},
        "binaries": {
            b: shutil.which(b)
            for b in ("apt-get", "apt", "dpkg", "node", "npm", "python3", "Xvfb",
                      "Xvnc", "Xtigervnc", "x11vnc", "nginx", "gcc", "make", "curl")
        },
        "os_release": sh("cat /etc/os-release 2>&1"),
        "pid1": sh("cat /proc/1/cmdline 2>&1 | tr '\\0' ' '"),
        "cgroup": sh("cat /proc/1/cgroup 2>&1 | head -3"),
        "apt_list": sh("ls /etc/apt/sources.list.d/ 2>&1; head -3 /etc/apt/sources.list 2>&1"),
        "root_fs": sh("ls / 2>&1 | tr '\\n' ' '"),
        "can_write_usr": sh("touch /usr/local/.probe 2>&1 && echo WRITABLE && rm -f /usr/local/.probe"),
        "systemd_bin": sh("ls -la /usr/lib/systemd/systemd /sbin/init 2>&1"),
        "caps": sh("grep CapEff /proc/self/status 2>&1"),
    }
    return json.dumps(data, indent=2, ensure_ascii=False)


class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, body, ctype="application/json"):
        b = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        self._send(200, report())

    def do_HEAD(self):
        self.do_GET()

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "3000"))
    print(f"[probe] listening on 0.0.0.0:{port}", flush=True)
    http.server.ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()
