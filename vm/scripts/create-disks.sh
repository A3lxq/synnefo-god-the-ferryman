#!/usr/bin/env bash
# create-disks.sh — builds all three VMs' writable disks + cloud-init
# seeds from the shared base Ubuntu cloud image. Safe to re-run:
# refuses to overwrite an existing disk unless you pass --force.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_IMAGE="images/ubuntu-24.04-server-cloudimg-amd64.img"
DISK_SIZE="4G"
FORCE=0

for arg in "$@"; do
  [ "$arg" = "--force" ] && FORCE=1
done

if [ ! -f "$BASE_IMAGE" ]; then
  echo "Missing $BASE_IMAGE. See README.md for where to get the base cloud image." >&2
  exit 1
fi

for HOST in portal waystation vault; do
  DISK="$HOST/disks/$HOST.qcow2"
  SEED="$HOST/seed/seed.img"
  mkdir -p "$HOST/disks" "$HOST/seed"

  if [ -f "$DISK" ] && [ "$FORCE" -ne 1 ]; then
    echo "Refusing to overwrite existing $DISK (pass --force to rebuild from scratch)." >&2
    exit 1
  fi

  echo "== [$HOST] Creating writable overlay disk ($DISK_SIZE) from base image =="
  qemu-img create -f qcow2 -F qcow2 -b "$(pwd)/$BASE_IMAGE" "$DISK" "$DISK_SIZE"

  echo "== [$HOST] Building cloud-init seed image =="
  cloud-localds -N "$HOST/cloud-init/network-config.yaml" "$SEED" \
    "$HOST/cloud-init/user-data.yaml" "$HOST/cloud-init/meta-data.yaml"
done

echo "Done. Next: ./scripts/boot-vms.sh"
