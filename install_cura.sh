#!/bin/bash
set -e

# ----------------------------
# CONFIGURATION
# ----------------------------
VMID=9000
VM_NAME="cura-vm"
TEMPLATE="local:vztmpl/debian-12-standard_12.6-1_amd64.tar.gz"  # template cloud Debian
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

qm importdisk $VMID $TEMPLATE $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:$DISK_SIZE
qm set $VMID --ide2 $STORAGE:cloudinit
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --serial0 socket --vga serial0

# ----------------------------
# CONFIGURATION CLOUD-INIT
# ----------------------------
qm set $VMID --ciuser $USER_NAME --cipassword $USER_PASS --citype nocloud
qm set $VMID --agent 1

# ----------------------------
# SCRIPT D'INSTALLATION CURA
# ----------------------------
cat << 'EOF' > /var/lib/vz/snippets/setup_cura.sh
#!/bin/bash
set -e
# Mise à jour et dépendances
apt update && apt upgrade -y
apt install -y python3-pip python3-pyqt5 python3-setuptools xorg openbox wget

# Installation de Cura
pip3 install --upgrade pip
pip3 install --user cura

# Script de lancement automatique
cat << "EOL" > /home/$USER/start_cura.sh
#!/bin/bash
xinit -- /usr/bin/openbox-session &
sleep 2
~/.local/bin/cura
EOL
chmod +x /home/$USER/start_cura.sh

# Ajout au démarrage via crontab
(crontab -l 2>/dev/null; echo "@reboot /home/$USER/start_cura.sh") | crontab -
EOF

chmod +x /var/lib/vz/snippets/setup_cura.sh
qm set $VMID --cicustom "user=local:snippets/setup_cura.sh"

# ----------------------------
# DEMARRAGE DE LA VM
# ----------------------------
qm start $VMID
echo "[+] VM $VM_NAME (ID $VMID) démarrée. Cura sera installé et lancé automatiquement."
