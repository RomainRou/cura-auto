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
RAW_CURA="https://raw.githubusercontent.com/RomainRou/cura-auto/main/install_cura.sh"

# ----------------- Téléchargement ISO Debian -----------------
echo "📥 Téléchargement ISO Debian..."
mkdir -p $ISO_DIR
ISO_NAME="$(wget -qO- https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/ | grep -o 'debian-[0-9.]*-amd64-netinst.iso' | head -n1)"
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/$ISO_NAME"
ISO_PATH="$ISO_DIR/$ISO_NAME"
wget -nc -O $ISO_PATH $ISO_URL

# ----------------- Préseed Debian (auto-install) -----------------
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
d-i grub-installer/with_other_os boolean true
d-i preseed/late_command string in-target bash -c "wget -O /root/install_cura.sh $RAW_CURA && bash /root/install_cura.sh && cat <<EOT >/etc/systemd/system/cura.service
[Unit]
Description=Auto-start Ultimaker Cura
After=graphical.target

[Service]
User=$USER
Environment=DISPLAY=:0
ExecStart=/usr/bin/cura
Restart=always

[Install]
WantedBy=graphical.target
EOT
systemctl enable cura.service"
d-i finish-install/reboot_in_progress note
EOF

# ----------------- Création de la VM -----------------
echo "🖥️ Création de la VM $VMNAME ($VMID)..."
qm destroy $VMID --purge || true
qm create $VMID --name $VMNAME --memory $MEM --cores $CORES \
    --net0 virtio,bridge=$BRIDGE --scsihw virtio-scsi-pci \
    --scsi0 local-lvm:${DISK}G --boot c --bootdisk scsi0

# ----------------- Attachement ISO et Preseed -----------------
qm set $VMID --ide2 local:iso/$ISO_NAME,media=cdrom
qm set $VMID --ide3 local:iso/preseed.cfg,media=cdrom

# ----------------- Démarrage -----------------
qm start $VMID

echo "✅ VM créée et démarrée. Debian + Cura s'installeront automatiquement sans aucune intervention."
