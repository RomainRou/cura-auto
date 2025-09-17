#!/bin/bash
set -e

# ----------------------------
# CONFIGURATION
# ----------------------------
VMID=9000
VM_NAME="cura-vm"
ISO_PATH="/var/lib/vz/template/iso/debian-12.6.0-amd64-netinst.iso"  # ISO Debian minimal
STORAGE="local-lvm"
DISK_SIZE="20G"
RAM="2048"
CPUS="2"
BRIDGE="vmbr0"
USER_NAME="curauser"
USER_PASS="CuraPass123"

# ----------------------------
# CREATION DE LA VM
# ----------------------------
echo "[+] Création de la VM $VM_NAME avec ID $VMID..."
qm create $VMID \
  --name $VM_NAME \
  --memory $RAM \
  --cores $CPUS \
  --net0 virtio,bridge=$BRIDGE \
  --boot c \
  --bootdisk scsi0

qm importdisk $VMID $ISO_PATH $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:$DISK_SIZE
qm set $VMID --ide2 $STORAGE:cloudinit
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --serial0 socket --vga serial0

echo "[+] VM créée. Démarrez la VM via l'interface web Proxmox pour installer Debian minimal."
echo "[!] Après installation de Debian, connectez-vous et exécutez le script de setup Cura :"
echo "    wget -O /tmp/setup_cura.sh https://raw.githubusercontent.com/RomainRou/cura-auto/main/setup_cura.sh && bash /tmp/setup_cura.sh"
