bash -c 'set -e
# ----------------------------
# Config
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

# ----------------------------
# Création VM
# ----------------------------
qm create $VMID --name $VM_NAME --memory $RAM --cores $CPUS --net0 virtio,bridge=$BRIDGE --boot c --bootdisk scsi0
qm importdisk $VMID $ISO_PATH $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:$DISK_SIZE
qm set $VMID --ide2 $STORAGE:cloudinit
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --serial0 socket --vga serial0

# ----------------------------
# Configuration Cloud-Init
# ----------------------------
qm set $VMID --ciuser $USER_NAME --cipassword $USER_PASS --citype nocloud
qm set $VMID --agent 1

# ----------------------------
# Script d\'installation Cura
# ----------------------------
cat << "EOF" > /tmp/setup_cura.sh
#!/bin/bash
set -e
apt update && apt upgrade -y
apt install -y python3-pip python3-pyqt5 python3-setuptools xorg openbox wget
pip3 install --upgrade pip
pip3 install --user cura
cat << "EOL" > /home/$USER/start_cura.sh
#!/bin/bash
xinit -- /usr/bin/openbox-session &
sleep 2
~/.local/bin/cura
EOL
chmod +x /home/$USER/start_cura.sh
(crontab -l 2>/dev/null; echo "@reboot /home/$USER/start_cura.sh") | crontab -
EOF

# ----------------------------
# Injection du script dans la VM via cloud-init
# ----------------------------
qm set $VMID --ciuser $USER_NAME --cipassword $USER_PASS --sshkeys /root/.ssh/id_rsa.pub
qm set $VMID --cicustom "user=local:snippets/setup_cura.sh"
mkdir -p /var/lib/vz/snippets
cp /tmp/setup_cura.sh /var/lib/vz/snippets/setup_cura.sh
chmod +x /var/lib/vz/snippets/setup_cura.sh

# ----------------------------
# Démarrage automatique
# ----------------------------
qm start $VMID
echo "VM $VM_NAME (ID $VMID) démarrée. Cura s\'installera et se lancera automatiquement."
'
