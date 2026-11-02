# Organizer manifest — The Ferryman (God)

Keep this file (and this whole `organizer/` directory) off any
player-facing host. Flag *values* are never written here — re-derive
them from the deployment's `CTF_SECRET` (HMAC-SHA256("god-the-ferryman:N",
secret), first 10 hex chars, wrapped `HLC{...}`). Fragments A/B/C use
`:fragment:A`/`B`/`C`, first 16 hex chars.

Three hosts: **Portal** (published), **Waystation** (internal-only),
**Vault** (internal-only). This capstone deliberately reuses technique
categories from earlier boxes in the series (JWT, SQLi, SSRF, XOR
crypto puzzle, authenticated RCE, SSH pivot, sudo privesc, multi-
fragment final decrypt) rather than introducing new ones — the point is
synthesizing everything a player has already learned, in one chain.

| # | Host | Difficulty | Concept taught | Primary tool(s) | Where it lives |
|---|---|---|---|---|---|
| 1 | Portal | Easy | Reading page source | curl/browser | HTML comment on `/` |
| 2 | Portal | Easy | JWT payload decode (no cracking) | CyberChef / `jwt.decode(verify_signature=False)` | `/guest-token` |
| 3 | Portal | Medium | SQL injection authentication bypass | `' OR '1'='1' -- ` | `/login` -> `/admin` (no admin credential exists anywhere) |
| 4 | Waystation | Medium | SSRF as a pivot to a never-published internal host | `/admin/preview?url=http://waystation:7000/` | recon banner |
| 5 | Waystation | Medium/Hard | Base64 + single-byte XOR crypto puzzle | CyberChef or a one-line script, key given in-band | `/config` |
| 6 | Waystation | Hard | Authenticated custom-endpoint RCE | the recovered token against `/run` | `/opt/waystation/secret/flag6.txt` -> vault creds + fragment A |
| 7 | Vault | Hard | SSH pivot via credential reuse | `ssh`/`sshpass`, chained through the SSRF+RCE | `traveler`'s home directory |
| 8 | Vault | Hard | sudo NOPASSWD misconfiguration -> root | GTFOBins `find` | `/root/flag8.txt` -> fragment B |
| 9 | Vault | Hard | Root-only forensic log, story payoff | `cat` once root | `/root/ferryman_notes.log` -> fragment C |
| 10 | — | Capstone | Combining three independently-found fragments | `flagcrypto.py` (ships to players) | `/root/dossier.enc`, key = fragment A + B + C concatenated |

## Honeypots (never flag-shaped, cost time only)
- Portal `/backup` — a plausible path, 501, nothing behind it.
- Waystation `/legacy` — a real, responding endpoint with nothing useful
  behind it, reachable via the same SSRF pivot as everything else.

## Fixed design constants (intentional, not secret-derived)
- Portal JWT signing secret: `ferryman-guest` (only ever used for
  guest-role tokens the app itself issues — there's no privilege to
  forge here, unlike earlier boxes' JWT steps; this one is pure decode
  practice).
- Portal admin DB row has a genuinely random, unknown password — SQLi
  is the only way in, by design.
- Waystation: `XOR_KEY = 0x3C` (hinted in its own `/` banner text, not
  hidden), auth token `WAY-7a21-STATION`.
- Vault's `traveler` password == what waystation's RCE discloses
  (`F3rrym4n-Vault!`) — credential reuse, the deliberate pivot lesson.
- Privesc: `traveler ALL=(root) NOPASSWD: /usr/bin/find` (sudoers
  misconfiguration, same GTFOBins technique used in Veteran, different
  box).
- `docker-compose.yml`'s `internal-net` has `internal: true` — neither
  Waystation nor Vault has any route to the internet, not just no
  published ports.

## Build notes (so a rebuild doesn't rediscover these)
- Waystation's image needs `openssh-client` + `sshpass` installed
  explicitly — Debian's base image doesn't ship either, and without
  them the intended SSH pivot from waystation's RCE to vault fails with
  "ssh: not found" / "sshpass: not found".
- When a command run over this chain (`run_on_vault`/`remote_vault` in
  `tests/solve.sh`) mixes real output with SSH's own stderr (e.g. the
  "Warning: Permanently added ... to the list of known hosts" line),
  that warning text lands **concatenated on the same line as the
  command's own output, with no separator** (Python's
  `subprocess.run(capture_output=True)` captures stdout/stderr as
  separate buffers and `waystation/app.py` just appends
  `out.stdout + out.stderr` — there's never a newline between them
  unless the command's own stdout happened to end with one). Strip with
  `sed 's/Warning: Permanently added.*//'` — filtering by line anchor
  (`grep -v '^Warning:'`) does **not** work here and will silently
  corrupt base64 payloads (hit this exact bug building flag 10's
  extraction; fixed in `tests/solve.sh`).
