#!/usr/bin/env bash
# Script pour créer une VM Debian 12 et installer Cura GUI avec choix du stockage
set -e

# ---------- Variables ----------
VMID=$(pvesh get /cluster/nextid)
HN="cura-vm"
CORE_COUNT=2
RAM_SIZE=4096
DISK_SIZE="32G"
BRG="vmbr0"
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
MAC="$GEN_MAC"
START_VM="yes"
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

# ---------- Choix du stockage ----------
STORAGE_OPTIONS=($(pvesm status -content images | awk 'NR>1{print $1}'))
echo "Choisissez le stockage pour la VM :"
select STORAGE in "${STORAGE_OPTIONS[@]}"; do
  if [[ -n "$STORAGE" ]]; then
    echo "[INFO] Stockage choisi : $STORAGE"
    break
  fi
done

# ---------- Télécharger Debian 12 QCOW2 ----------
DEBIAN_QCOW_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
DISK_FILE="vm-${VMID}-disk-0.qcow2"
echo "[INFO] Téléchargement de l'image Debian 12..."
wget -O $DISK_FILE $DEBIAN_QCOW_URL

# ---------- Créer la VM ----------
echo "[INFO] Création de la VM Debian 12 minimale..."
qm create $VMID -name $HN -cores $CORE_COUNT -memory $RAM_SIZE \
    -net0 virtio,bridge=$BRG,macaddr=$MAC -onboot 1 -ostype l26 -scsihw virtio-scsi-pci

# ---------- Importer le disque ----------
echo "[INFO] Importation du disque sur $STORAGE..."
qm importdisk $VMID $DISK_FILE $STORAGE
qm set $VMID --scsi0 ${STORAGE}:vm-$VMID-disk-0,discard=on,ssd=1,format=raw
qm set $VMID --boot order=scsi0 --serial0 socket --vga virtio

# ---------- Démarrer la VM ----------
if [ "$START_VM" == "yes" ]; then
    echo "[INFO] Démarrage de la VM $VMID..."
    qm start $VMID
fi

# ---------- Installer X minimal et Cura GUI ----------
echo "[INFO] Installation de X minimal et Cura GUI..."
qm terminal $VMID << 'EOF'
set -e
apt update
apt install -y --no-install-recommends xserver-xorg-core xserver-xorg-video-all x11-xserver-utils wget software-properties-common sudo

# Installer Cura GUI
add-apt-repository ppa:thopiekar/cura -y
apt update
apt install -y cura

# Créer une session X minimale pour lancer Cura
mkdir -p /root/.xinitrc
cat << EOF_XINIT > /root/.xinitrc
#!/bin/bash
/usr/bin/cura
EOF_XINIT
chmod +x /root/.xinitrc

# Service systemd pour lancer Cura au boot
cat << EOF_SYSTEMD > /etc/systemd/system/cura-x.service
[Unit]
Description=Launch Cura GUI on minimal X
After=network.target

[Service]
User=root
ExecStart=/usr/bin/startx /root/.xinitrc --
Restart=always
Environment=DISPLAY=:0

[Install]
WantedBy=multi-user.target
EOF_SYSTEMD

systemctl enable cura-x.service
systemctl start cura-x.service
EOF

popd >/dev/null
rm -rf $TEMP_DIR
echo "[SUCCESS] VM Debian 12 avec Cura GUI installée et autostart activé sur le stockage choisi !"
