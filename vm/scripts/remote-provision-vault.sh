#!/usr/bin/env bash
# remote-provision-vault.sh — deploys the Vault host of the God (The
# Ferryman) capstone CTF box onto an already-booted Ubuntu 24.04
# guest (run over SSH as ctfbuilder, with sudo). Native build: real
# openssh-server, a sudo NOPASSWD misconfiguration privesc, final
# dossier decrypt. No Docker anywhere. Public, so never hardcode the
# release secret here -- it must only ever arrive via the SSH
# session's own environment.
set -euo pipefail

: "${RELEASE_SECRET:?RELEASE_SECRET must be passed in (never hardcode it here -- this script is public)}"

VAULT_PASSWORD="F3rrym4n-Vault!"   # matches waystation's disclosed creds

echo "== Vault: packages & venv =="
sudo apt-get install -y -qq python3-venv >/dev/null 2>&1 || true
sudo python3 -m venv /opt/venv
sudo /opt/venv/bin/pip install -q --no-cache-dir cryptography==43.0.3

sudo mkdir -p /opt/shared

echo "== Vault: shared flag/crypto modules =="
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

sudo tee /opt/shared/flagcrypto.py >/dev/null <<'EOF'
#!/usr/bin/env python3
"""
flagcrypto.py -- ships to players unchanged. scrypt for password-based
key derivation, AES-256-GCM for authenticated encryption.

File format (binary): b"HLCX1" + 16-byte salt + 12-byte nonce + ciphertext||tag
"""
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt

MAGIC = b"HLCX1"
SALT_LEN = 16
NONCE_LEN = 12
KEY_LEN = 32


def _derive_key(passphrase: str, salt: bytes) -> bytes:
    kdf = Scrypt(salt=salt, length=KEY_LEN, n=2**14, r=8, p=1)
    return kdf.derive(passphrase.encode("utf-8"))


def encrypt_bytes(passphrase: str, plaintext: bytes) -> bytes:
    import os
    salt = os.urandom(SALT_LEN)
    nonce = os.urandom(NONCE_LEN)
    key = _derive_key(passphrase, salt)
    ct = AESGCM(key).encrypt(nonce, plaintext, None)
    return MAGIC + salt + nonce + ct


def decrypt_bytes(passphrase: str, blob: bytes) -> bytes:
    if not blob.startswith(MAGIC):
        raise ValueError("Not a recognized flagcrypto file (bad magic).")
    rest = blob[len(MAGIC):]
    salt, nonce, ct = rest[:SALT_LEN], rest[SALT_LEN:SALT_LEN + NONCE_LEN], rest[SALT_LEN + NONCE_LEN:]
    key = _derive_key(passphrase, salt)
    return AESGCM(key).decrypt(nonce, ct, None)


if __name__ == "__main__":
    if len(sys.argv) != 5 or sys.argv[1] not in ("encrypt", "decrypt"):
        print(__doc__)
        sys.exit(1)
    mode, passphrase, infile, outfile = sys.argv[1:5]
    with open(infile, "rb") as f:
        data = f.read()
    result = encrypt_bytes(passphrase, data) if mode == "encrypt" else decrypt_bytes(passphrase, data)
    if outfile == "-":
        sys.stdout.buffer.write(result)
    else:
        with open(outfile, "wb") as f:
            f.write(result)
EOF

getflag() { /opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import flag_for; print(flag_for('$RELEASE_SECRET', $1))"; }
getfrag() { /opt/venv/bin/python3 -c "import sys; sys.path.insert(0,'/opt/shared'); from generate_flags import fragment_for; print(fragment_for('$RELEASE_SECRET', '$1'))"; }

echo "== Vault: traveler account + flag7 =="
if ! id traveler >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash traveler
fi
echo "traveler:$VAULT_PASSWORD" | sudo chpasswd
getflag 7 | sudo tee /home/traveler/flag7.txt >/dev/null
sudo chown traveler:traveler /home/traveler/flag7.txt
sudo chmod 600 /home/traveler/flag7.txt

sudo tee /etc/ssh/sshd_config.d/90-traveler-password-auth.conf >/dev/null <<'EOF'
Match User traveler
    PasswordAuthentication yes
EOF

echo "== Vault: INTENTIONALLY VULNERABLE sudo NOPASSWD misconfiguration (Stage 8) =="
echo "traveler ALL=(root) NOPASSWD: /usr/bin/find" | sudo tee /etc/sudoers.d/traveler >/dev/null
sudo chmod 440 /etc/sudoers.d/traveler

echo "== Vault: root's own secrets, reachable only via that privesc =="
FRAG_B=$(getfrag B)
F8=$(getflag 8)
sudo tee /root/flag8.txt >/dev/null <<EOF
$F8
fragment: $FRAG_B
EOF
sudo chmod 600 /root/flag8.txt

FRAG_C=$(getfrag C)
F9=$(getflag 9)
sudo tee /root/ferryman_notes.log >/dev/null <<EOF
2024-03-11 03:02:19 priya.okonkwo-reyes: last known session, this host
2024-03-11 03:04:40 priya.okonkwo-reyes: "if this is the last note I leave,
    the Ferryman's real ledger is in dossier.enc. Three keys open it, each
    one somewhere I've already been. Last fragment: $FRAG_C"
2024-03-11 03:05:02 session closed -- account disabled
$F9
EOF
sudo chmod 600 /root/ferryman_notes.log

echo "== Vault: final dossier (all three fragments derivable from the secret alone) =="
FRAG_A=$(getfrag A)
F10=$(getflag 10)
echo -n "$F10" > /tmp/flag10_plain.txt
/opt/venv/bin/python3 /opt/shared/flagcrypto.py encrypt "${FRAG_A}${FRAG_B}${FRAG_C}" /tmp/flag10_plain.txt /tmp/dossier.enc
rm -f /tmp/flag10_plain.txt
sudo mv /tmp/dossier.enc /root/dossier.enc
sudo chmod 600 /root/dossier.enc

echo "== Vault: restart sshd (clean, no orphaned listeners) =="
sudo pkill -9 -f 'sshd: /usr/sbin/sshd -D \[listener\]' 2>/dev/null || true
sleep 1
sudo systemctl restart ssh

echo "[remote-provision-vault] Vault ready."
