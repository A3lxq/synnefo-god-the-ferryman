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
    # Honeypot: a real, responding internal endpoint with nothing useful behind it.
    return "This endpoint was deprecated in 2021. There's nothing here.\n"


@app.route("/run")
def run():
    token = request.args.get("token", "")
    if token != TOKEN:
        return Response("403 -- bad token\n", status=403)
    cmd = request.args.get("cmd", "echo no command")
    try:
        out = subprocess.run(cmd, shell=True, capture_output=True, timeout=5, text=True)
        return Response(out.stdout + out.stderr, mimetype="text/plain")
    except Exception as e:
        return Response(f"error: {e}\n", status=500, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=7000)
