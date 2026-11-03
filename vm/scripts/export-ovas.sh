#!/usr/bin/env bash
# export-ovas.sh — builds the three OVF/OVA appliances (run
# export-vms.sh first). gateway gets THREE network adapters in its
# OVF ("NAT", "halcyon-annex-directory-link", "halcyon-annex-
# fileserver-link"); directory and fileserver each get two ("NAT" +
# their one matching internal-link name). VirtualBox's own Import
# Appliance wizard lets you map each adapter to a real attachment
# type on import -- see vm/README.md for the exact steps (Internal
# Network, matching names across the VMs that share a link).
set -euo pipefail
cd "$(dirname "$0")/.."

MEM_MB=1024
CPUS=2

# build_one HOST VM_NAME TITLE ANNOTATION LINK1_NAME [LINK2_NAME]
build_one() {
  local HOST="$1" VM_NAME="$2" TITLE="$3" ANNOTATION="$4" LINK1="$5" LINK2="${6:-}"
  local SRC_QCOW2="$HOST/dist/$HOST-the-ferryman-ctf.qcow2"
  local OUT_DIR="$HOST/dist"
  local VMDK="$OUT_DIR/$VM_NAME-disk001.vmdk"
  local OVF="$OUT_DIR/$VM_NAME.ovf"
  local MF="$OUT_DIR/$VM_NAME.mf"
  local OVA="$OUT_DIR/$VM_NAME.ova"

  if [ ! -f "$SRC_QCOW2" ]; then
    echo "Missing $SRC_QCOW2. Run ./scripts/export-vms.sh first." >&2
    exit 1
  fi

  echo "== [$HOST] Converting qcow2 -> stream-optimized VMDK =="
  rm -f "$VMDK"
  qemu-img convert -p -O vmdk -o subformat=streamOptimized "$SRC_QCOW2" "$VMDK"

  local VMDK_SIZE CAPACITY_BYTES
  VMDK_SIZE=$(stat -c %s "$VMDK")
  CAPACITY_BYTES=$(qemu-img info --output=json "$SRC_QCOW2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["virtual-size"])')

  local NETWORK_ENTRIES="" NIC_ITEMS=""
  NETWORK_ENTRIES+="    <Network ovf:name=\"NAT\"><Description>Host-only / NAT network. Do not bridge this to a public network.</Description></Network>\n"
  NIC_ITEMS+="      <Item>\n        <rasd:AddressOnParent>7</rasd:AddressOnParent>\n        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>\n        <rasd:Connection>NAT</rasd:Connection>\n        <rasd:Description>E1000 ethernet adapter -- NAT / build network</rasd:Description>\n        <rasd:ElementName>Network adapter 1</rasd:ElementName>\n        <rasd:InstanceID>5</rasd:InstanceID>\n        <rasd:ResourceSubType>E1000</rasd:ResourceSubType>\n        <rasd:ResourceType>10</rasd:ResourceType>\n      </Item>\n"

  NETWORK_ENTRIES+="    <Network ovf:name=\"$LINK1\"><Description>Private link. Map this adapter to Internal Network, with this exact same name, on both VMs that share it.</Description></Network>\n"
  NIC_ITEMS+="      <Item>\n        <rasd:AddressOnParent>8</rasd:AddressOnParent>\n        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>\n        <rasd:Connection>$LINK1</rasd:Connection>\n        <rasd:Description>E1000 ethernet adapter -- private link (set to Internal Network on import)</rasd:Description>\n        <rasd:ElementName>Network adapter 2</rasd:ElementName>\n        <rasd:InstanceID>6</rasd:InstanceID>\n        <rasd:ResourceSubType>E1000</rasd:ResourceSubType>\n        <rasd:ResourceType>10</rasd:ResourceType>\n      </Item>\n"

  if [ -n "$LINK2" ]; then
    NETWORK_ENTRIES+="    <Network ovf:name=\"$LINK2\"><Description>Private link. Map this adapter to Internal Network, with this exact same name, on both VMs that share it.</Description></Network>\n"
    NIC_ITEMS+="      <Item>\n        <rasd:AddressOnParent>9</rasd:AddressOnParent>\n        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>\n        <rasd:Connection>$LINK2</rasd:Connection>\n        <rasd:Description>E1000 ethernet adapter -- private link (set to Internal Network on import)</rasd:Description>\n        <rasd:ElementName>Network adapter 3</rasd:ElementName>\n        <rasd:InstanceID>7</rasd:InstanceID>\n        <rasd:ResourceSubType>E1000</rasd:ResourceSubType>\n        <rasd:ResourceType>10</rasd:ResourceType>\n      </Item>\n"
  fi

  echo "== [$HOST] Writing OVF descriptor =="
  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<Envelope vmw:buildId="build-%s" xmlns="http://schemas.dmtf.org/ovf/envelope/1" xmlns:cim="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vmw="http://www.vmware.com/schema/ovf" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n' "$VM_NAME"
    printf '  <References>\n    <File ovf:href="%s" ovf:id="file1" ovf:size="%s"/>\n  </References>\n' "$(basename "$VMDK")" "$VMDK_SIZE"
    printf '  <DiskSection>\n    <Info>Virtual disk information</Info>\n    <Disk ovf:capacity="%s" ovf:capacityAllocationUnits="byte" ovf:diskId="vmdisk1" ovf:fileRef="file1" ovf:format="http://www.vmware.com/interfaces/specifications/vmdk.html#streamOptimized" ovf:populatedSize="%s"/>\n  </DiskSection>\n' "$CAPACITY_BYTES" "$VMDK_SIZE"
    printf '  <NetworkSection>\n    <Info>The list of logical networks</Info>\n'
    printf '%b' "$NETWORK_ENTRIES"
    printf '  </NetworkSection>\n'
    printf '  <VirtualSystem ovf:id="%s">\n    <Info>%s</Info>\n    <Name>%s</Name>\n' "$VM_NAME" "$TITLE" "$VM_NAME"
    printf '    <OperatingSystemSection ovf:id="101" ovf:version="24.04" vmw:osType="ubuntu64Guest">\n      <Info>The kind of installed guest operating system</Info>\n      <Description>Ubuntu Linux (64-bit)</Description>\n    </OperatingSystemSection>\n'
    printf '    <VirtualHardwareSection>\n      <Info>Virtual hardware requirements</Info>\n      <System>\n        <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>\n        <vssd:InstanceID>0</vssd:InstanceID>\n        <vssd:VirtualSystemIdentifier>%s</vssd:VirtualSystemIdentifier>\n        <vssd:VirtualSystemType>vmx-19</vssd:VirtualSystemType>\n      </System>\n' "$VM_NAME"
    printf '      <Item>\n        <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>\n        <rasd:Description>Number of virtual CPUs</rasd:Description>\n        <rasd:ElementName>%s virtual CPU(s)</rasd:ElementName>\n        <rasd:InstanceID>1</rasd:InstanceID>\n        <rasd:ResourceType>3</rasd:ResourceType>\n        <rasd:VirtualQuantity>%s</rasd:VirtualQuantity>\n      </Item>\n' "$CPUS" "$CPUS"
    printf '      <Item>\n        <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>\n        <rasd:Description>Memory Size</rasd:Description>\n        <rasd:ElementName>%sMB of memory</rasd:ElementName>\n        <rasd:InstanceID>2</rasd:InstanceID>\n        <rasd:ResourceType>4</rasd:ResourceType>\n        <rasd:VirtualQuantity>%s</rasd:VirtualQuantity>\n      </Item>\n' "$MEM_MB" "$MEM_MB"
    printf '      <Item>\n        <rasd:Address>0</rasd:Address>\n        <rasd:Description>IDE Controller</rasd:Description>\n        <rasd:ElementName>IDE Controller 0</rasd:ElementName>\n        <rasd:InstanceID>3</rasd:InstanceID>\n        <rasd:ResourceSubType>PIIX4</rasd:ResourceSubType>\n        <rasd:ResourceType>5</rasd:ResourceType>\n      </Item>\n'
    printf '      <Item>\n        <rasd:AddressOnParent>0</rasd:AddressOnParent>\n        <rasd:ElementName>Hard Disk 1</rasd:ElementName>\n        <rasd:HostResource>ovf:/disk/vmdisk1</rasd:HostResource>\n        <rasd:InstanceID>4</rasd:InstanceID>\n        <rasd:Parent>3</rasd:Parent>\n        <rasd:ResourceType>17</rasd:ResourceType>\n      </Item>\n'
    printf '%b' "$NIC_ITEMS"
    printf '    </VirtualHardwareSection>\n    <AnnotationSection>\n      <Info>A description of the meaning of the VM</Info>\n      <Annotation>%s</Annotation>\n    </AnnotationSection>\n  </VirtualSystem>\n</Envelope>\n' "$ANNOTATION"
  } > "$OVF"

  echo "== [$HOST] Validating the OVF XML is well-formed =="
  python3 -c "import xml.etree.ElementTree as ET; ET.parse('$OVF')" && echo "XML OK"

  echo "== [$HOST] Writing the manifest (.mf) =="
  local OVF_HASH VMDK_HASH
  OVF_HASH=$(sha256sum "$OVF" | cut -d' ' -f1)
  VMDK_HASH=$(sha256sum "$VMDK" | cut -d' ' -f1)
  cat > "$MF" <<EOF
SHA256($(basename "$OVF"))= $OVF_HASH
SHA256($(basename "$VMDK"))= $VMDK_HASH
EOF

  echo "== [$HOST] Packing the .ova =="
  rm -f "$OVA"
  tar -C "$OUT_DIR" -cf "$OVA" "$(basename "$OVF")" "$(basename "$MF")" "$(basename "$VMDK")"

  echo "== [$HOST] Structural self-check =="
  tar -tvf "$OVA"
  ( cd "$OUT_DIR" && sha256sum -c "$(basename "$MF")" )

  echo
  echo "Built: $OVA ($(du -h "$OVA" | cut -f1))"
  rm -f "$VMDK" "$OVF" "$MF"
}

# Chain topology: portal <-> waystation <-> vault. portal only links
# to waystation (its SSRF never targets vault directly); waystation
# is the middle host with two links; vault only links to waystation.
build_one portal portal-the-ferryman-ctf \
  "Case File 8 (God) -- The Ferryman -- Portal -- Halcyon Protocol CTF VM (Ubuntu Server 24.04 LTS, native)" \
  "Case File 8 (God) -- The Ferryman -- Portal (capstone). Deliberately vulnerable, isolated lab use only. Import together with the matching Waystation and Vault VMs; map adapter 2 to halcyon-ferryman-portal-waystation-link (see vm/README.md)." \
  "halcyon-ferryman-portal-waystation-link"

build_one waystation waystation-the-ferryman-ctf \
  "Case File 8 (God) -- The Ferryman -- Waystation -- Halcyon Protocol CTF VM (Ubuntu Server 24.04 LTS, native)" \
  "Case File 8 (God) -- The Ferryman -- Waystation (capstone). Deliberately vulnerable, isolated lab use only. Never reachable except via Portal's internal link -- import together with Portal and Vault, map adapter 2 to halcyon-ferryman-portal-waystation-link and adapter 3 to halcyon-ferryman-waystation-vault-link (see vm/README.md)." \
  "halcyon-ferryman-portal-waystation-link" "halcyon-ferryman-waystation-vault-link"

build_one vault vault-the-ferryman-ctf \
  "Case File 8 (God) -- The Ferryman -- Vault -- Halcyon Protocol CTF VM (Ubuntu Server 24.04 LTS, native)" \
  "Case File 8 (God) -- The Ferryman -- Vault (capstone). Deliberately vulnerable, isolated lab use only. Never reachable except via Waystation's internal link -- import together with Portal and Waystation, map adapter 2 to halcyon-ferryman-waystation-vault-link (see vm/README.md)." \
  "halcyon-ferryman-waystation-vault-link"

echo
echo "All three OVAs built. VBoxManage not found on this host -- only structurally"
echo "validated (XML, tar layout, manifest checksums). Test a real import with"
echo "VBoxManage import <ova> --dry-run or VMware Workstation/Fusion's File > Open."
