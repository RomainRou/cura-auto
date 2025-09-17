#!/usr/bin/env bash
set -e

# ---------- Fonctions ----------
function header_info {
  clear
  cat <<"EOF"
   ____                  _     
  / ___|  ___ __ _ _ __ | |__  
 | |     / __/ _` | '_ \| '_ \ 
 | |___ | (_| (_| | | | | | | |
  \____| \___\__,_|_| |_|_| |_|
  Automated Cura VM Installer
EOF
}

function check_root {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "[ERROR] Run this script as root."
    exit 1
  fi
}

function select_storage {
  STORAGE_MENU=()
  MSG_MAX_LENGTH=0
  while read -r line; do
    TAG=$(echo $line | awk '{print $1}')
    TYPE=$(echo $line | awk '{printf "%-10s", $2}')
    FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
    ITEM=" Type: $TYPE Free: $FREE "
    OFFSET=2
    [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]] && MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
    STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
  done < <(pvesm status -content images | awk 'NR>1')

  if [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
    STORAGE=${STORAGE_MENU[0]}
  else
    STORAGE=$(whiptail --backtitle "Proxmox Cura VM Installer" --title "Select Storage" --radiolist \
      "Select storage for the VM (Space to select):" 16 $(($MSG_MAX_LENGTH + 23)) 6 "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  fi
  echo "Using storage: $STORAGE"
}

function create_vm {
  NEXTID=$(pvesh get /cluster/nextid)
  VMID=$NEXTID
  wget -q https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 -O vm-${VMID}-disk-0.qcow2
  qm create $VMID -name "cura-vm" -memory 4096 -cores 2 -net0 virtio,bridge=vmbr0 -ostype l26
  pvesm alloc $STORAGE $VMID vm-${VMID}-disk-0.qcow2 4M
  qm importdisk $VMID vm-${VMID}-disk-0.qcow2 $STORAGE -format qcow2
  qm set $VMID --scsi0 ${STORAGE}:vm-$VMID-disk-0,discard=on,ssd=1
  qm set $VMID -boot order=scsi0
  qm set $VMID -agent 1
  qm start $VMID
  echo "VM $VMID created and started"
}

function install_cura {
  VMID=$1
  echo "[INFO] Installing Cura inside VM $VMID..."
  # Copie et exécution d’un script d’installation dans la VM
  qm agent $VMID exec "bash -c 'apt update && apt install -y software-properties-common && add-apt-repository -y ppa:ultimaker/cura && apt update && apt install -y cura'"
  echo "[INFO] Cura installation complete."
}

# ---------- Script ----------
check_root
header_info
select_storage
create_vm
install_cura $VMID
echo "[DONE] Cura VM is ready!"
