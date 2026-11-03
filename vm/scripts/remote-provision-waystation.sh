#!/usr/bin/env bash
# remote-provision-waystation.sh — deploys the Waystation host of the
# God (The Ferryman) capstone CTF box onto an already-booted Ubuntu
# 24.04 guest (run over SSH as ctfbuilder, with sudo). Native build:
# real Flask app via systemd, running as an unprivileged account. No
# Docker anywhere. Public, so never hardcode the release secret here
# -- it must only ever arrive via the SSH session's own environment.
set -euo pipefail

: "${RELEASE_SECRET:?RELEASE_SECRET must be passed in (never hardcode it here -- this script is public)}"

VAULT_PASSWORD="F3rrym4n-Vault!"   # only ever disclosed via the waystation RCE (flag 6)

echo "== Waystation: packages & venv =="
sudo apt-get install -y -qq python3-venv >/dev/null 2>&1 || true
sudo python3 -m venv /opt/venv
sudo /opt/venv/bin/pip install -q --no-cache-dir flask==3.1.0

sudo mkdir -p /opt/shared /opt/app /opt/waystation/secret

echo "== Waystation: shared flag module =="
sudo tee /opt/shared/generate_flags.py >/dev/null <<'EOF'
import hmac
import hashlib

BOX_ID = "god-the-ferryman"


def flag_for(secret: str, n: int) -> str:
    digest = hmac.new(secret.encode(), f"{BOX_ID}:{n}".encode(), hashlib.sha256).hexdigest()
    return f"HLC{{{digest[:10]}}}"


def fragment_for(secret: str, which: str) -> str:
    digest = hmac.new(secret.encode(), f"{BOX_ID}:fragment:{which}".encode(), hashlib.sha256).hexdigest()
    return digest[:16]
EOF

getflag() { /opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import flag_for; print(flag_for('$RELEASE_SECRET', $1))"; }
getfrag() { /opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import fragment_for; print(fragment_for('$RELEASE_SECRET', '$1'))"; }

echo "== Waystation: app.py =="
sudo tee /opt/app/app.py >/dev/null <<'PYEOF'
"""
The Ferryman -- waystation. Flask, port 7000. Never published --
reachable only via the portal's SSRF-vulnerable /admin/preview.
"""
import base64
import os
import subprocess
import sys

from flask import Flask, request, Response

sys.path.insert(0, "/opt/shared")
from generate_flags import flag_for  # noqa: E402

SECRET = os.environ["CTF_SECRET"]
XOR_KEY = 0x3C
TOKEN = "WAY-7a21-STATION"

app = Flask(__name__)


def flag(n):
    return flag_for(SECRET, n)


@app.route("/")
def index():
    return f"waystation internal relay\nnote: {flag(4)}\nconfig: /config (legacy single-byte XOR + base64, key noted in our old wiki as 0x3C)\n"


@app.route("/config")
def config():
    plaintext = f"token={TOKEN}\nnote={flag(5)}\n".encode()
    xored = bytes(b ^ XOR_KEY for b in plaintext)
    return Response(base64.b64encode(xored), mimetype="text/plain")


@app.route("/legacy")
def legacy_decoy():
    return "This endpoint was deprecated in 2021. There's nothing here.\n"


@app.route("/run")
def run():
    token = request.args.get("token", "")
    if token != TOKEN:
        return Response("403 -- bad token\n", status=403)
    cmd = request.args.get("cmd", "echo no command")
    try:
        # Generous timeout: this often runs an SSH pivot to vault, which
        # carries real handshake overhead on slow/heavily-virtualized
        # hardware -- don't shrink this back down (see vm/README.md).
        out = subprocess.run(cmd, shell=True, capture_output=True, timeout=20, text=True)
        return Response(out.stdout + out.stderr, mimetype="text/plain")
    except Exception as e:
        return Response(f"error: {e}\n", status=500, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=7000)
PYEOF

echo "== Waystation: systemd service =="
sudo tee /etc/systemd/system/waystation-app.service >/dev/null <<EOF
[Unit]
Description=Waystation Flask app
After=network.target

[Service]
Environment=CTF_SECRET=$RELEASE_SECRET
ExecStart=/opt/venv/bin/python3 /opt/app/app.py
WorkingDirectory=/opt/app
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now waystation-app.service

echo "== Waystation: secret reachable only via the authenticated /run RCE =="
F6=$(getflag 6)
FRAG_A=$(getfrag A)
sudo tee /opt/waystation/secret/flag6.txt >/dev/null <<EOF
$F6
vault login: traveler / $VAULT_PASSWORD
fragment: $FRAG_A
EOF
sudo chmod 644 /opt/waystation/secret/flag6.txt

echo "== Waystation: /etc/hosts entry for the internal link to vault =="
# Waystation's own RCE is what pivots on to vault via SSH (portal
# never contacts vault directly) -- so waystation is the host that
# needs the route and hosts entry for it.
if ! grep -q '^10\.10\.60\.2 vault' /etc/hosts; then
  echo "10.10.60.2 vault" | sudo tee -a /etc/hosts >/dev/null
fi

echo "[remote-provision-waystation] Waystation ready."
