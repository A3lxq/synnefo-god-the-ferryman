#!/usr/bin/env python3
"""
flagcrypto.py — ships to players unchanged. Same scheme used elsewhere in
this series for "combine two pieces of evidence to decrypt the last
flag": scrypt for password-based key derivation, AES-256-GCM for
authenticated encryption. Standard, documented primitives only.

File format (binary): b"HLCX1" + 16-byte salt + 12-byte nonce + ciphertext||tag

Usage:
    python3 flagcrypto.py encrypt <passphrase> <in-file> <out-file.enc>
    python3 flagcrypto.py decrypt <passphrase> <in-file.enc> <out-file|->
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
