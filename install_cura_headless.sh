#!/bin/bash
set -e

# ----------------------------
# CONFIGURATION
# ----------------------------
VMID=9000
VM_NAME="cura-vm"
ISO_PATH="/var/lib/vz/template/iso/debian-12.6.0-amd64-netinst.iso"
STORAGE="local-lvm"
DISK_SIZE="20G"
RAM="2048"
CPUS="2"
BRIDGE="vmbr0"
USER_NAME="curauser"
USER_PASS="CuraPass123"
SNIPPET_DIR="/var/lib/vz/snippets"

mkdir -p $SNIPPET_DIR

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
qm set $VMID --ide2 $STORAGE:iso,media=cdrom
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --serial0 socket --vga serial0

# ----------------------------
# SCRIPT D'INSTALLATION CURA
# ----------------------------
cat << 'EOF' > $SNIPPET_DIR/setup_cura.sh
#!/bin/bash
set -e
# Mise à jour et dépendances
apt update && apt upgrade -y
apt install -y python3-pip python3-pyqt5 python3-setuptools xorg openbox wget sudo

# Création de l'utilisateur Cura
if ! id -u curauser >/dev/null 2>&1; then
    useradd -m -s /bin/bash curauser
    echo "curauser:CuraPass123" | chpasswd
    usermod -aG sudo curauser
fi

# Installation de Cura
sudo -u curauser -H bash -c "pip3 install --upgrade pip"
sudo -u curauser -H bash -c "pip3 install --user cura"

# Script de lancement automatique
cat << "EOL" > /home/curauser/start_cura.sh
#!/bin/bash
xinit -- /usr/bin/openbox-session &
sleep 2
/home/curauser/.local/bin/cura
EOL
chmod +x /home/curauser/start_cura.sh
(crontab -l 2>/dev/null; echo "@reboot /home/curauser/start_cura.sh") | crontab -u curauser -

echo "[+] Cura installé et configuré pour démarrage automatique"
EOF

chmod +x $SNIPPET_DIR/setup_cura.sh

# ----------------------------
# Injection du script dans la VM
# ----------------------------
qm set $VMID --cicustom "user=local:snippets/setup_cura.sh"

# ----------------------------
# DEMARRAGE DE LA VM
# ----------------------------
qm start $VMID
echo "[+] VM $VM_NAME (ID $VMID) démarrée. Debian sera installé automatiquement et Cura configuré."
