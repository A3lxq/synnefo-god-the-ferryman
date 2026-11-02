# Tools you'll use in this box

| Tool | What it's for here |
|---|---|
| curl / browser | Recon, login, triggering requests. |
| CyberChef "JWT Decode" or `jwt.decode(verify_signature=False)` | Read the guest token's payload (flag 2) — no cracking needed. |
| Manual SQL injection | `' OR '1'='1' -- ` as the username (flag 3). |
| Burp Repeater / curl | Craft the SSRF requests against `/admin/preview?url=...` (flags 4–6). |
| CyberChef "XOR" + "From Base64" (or a one-line script) | Recover the waystation auth token from `/config` (flag 5) — the XOR key is given in-band. |
| `ssh` / `sshpass` | The pivot from waystation's RCE to vault (flag 7), using a credential the chain itself discloses. |
| `sudo -l` + GTFOBins (gtfobins.github.io) | Find and use a sudo misconfiguration once you're on vault (flag 8). |
| `docker/flagcrypto.py` (ships with this repo) | Decrypt the final dossier once you have all three fragments (flag 10). |
