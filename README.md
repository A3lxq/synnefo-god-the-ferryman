# Case File 8 (God) — The Ferryman

Part of **The Halcyon Protocol** CTF series. This is the **capstone** —
the final case file in the arc that began with Case File 1. It stands
alone (you don't strictly need any other box in the series to play it),
but it's built to feel like the payoff for everything the series taught
along the way: JWT handling, SQL injection, SSRF pivoting, a small
crypto puzzle, authenticated RCE, credential-reuse pivoting, privilege
escalation, and a final step that only comes together if you kept
everything you found earlier.

> See [`STORY.md`](STORY.md) for the full case file.

## What this is

**Three hosts**: a public Portal, a Waystation reachable only by
pivoting through it, and a Vault reachable only by pivoting again from
there. 10 flags, no decoys. The first few are approachable on their
own; the back half only works if you carry credentials and fragments
forward from earlier steps — this box doesn't give you anything a
second time.

**This machine is intentionally vulnerable. Run it only on an isolated
network.**

## Running it

This box ships as **three** VM appliances — download all three `.ova`
files from this repo's [Releases](../../releases) page and import all
of them into VirtualBox (File > Import Appliance) or VMware
Workstation/Fusion (File > Open). The three form a chain (Portal <->
Waystation <-> Vault); each VM's internal-link adapter(s) need to be
set to the matching Internal Network / LAN segment name — see
[`vm/README.md`](vm/README.md) for exact steps and for rebuilding
from source.

There is no Docker build in this repo (an earlier one was removed; a
Docker version may be added back separately).

## Flag format

`HLC{xxxxxxxxxx}` — submit exactly as found.

## Rules

- No decoy flags: everything matching the flag format is real and counts.
- Some things in this box are honeypots — red herrings that cost you time,
  not flags.
- Don't attack this box over a shared or public network.

## More

- [`STORY.md`](STORY.md) — the in-universe case file, and the end of the arc
- [`docs/hints.md`](docs/hints.md) — progressive hints
- [`docs/tools.md`](docs/tools.md) — what each tool is for
- [`docs/writeup/WRITEUP.md`](docs/writeup/WRITEUP.md) — full spoiler walkthrough
- [`flags/generate_flags.py`](flags/generate_flags.py) — the per-deployment flag derivation scheme, used by `organizer/verify.py`
