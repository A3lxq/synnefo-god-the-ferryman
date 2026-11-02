# The Halcyon Protocol — a CTF series

A standalone fictional universe, unrelated to The Forgotten Administrator / Synnefo
Academy. Eight independent boxes, each its own folder and its own public repo,
unified only by shared lore. Playing them in order tells one story; playing any
one alone still works as a self-contained box.

## Premise

**Halcyon Dynamics** is a fictional conglomerate that makes everything from
municipal traffic systems to orbital weather sensors. Four years ago its
internal auditor, **Priya Okonkwo-Reyes**, disappeared mid-investigation into a
shell-company network she'd nicknamed **"the Ferryman."** Her notes — case
files, each centred on one compromised system — are the only trace she left.

Players are a contracted investigator reopening her case files one at a time,
weakest system first. Each box is a surviving fragment of Halcyon's
infrastructure, deliberately left reachable, that Priya had flagged before she
vanished. No box requires having played another; each stands alone.

## Case files (tier → box)

1. **Noob — "Orientation Server"**: a brand-new contractor's onboarding VM,
   barely configured, its paper trail still on disk. The gentlest entry point
   into the Ferryman story.
2. **Beginner — "Reading Room"**: Halcyon's public-facing internal library
   portal, quietly used to stage files nobody should've had access to.
3. **Intermediate — "Portside"**: a logistics subsidiary that rerouted a
   shipment nobody can account for.
4. **Master — "Two Offices"**: a pair of linked workstations inside a regional
   branch, reachable only by pivoting from one to the other.
5. **Expert — "The Annex"**: a small departmental network with its own
   lightweight directory service, where Priya's last login was traced.
6. **Legendary — "Ferryman's Relay"**: a custom relay service Halcyon built
   in-house, running inside containers that were never meant to be exposed.
7. **Veteran — "Aftermath"**: not a live system — the forensic remains
   (logs, a disk image, a packet capture) of the night Priya's access was
   revoked, handed over by Halcyon's incident-response team.
8. **God — "The Ferryman"**: Priya's final case file, a capstone system that
   draws on everything the previous seven taught, ending the series.

## Tone and constraints

- Entirely fictional: no real company, person, or product is depicted.
- No box depicts real-world violence; stakes stay corporate/economic
  (fraud, data theft, sabotage of fictional systems).
- Every technical flaw in every box is deliberately placed for teaching and
  documented in that box's own organizer material — nothing is there "for
  realism" alone.
- Honeypots are narrative dead ends (a decoy office, a shredded notebook, a
  locked drawer with nothing behind it) — never a flag-shaped string, so a
  player is never tricked into submitting a wrong answer, only into spending
  time.

## House style carried into every box's README

> "Priya numbered every file she opened. We've kept her numbering. Flags 1–3
> are the ones she found in an afternoon. The rest took her weeks."
