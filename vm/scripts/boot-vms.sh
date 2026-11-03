#!/usr/bin/env bash
# boot-vms.sh — boots all three VMs in a CHAIN topology: portal <->
# waystation <-> vault. This matches the original docker-compose
# design exactly: portal's code only ever contacts waystation
# directly (its SSRF never targets vault), and it's waystation's own
# RCE that SSHes on to vault -- so waystation is the one host that
# needs two internal links, not portal. portal and vault never talk
# to each other directly.
set -euo pipefail
cd "$(dirname "$0")/.."

ACCEL="tcg"
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  ACCEL="kvm"
fi
echo "Using acceleration: $ACCEL"

LINK_A_PORT=20081   # portal <-> waystation
LINK_B_PORT=20082   # waystation <-> vault

boot() {
  local NAME="$1"; shift
  local DISK="$NAME/disks/$NAME.qcow2" SEED="$NAME/seed/seed.img"
  mkdir -p "$NAME/logs"
  qemu-system-x86_64 \
    -name "$NAME" \
    -machine type=q35,accel=$ACCEL \
    -cpu max -m 1536 -smp 2 \
    -drive file="$DISK",if=virtio,format=qcow2 \
    -drive file="$SEED",if=virtio,format=raw \
    "$@" \
    -display none \
    -serial file:"$NAME/logs/vm-console.log" \
    -monitor unix:"$NAME/disks/monitor.sock",server,nowait \
    -pidfile "$NAME/disks/vm.pid" \
    -daemonize
}

echo "== Starting portal (NAT + link-to-waystation listener) =="
boot portal \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2208-:22,hostfwd=tcp:127.0.0.1:8008-:5000 \
  -device virtio-net-pci,netdev=net0,mac=52:54:00:aa:00:01 \
  -netdev socket,id=net1,listen=127.0.0.1:${LINK_A_PORT} \
  -device virtio-net-pci,netdev=net1,mac=52:54:00:aa:01:01

sleep 1

echo "== Starting waystation (NAT + link-to-portal connector + link-to-vault listener) =="
boot waystation \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2218-:22 \
  -device virtio-net-pci,netdev=net0,mac=52:54:00:aa:00:02 \
  -netdev socket,id=net1,connect=127.0.0.1:${LINK_A_PORT} \
  -device virtio-net-pci,netdev=net1,mac=52:54:00:aa:01:02 \
  -netdev socket,id=net2,listen=127.0.0.1:${LINK_B_PORT} \
  -device virtio-net-pci,netdev=net2,mac=52:54:00:aa:02:01

echo "== Starting vault (NAT + link-to-waystation connector) =="
boot vault \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2228-:22 \
  -device virtio-net-pci,netdev=net0,mac=52:54:00:aa:00:03 \
  -netdev socket,id=net1,connect=127.0.0.1:${LINK_B_PORT} \
  -device virtio-net-pci,netdev=net1,mac=52:54:00:aa:02:02

echo "All three VMs starting."
echo "portal:     ssh -i keys/ctfbuilder_ed25519 -p 2208 ctfbuilder@127.0.0.1   (web: http://127.0.0.1:8008)"
echo "waystation: ssh -i keys/ctfbuilder_ed25519 -p 2218 ctfbuilder@127.0.0.1   (build-only)"
echo "vault:      ssh -i keys/ctfbuilder_ed25519 -p 2228 ctfbuilder@127.0.0.1   (build-only)"
echo "Stop with: ./scripts/stop-vms.sh"
