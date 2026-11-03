# VM / OVA — The Ferryman (capstone)

**Three separate VM appliances**, not one: `portal-the-ferryman-ctf.ova`
(published to your host), `waystation-the-ferryman-ctf.ova`, and
`vault-the-ferryman-ctf.ova` (both never published). They form a
**chain**, not a star: Portal only ever talks to Waystation directly
(its SSRF never targets Vault); it's Waystation's own authenticated
RCE that pivots on to Vault over SSH. Portal and Vault never talk to
each other. All three are Ubuntu Server 24.04 LTS via QEMU/KVM +
cloud-init (NoCloud). Native build — real Flask/SQLite/openssh-server
managed by systemd. No Docker anywhere.

- **Portal** has two network adapters: NAT (its published web app,
  port 5000) and a private link to Waystation.
- **Waystation** (the middle host) has three: NAT (build-only), a
  link back to Portal, and a second private link on to Vault.
- **Vault** has two: NAT (build-only) and its one private link back
  to Waystation.

Flags are **static**, baked in once at provisioning time from a fixed
release secret — every copy of the exported OVAs has the same flags.
The release secret is never committed; `organizer/release-secret.txt`
(gitignored) holds it.

## Using the pre-built OVAs

Download **all three** `.ova` files from this repo's Releases page,
then in VirtualBox (File > Import Appliance), import all three:

1. Import `portal-the-ferryman-ctf.ova`. Leave adapter 1 as **NAT**.
   After import, open Settings > Network > Adapter 2 -> **Internal
   Network**, name `halcyon-ferryman-portal-waystation-link`.
2. Import `waystation-the-ferryman-ctf.ova`.
   - Adapter 2 -> **Internal Network**, name
     `halcyon-ferryman-portal-waystation-link` (must match Portal's
     adapter 2 exactly).
   - Adapter 3 -> **Internal Network**, name
     `halcyon-ferryman-waystation-vault-link`.
3. Import `vault-the-ferryman-ctf.ova`. Adapter 2 -> **Internal
   Network**, name `halcyon-ferryman-waystation-vault-link` (must
   match Waystation's adapter 3 exactly).
4. Power on all three (order doesn't matter) and wait about a minute
   for boot. Browse to Portal's forwarded web port — check
   VirtualBox's Adapter 1 port-forwarding rules (or open the VM's
   console and `curl localhost:5000`) to confirm the NAT-forwarded
   port.
5. Everything else happens inside the challenge — see `STORY.md` and
   `docs/hints.md` in the repo root. This box deliberately synthesizes
   techniques from earlier boxes in the series rather than
   introducing new ones.

VMware Workstation/Fusion: File > Open each `.ova`, then set the
matching adapters to "LAN segment" (VMware's equivalent of
VirtualBox's Internal Network) with the same segment name across the
VMs that share a link.

**This is an intentionally vulnerable trio of machines. Import them
only on an isolated network/host.**

## Build from source

```
cd vm
# put ubuntu-24.04-server-cloudimg-amd64.img in images/ first
# put your own ed25519 keypair in keys/ctfbuilder_ed25519[.pub],
# and reference the .pub in all three hosts' cloud-init/user-data.yaml
# generate a release secret: openssl rand -hex 32 > ../organizer/release-secret.txt
./scripts/create-disks.sh
./scripts/boot-vms.sh        # wait a few minutes for first boot + cloud-init on all three
RELEASE_SECRET=$(cat ../organizer/release-secret.txt)
scp -i keys/ctfbuilder_ed25519 -P 2228 scripts/remote-provision-vault.sh ctfbuilder@127.0.0.1:/tmp/
scp -i keys/ctfbuilder_ed25519 -P 2218 scripts/remote-provision-waystation.sh ctfbuilder@127.0.0.1:/tmp/
scp -i keys/ctfbuilder_ed25519 -P 2208 scripts/remote-provision-portal.sh ctfbuilder@127.0.0.1:/tmp/
ssh -i keys/ctfbuilder_ed25519 -p 2228 ctfbuilder@127.0.0.1 "RELEASE_SECRET='$RELEASE_SECRET' bash /tmp/remote-provision-vault.sh"
ssh -i keys/ctfbuilder_ed25519 -p 2218 ctfbuilder@127.0.0.1 "RELEASE_SECRET='$RELEASE_SECRET' bash /tmp/remote-provision-waystation.sh"
ssh -i keys/ctfbuilder_ed25519 -p 2208 ctfbuilder@127.0.0.1 "RELEASE_SECRET='$RELEASE_SECRET' bash /tmp/remote-provision-portal.sh"
./scripts/verify.sh           # proves all 10 flags before you export anything
./scripts/export-vms.sh
./scripts/export-ovas.sh
```

## Build note: chain topology, not a star

Unlike this series' other multi-VM boxes, this one is a genuine
**chain** (Portal <-> Waystation <-> Vault), not a star through the
published host. Portal's code only ever contacts Waystation; it's
Waystation's own `/run` RCE that pivots further to Vault over SSH.
Wiring Portal directly to Vault (as a star topology would) leaves
Waystation unable to resolve or reach `vault` at all, breaking flag 7
with "Could not resolve hostname vault" -- caught by `verify.sh`
during this box's own build, fixed by giving Waystation the second
internal link instead of Portal. If you ever see that exact error
while rebuilding, this is almost certainly the cause.

## Build note: generous timeouts

Both `/admin/preview` (Portal's SSRF) and `/run` (Waystation's RCE)
use generous timeouts (25s / 20s) -- the nested SSRF -> RCE -> SSH
pivot to Vault carries real handshake overhead on slow or heavily-
virtualized hardware. If you rebuild this and see flag 7 or later time
out, that's the symptom; don't shrink these back down.
