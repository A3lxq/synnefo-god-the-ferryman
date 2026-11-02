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

## Requirements

- Docker + Docker Compose
- A player machine with: `curl`, a browser, CyberChef or a scripting
  language (for the JWT decode and the XOR puzzle), an SSH client

## Starting the box

```
./start.sh
```
Generates a fresh `.env` with a random per-deployment secret and brings
all three containers up.

- Portal: http://localhost:8008
- Waystation and Vault: **not reachable from your host at all** —
  that's intentional, and part of the challenge.

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
