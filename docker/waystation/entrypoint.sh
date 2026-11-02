#!/bin/bash
set -euo pipefail
: "${CTF_SECRET:?CTF_SECRET must be set}"
export CTF_SECRET

VAULT_PASSWORD="F3rrym4n-Vault!"   # only ever disclosed via the waystation RCE (flag 6)

mkdir -p /var/log/supervisor /opt/waystation/secret

getflag() { /opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import flag_for; print(flag_for('$CTF_SECRET', $1))"; }
getfrag() { /opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import fragment_for; print(fragment_for('$CTF_SECRET', '$1'))"; }

F6=$(getflag 6)
FRAG_A=$(getfrag A)
cat > /opt/waystation/secret/flag6.txt <<EOF
$F6
vault login: traveler / $VAULT_PASSWORD
fragment: $FRAG_A
EOF
chmod 644 /opt/waystation/secret/flag6.txt

echo "[entrypoint] Waystation ready."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/ctf.conf
