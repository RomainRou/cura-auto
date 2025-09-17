#!/usr/bin/env bash
# Debian 12 minimal VM + Cura GUI minimal autostart

set -e
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

# ---------- Variables ----------
VMID=$(pvesh get /cluster/nextid)
HN="debian"
CORE_COUNT=2
RAM_SIZE=4096   # un peu plus pour GUI
BRG="vmbr0"
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
MAC="$GEN_MAC"
START_VM="yes"
DISK_SIZE="32G"  # pour Cura + fichiers STL

# ---------- Create VM ----------
echo "[INFO] Creating Debian 12 minimal VM..."
qm create $VMID -name $HN -cores $CORE_COUNT -memory $RAM_SIZE \
    -net0 virtio,bridge=$BRG,macaddr=$MAC -onboot 1 -ostype l26 -scsihw virtio-scsi-pci

STORAGE=$(pvesm status -content images | awk 'NR==2{print $1}')
DISK_FILE="vm-${VMID}-disk-0.qcow2"
qm importdisk $VMID https://cloud.debian.org/images/cloud/bookworm/20240507-1740/debian-12-nocloud-amd64-20240507-1740.qcow2 $STORAGE

qm set $VMID -scsi0 ${STORAGE}:vm-$VMID-disk-0,cache=none,size=$DISK_SIZE \
    -boot order=scsi0 -serial0 socket -vga virtio

# ---------- Start VM ----------
if [ "$START_VM" == "yes" ]; then
    echo "[INFO] Starting VM $VMID..."
    qm start $VMID
fi

# ---------- Install minimal X + Cura ----------
echo "[INFO] Installing minimal X server and Cura..."
qm terminal $VMID << 'EOF'
set -e
apt update
apt install -y --no-install-recommends xserver-xorg-core xserver-xorg-video-all x11-xserver-utils \
    wget curl software-properties-common sudo

# Install Cura
add-apt-repository ppa:thopiekar/cura -y
apt update
apt install -y cura

# Create a minimal X session to launch Cura
mkdir -p /root/.xinitrc
cat << EOF_XINIT > /root/.xinitrc
#!/bin/bash
# Launch Cura directly in X
/usr/bin/cura
EOF_XINIT
chmod +x /root/.xinitrc

# Create systemd service to start X at boot
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
echo "[SUCCESS] Debian 12 VM with minimal X + Cura GUI installed and autostart enabled!"
