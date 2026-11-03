#!/usr/bin/env bash
# remote-provision-portal.sh — deploys the Portal host of the God
# (The Ferryman) capstone CTF box onto an already-booted Ubuntu 24.04
# guest (run over SSH as ctfbuilder, with sudo). Native build: real
# Flask + SQLite app via systemd. No Docker anywhere. Public, so
# never hardcode the release secret here -- it must only ever arrive
# via the SSH session's own environment.
set -euo pipefail

: "${RELEASE_SECRET:?RELEASE_SECRET must be passed in (never hardcode it here -- this script is public)}"

echo "== Portal: packages & venv =="
sudo apt-get install -y -qq python3-venv >/dev/null 2>&1 || true
sudo python3 -m venv /opt/venv
sudo /opt/venv/bin/pip install -q --no-cache-dir flask==3.1.0 pyjwt==2.9.0 requests==2.32.3

sudo mkdir -p /opt/shared /opt/app /var/lib/portal

echo "== Portal: shared flag module =="
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

echo "== Portal: seed.py (randomized, genuinely-unknown admin password) =="
sudo tee /opt/app/seed.py >/dev/null <<'PYEOF'
import os
import sqlite3

DB_PATH = "/var/lib/portal/portal.db"

if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

conn = sqlite3.connect(DB_PATH)
conn.execute("CREATE TABLE staff (id INTEGER PRIMARY KEY, username TEXT, password TEXT)")
admin_pw = os.urandom(16).hex()  # genuinely unknown to anyone -- SQLi is the only way in
conn.execute("INSERT INTO staff (id, username, password) VALUES (1, 'admin', ?)", (admin_pw,))
conn.commit()
conn.close()
print("Portal DB seeded.")
PYEOF

echo "== Portal: app.py =="
sudo tee /opt/app/app.py >/dev/null <<'PYEOF'
"""
The Ferryman -- portal. Flask + SQLite, port 5000 (published).
Combines techniques from earlier in this series (JWT, SQLi, SSRF) as
the entry point for this capstone box.
"""
import os
import sqlite3
import sys

import jwt
import requests
from flask import Flask, request, Response, jsonify, session

sys.path.insert(0, "/opt/shared")
from generate_flags import flag_for  # noqa: E402

SECRET = os.environ["CTF_SECRET"]
JWT_SECRET = "ferryman-guest"  # weak on purpose, but only guest-role tokens are ever issued by this app
DB_PATH = "/var/lib/portal/portal.db"

app = Flask(__name__)
app.secret_key = os.urandom(32).hex()


def flag(n):
    return flag_for(SECRET, n)


def db():
    return sqlite3.connect(DB_PATH)


@app.route("/")
def index():
    return f"""<!DOCTYPE html><html><head><title>The Ferryman</title></head><body>
    <!-- {flag(1)} -->
    <h1>Halcyon Dynamics -- Case Tracking Portal</h1>
    <p><a href="/guest-token">Get a guest token</a> or
    <a href="/login">staff login</a>.</p>
    </body></html>"""


@app.route("/guest-token")
def guest_token():
    token = jwt.encode({"role": "guest", "note": flag(2)}, JWT_SECRET, algorithm="HS256")
    return jsonify({"token": token})


@app.route("/login", methods=["GET", "POST"])
def login():
    error = ""
    if request.method == "POST":
        u = request.form.get("username", "")
        p = request.form.get("password", "")
        query = f"SELECT * FROM staff WHERE username = '{u}' AND password = '{p}' LIMIT 1"
        row = None
        try:
            cur = db().execute(query)
            row = cur.fetchone()
        except Exception:
            error = "Database error."
        if row:
            session["db_username"] = row[1]
            return Response(status=302, headers={"Location": "/admin"})
        error = error or "Invalid credentials."
    return f"""<!DOCTYPE html><html><body><h2>Staff Login</h2>
    <p style="color:red">{error}</p>
    <form method="post">
      Username: <input name="username"><br>
      Password: <input name="password" type="password"><br>
      <button type="submit">Log in</button>
    </form></body></html>"""


@app.route("/admin")
def admin():
    if session.get("db_username") != "admin":
        return Response("403 -- admin only.", status=403)
    return f"""<!DOCTYPE html><html><body><h1>Admin</h1><p>{flag(3)}</p>
    <p>Use <a href="/admin/preview?url=http://waystation:7000/">/admin/preview?url=...</a>
    to check an internal link before publishing it.</p>
    </body></html>"""


@app.route("/backup")
def backup_decoy():
    return Response("Not implemented yet.\n", status=501)


@app.route("/admin/preview")
def admin_preview():
    if session.get("db_username") != "admin":
        return Response("403 -- admin only.", status=403)
    url = request.args.get("url", "")
    try:
        # Generous timeout: this often proxies a nested RCE+SSH pivot to
        # vault, which carries real handshake overhead on slow/heavily-
        # virtualized hardware -- don't shrink this back down (see
        # vm/README.md).
        resp = requests.get(url, timeout=25)
        return Response(resp.text[:4000], mimetype="text/plain")
    except Exception as e:
        return Response(f"Fetch failed: {e}", status=502, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
PYEOF

echo "== Portal: systemd service =="
sudo tee /etc/systemd/system/portal-app.service >/dev/null <<EOF
[Unit]
Description=Portal Flask app
After=network.target

[Service]
Environment=CTF_SECRET=$RELEASE_SECRET
ExecStartPre=/opt/venv/bin/python3 /opt/app/seed.py
ExecStart=/opt/venv/bin/python3 /opt/app/app.py
WorkingDirectory=/opt/app
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now portal-app.service

echo "== Portal: /etc/hosts entry for the internal link to waystation =="
# Portal's SSRF only ever targets waystation directly -- the pivot to
# vault happens from waystation's own RCE, not from here -- so portal
# needs no route or hosts entry for vault at all.
if ! grep -q '^10\.10\.40\.2 waystation' /etc/hosts; then
  echo "10.10.40.2 waystation" | sudo tee -a /etc/hosts >/dev/null
fi

echo "== Portal: restart sshd (clean, no orphaned listeners) =="
sudo pkill -9 -f 'sshd: /usr/sbin/sshd -D \[listener\]' 2>/dev/null || true
sleep 1
sudo systemctl restart ssh

echo "[remote-provision-portal] Portal ready."
