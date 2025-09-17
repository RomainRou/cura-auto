#!/usr/bin/env bash
# Copyright (c) 2025
# Author: RomainRou
# License: MIT
# GitHub: https://github.com/RomainRou/cura-auto

function header_info {
  clear
  cat <<"EOF"
   ____                 _             
  / ___|_ __ __ _ _ __ | | _____ _ __ 
 | |   | '__/ _` | '_ \| |/ / _ \ '__|
 | |___| | | (_| | | | |   <  __/ |   
  \____|_|  \__,_|_| |_|_|\_\___|_|   
EOF
}

header_info
echo -e "\n Loading..."

GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)

VMID=${VMID:-$NEXTID}
VMNAME=${VMNAME:-CuraZeroBoot}
MEM=${MEM:-4096}
CORES=${CORES:-2}
DISK=${DISK:-32}       # Go
BRIDGE=${BRIDGE:-vmbr0}
USER=${USER:-cura}

STORAGE_DISK="local-lvm"
STORAGE_ISO="local"
ISO_DIR="/var/lib/vz/template/iso"
CURA_APPIMAGE_URL="https://download.ultimaker.com/software/Ultimaker_Cura-5.5.0.AppImage"

set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  echo -e "[ERROR] in line $line_number: exit code $exit_code: $command"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function msg_info() { echo -ne " [..] $1..."; }
function msg_ok() { echo -e " [✓] $1"; }

check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Please run as root."; exit
  fi
}

check_root

# ----------------- Téléchargement ISO -----------------
mkdir -p $ISO_DIR
msg_info "Downloading Debian ISO"
ISO_NAME="$(wget -qO- https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/ | grep -o 'debian-[0-9.]*-amd64-netinst.iso' | head -n1)"
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/$ISO_NAME"
ISO_PATH="$ISO_DIR/$ISO_NAME"
wget -nc -O $ISO_PATH $ISO_URL
msg_ok "Downloaded $ISO_NAME"

# ----------------- Préseed -----------------
PRESEED="$ISO_DIR/preseed.cfg"
cat <<EOF > $PRESEED
d-i debian-installer/locale string en_US
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/get_hostname string $VMNAME
d-i netcfg/get_domain string local
d-i mirror/country string manual
d-i mirror/http/hostname string ftp.debian.org
d-i mirror/http/directory string /debian
d-i passwd/user-fullname string Cura User
d-i passwd/username string $USER
d-i passwd/user-password password cura
d-i passwd/user-password-again password cura
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
tasksel tasksel/first multiselect standard, ssh-server
d-i grub-installer/only_debian boolean true
d-i preseed/late_command string in-target bash -c "
apt update
apt install -y xorg openbox wget libglu1-mesa libxi6 libxrender1 libxrandr2 libxinerama1
wget -O /home/$USER/Cura.AppImage $CURA_APPIMAGE_URL
chmod +x /home/$USER/Cura.AppImage
chown -R $USER:$USER /home/$USER
echo '#!/bin/bash
/home/$USER/Cura.AppImage' > /home/$USER/.xinitrc
chown $USER:$USER /home/$USER/.xinitrc
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOT >/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOT
systemctl daemon-reexec
echo 'if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    startx
fi' >> /home/$USER/.bash_profile
chown $USER:$USER /home/$USER/.bash_profile
"
EOF

# ----------------- Création VM -----------------
msg_info "Creating VM $VMNAME ($VMID) on $STORAGE_DISK"
qm destroy $VMID --purge || true
qm create $VMID --name $VMNAME --memory $MEM --cores $CORES \
  --net0 virtio,bridge=$BRIDGE,macaddr=$GEN_MAC --scsihw virtio-scsi-pci \
  --scsi0 $STORAGE_DISK:$DISK,format=raw --boot c --bootdisk scsi0
msg_ok "VM Created"

# ----------------- Attachement ISO et Preseed -----------------
qm set $VMID --ide2 $STORAGE_ISO:iso/$ISO_NAME,media=cdrom
qm set $VMID --ide3 $STORAGE_ISO:iso/preseed.cfg,media=cdrom

# ----------------- Démarrage VM -----------------
msg_info "Starting VM $VMNAME"
qm start $VMID
msg_ok "VM started! Debian + Cura will install automatically"
