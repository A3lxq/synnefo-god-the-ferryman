#!/bin/bash
set -euo pipefail
: "${CTF_SECRET:?CTF_SECRET must be set}"
export CTF_SECRET

VAULT_PASSWORD="F3rrym4n-Vault!"   # matches waystation's disclosed creds

mkdir -p /var/log/supervisor

VENV=/opt/venv
getflag() { $VENV/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import flag_for; print(flag_for('$CTF_SECRET', $1))"; }
getfrag() { $VENV/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import fragment_for; print(fragment_for('$CTF_SECRET', '$1'))"; }

echo "traveler:$VAULT_PASSWORD" | chpasswd
getflag 7 > /home/traveler/flag7.txt
chown traveler:traveler /home/traveler/flag7.txt
chmod 600 /home/traveler/flag7.txt

# Stage 8: sudo NOPASSWD misconfiguration (GTFOBins `find`).
echo "traveler ALL=(root) NOPASSWD: /usr/bin/find" > /etc/sudoers.d/traveler
chmod 440 /etc/sudoers.d/traveler

FRAG_B=$(getfrag B)
cat > /root/flag8.txt <<EOF
$(getflag 8)
fragment: $FRAG_B
EOF
chmod 600 /root/flag8.txt

# Stage 9: a short forensic log, root-only, the kind of thing an
# incident responder leaves behind on purpose.
FRAG_C=$(getfrag C)
cat > /root/ferryman_notes.log <<EOF
2024-03-11 03:02:19 priya.okonkwo-reyes: last known session, this host
2024-03-11 03:04:40 priya.okonkwo-reyes: "if this is the last note I leave,
    the Ferryman's real ledger is in dossier.enc. Three keys open it, each
    one somewhere I've already been. Last fragment: $FRAG_C"
2024-03-11 03:05:02 session closed -- account disabled
EOF
echo "$(getflag 9)" >> /root/ferryman_notes.log
chmod 600 /root/ferryman_notes.log

# fragment A lives on waystation; needed here only to build dossier.enc.
FRAG_A=$(getfrag A)
F10=$(getflag 10)
echo -n "$F10" > /tmp/flag10_plain.txt
$VENV/bin/python3 /opt/shared/flagcrypto.py encrypt "${FRAG_A}${FRAG_B}${FRAG_C}" /tmp/flag10_plain.txt /root/dossier.enc
rm -f /tmp/flag10_plain.txt
chmod 600 /root/dossier.enc

ssh-keygen -A >/dev/null 2>&1 || true

echo "[entrypoint] Vault ready."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/ctf.conf
