#!/usr/bin/env python3
"""
Organizer-side flag checker. Never commit real CTF_SECRET values.

Usage:
  CTF_SECRET=<deployment secret> python3 organizer/verify.py <flag_number> <submitted_flag>
"""
import hmac
import hashlib
import os
import sys

BOX_ID = "god-the-ferryman"


def flag_for(n: int, secret: str) -> str:
    digest = hmac.new(secret.encode(), f"{BOX_ID}:{n}".encode(), hashlib.sha256).hexdigest()
    return f"HLC{{{digest[:10]}}}"


if __name__ == "__main__":
    secret = os.environ.get("CTF_SECRET")
    if not secret or len(sys.argv) != 3:
        print("usage: CTF_SECRET=... verify.py <n 1-10> <submitted_flag>", file=sys.stderr)
        sys.exit(2)
    n, submitted = int(sys.argv[1]), sys.argv[2].strip()
    expected = flag_for(n, secret)
    print("CORRECT" if submitted == expected else "INCORRECT")
    sys.exit(0 if submitted == expected else 1)
