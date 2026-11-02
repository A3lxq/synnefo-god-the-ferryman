import hmac
import hashlib

BOX_ID = "god-the-ferryman"


def flag_for(secret: str, n: int) -> str:
    digest = hmac.new(secret.encode(), f"{BOX_ID}:{n}".encode(), hashlib.sha256).hexdigest()
    return f"HLC{{{digest[:10]}}}"


def fragment_for(secret: str, which: str) -> str:
    """which: 'A', 'B', or 'C' -- three independent thirds of the final passphrase."""
    digest = hmac.new(secret.encode(), f"{BOX_ID}:fragment:{which}".encode(), hashlib.sha256).hexdigest()
    return digest[:16]
