#!/bin/bash
set -e

# ----------------- Variables par défaut -----------------
VMID=${VMID:-111}
VMNAME=${VMNAME:-CuraZeroBoot}
DISK=${DISK:-32}       # Go
MEM=${MEM:-4096}       # Mo
CORES=${CORES:-2}
BRIDGE=${BRIDGE:-vmbr0}
USER=${USER:-cura}
HOME_DIR="/home/$USER"
ISO_DIR="/var/lib/vz/template/iso"
CURA_APPIMAGE_URL="https://download.ultimaker.com/software/Ultimaker_Cura-5.5.0.AppImage"

# ----------------- Forcer le stockage correct -----------------
STORAGE="local-lvm"
echo "💾 Utilisation du stockage : $STORAGE"

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
d-i preseed/late_command string in-target bash -c "
apt update
apt install -y xorg openbox wget libglu1-mesa libxi6 libxrender1 libxrandr2 libxinerama1
useradd -m -s /bin/bash $USER || true
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
d-i finish-install/reboot_in_progress note
EOF

# ----------------- Création de la VM -----------------
echo "🖥️ Création de la VM $VMNAME ($VMID)..."
qm destroy $VMID --purge || true
qm create $VMID --name $VMNAME --memory $MEM --cores $CORES \
    --net0 virtio,bridge=$BRIDGE --scsihw virtio-scsi-pci \
    --scsi0 $STORAGE:${DISK}G --boot c --bootdisk scsi0

# ----------------- Attachement ISO et Preseed -----------------
qm set $VMID --ide2 $STORAGE:iso/$ISO_NAME,media=cdrom
qm set $VMID --ide3 $STORAGE:iso/preseed.cfg,media=cdrom

# ----------------- Démarrage -----------------
qm start $VMID

echo "✅ VM créée et démarrée. Debian + Cura s'installeront automatiquement sans aucune interaction."
