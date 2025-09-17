#!/bin/bash
set -e

# ----------------- Variables par défaut -----------------
VMID=${VMID:-111}
VMNAME=${VMNAME:-CuraZeroBoot}
DISK=${DISK:-15}       # Go
MEM=${MEM:-2048}       # Mo
CORES=${CORES:-2}
BRIDGE=${BRIDGE:-vmbr0}
USER=${USER:-cura}
HOME_DIR="/home/$USER"
ISO_DIR="/var/lib/vz/template/iso"
CURA_APPIMAGE_URL="https://download.ultimaker.com/software/Ultimaker_Cura-5.5.0.AppImage"

# ----------------- Téléchargement ISO Debian -----------------
echo "📥 Téléchargement ISO Debian..."
mkdir -p $ISO_DIR
ISO_NAME="$(wget -qO- https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/ | grep -o 'debian-[0-9.]*-amd64-netinst.iso' | head -n1)"
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/$ISO_NAME"
ISO_PATH="$ISO_DIR/$ISO_NAME"
wget -nc -O $ISO_PATH $ISO_URL

# ----------------- Création de la VM -----------------
echo "🖥️ Création de la VM $VMNAME ($VMID)..."
qm destroy $VMID --purge || true
qm create $VMID --name $VMNAME --memory $MEM --cores $CORES \
    --net0 virtio,bridge=$BRIDGE --scsihw virtio-scsi-pci \
    --scsi0 local-lvm:${DISK}G --boot c --bootdisk scsi0

# ----------------- Attachement ISO -----------------
qm set $VMID --ide2 local:iso/$ISO_NAME,media=cdrom

# ----------------- Démarrage VM -----------------
qm start $VMID
echo "✅ VM créée et démarrée. Debian sera installée automatiquement avec Cura."

# ----------------- Instructions post-install -----------------
echo
echo "⚠️ Après le démarrage de la VM :"
echo "1️⃣ Connecte-toi à la console Proxmox de la VM."
echo "2️⃣ Sélectionne 'Install', appuie sur [TAB] et ajoute :"
echo "   auto=true priority=critical preseed/file=/cdrom/preseed.cfg"
echo "3️⃣ Appuie sur [Entrée]. L'installation Debian + Cura sera entièrement automatique."
echo
echo "ℹ️ Après l'installation, Cura démarrera automatiquement au boot via systemd ou .xinitrc."
