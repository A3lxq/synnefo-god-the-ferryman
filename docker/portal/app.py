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
        # INTENTIONALLY VULNERABLE: raw string-built query, no admin
        # credential disclosed anywhere -- SQL injection is the only
        # way to authenticate as 'admin' (id=1).
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
    # Honeypot: a plausible path, nothing behind it.
    return Response("Not implemented yet.\n", status=501)


@app.route("/admin/preview")
def admin_preview():
    if session.get("db_username") != "admin":
        return Response("403 -- admin only.", status=403)
    # INTENTIONALLY VULNERABLE: SSRF, no allowlist on the target host.
    url = request.args.get("url", "")
    try:
        resp = requests.get(url, timeout=4)
        return Response(resp.text[:4000], mimetype="text/plain")
    except Exception as e:
        return Response(f"Fetch failed: {e}", status=502, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
