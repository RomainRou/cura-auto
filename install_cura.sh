#!/usr/bin/env bash
set -e

# ========================
#  Auto-install Debian + Cura on Proxmox
# ========================

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

# -------- USER VARIABLES --------
VMID=${VMID:-111}
VMNAME=${VMNAME:-CuraZeroBoot}
MEM=${MEM:-4096}           # RAM in MB
CORES=${CORES:-2}
DISK=${DISK:-32}           # Disk in GB
BRIDGE=${BRIDGE:-vmbr0}
STORAGE=${STORAGE:-local-lvm}
ISO_NAME="debian-13.1.0-amd64-netinst.iso"
ISO_PATH="/var/lib/vz/template/iso/$ISO_NAME"
PRESEED_DIR="/var/www/html/cura"
PRESEED_URL="http://$(hostname -I | awk '{print $1}')/cura/preseed.cfg"
CURA_SCRIPT_URL="https://raw.githubusercontent.com/RomainRou/cura-auto/main/install_cura.sh"

# -------- FUNCTIONS --------
function msg_info()  { echo -ne "[..] $1...\n"; }
function msg_ok()    { echo -e "[✓] $1"; }
function msg_error() { echo -e "[✗] $1"; }

# -------- CHECK ROOT --------
if [[ $EUID -ne 0 ]]; then
  msg_error "Run this script as root."
  exit 1
fi

# -------- DOWNLOAD ISO --------
mkdir -p /var/lib/vz/template/iso
if [ ! -f "$ISO_PATH" ]; then
  msg_info "Downloading Debian ISO..."
  wget -O "$ISO_PATH" "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/$ISO_NAME"
  msg_ok "Downloaded $ISO_NAME"
else
  msg_ok "Debian ISO already exists"
fi

# -------- CREATE PRESEED --------
mkdir -p "$PRESEED_DIR"
cat <<EOF > $PRESEED_DIR/preseed.cfg
d-i debian-installer/locale string en_US
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/get_hostname string cura-vm
d-i netcfg/get_domain string local
d-i mirror/country string manual
d-i mirror/http/hostname string ftp.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
d-i passwd/user-fullname string Cura User
d-i passwd/username string cura
d-i passwd/user-password password cura
d-i passwd/user-password-again password cura
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
tasksel tasksel/first multiselect standard, ssh-server
d-i finish-install/reboot_in_progress note
d-i preseed/late_command string wget -O /tmp/install_cura.sh $CURA_SCRIPT_URL && bash /tmp/install_cura.sh
EOF
msg_ok "Preseed file created"

# -------- CREATE VM --------
msg_info "Creating VM $VMNAME ($VMID) on $STORAGE..."
qm create $VMID \
    -name $VMNAME \
    -memory $MEM \
    -cores $CORES \
    -net0 virtio,bridge=$BRIDGE \
    -scsihw virtio-scsi-pci \
    -ostype l26

# Create disk on local-lvm
pvesm alloc $STORAGE $VMID vm-${VMID}-disk-0 $DISK
qm set $VMID -scsi0 $STORAGE:vm-${VMID}-disk-0

# Attach ISO and boot
qm set $VMID -ide2 local:iso/$ISO_NAME,media=cdrom
qm set $VMID -boot order=ide2

# Start VM
qm start $VMID
msg_ok "VM started. Debian will install automatically with preseed."
msg_ok "Cura will be installed post-install via preseed late_command."
