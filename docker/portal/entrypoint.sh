#!/bin/bash
set -euo pipefail
: "${CTF_SECRET:?CTF_SECRET must be set}"
export CTF_SECRET

mkdir -p /var/log/supervisor /var/lib/portal
/opt/venv/bin/python3 /opt/app/seed.py

echo "[entrypoint] Portal ready."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/ctf.conf
