#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<<$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/api.func)

function header_info {
  clear
  cat <<"EOF"
    ____       __    _                ________
   / __ \___  / /_  (_)___ _____     <  /__  /
  / / / / _ \/ __ \/ / __ `/ __ \    / / /_ <
 / /_/ /  __/ /_/ / / /_/ / / / /   / /___/ /
/_____/\___/_.___/_/\__,_/_/ /_/   /_//____/
                                              (Trixie)
EOF
}
header_info
echo -e "\n Loading..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
RANDOM_UUID="$(cat /proc/sys/kernel/random/uuid)"
METHOD=""
NSAPP="debian13vm"
var_os="debian"
var_version="13"

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BOLD=$(echo "\033[1m")
BFR="\\r\\033[K"
HOLD=" "
TAB="  "

CM="${TAB}✔️${TAB}${CL}"
CROSS="${TAB}✖️${TAB}${CL}"
INFO="${TAB}💡${TAB}${CL}"
OS="${TAB}🖥️${TAB}${CL}"
CONTAINERTYPE="${TAB}📦${TAB}${CL}"
DISKSIZE="${TAB}💾${TAB}${CL}"
CPUCORE="${TAB}🧠${TAB}${CL}"
RAMSIZE="${TAB}🛠️${TAB}${CL}"
CONTAINERID="${TAB}🆔${TAB}${CL}"
HOSTNAME="${TAB}🏠${TAB}${CL}"
BRIDGE="${TAB}🌉${TAB}${CL}"
GATEWAY="${TAB}🌐${TAB}${CL}"
DEFAULT="${TAB}⚙️${TAB}${CL}"
MACADDRESS="${TAB}🔗${TAB}${CL}"
VLANTAG="${TAB}🏷️${TAB}${CL}"
CREATING="${TAB}🚀${TAB}${CL}"
ADVANCED="${TAB}🧩${TAB}${CL}"
CLOUD="${TAB}☁️${TAB}${CL}"

THIN="discard=on,ssd=1,"
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
trap 'post_update_to_api "failed" "INTERRUPTED"' SIGINT
trap 'post_update_to_api "failed" "TERMINATED"' SIGTERM

function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  post_update_to_api "failed" "${command}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function get_valid_nextid() {
  local try_id
  try_id=$(pvesh get /cluster/nextid)
  while true; do
    if [ -f "/etc/pve/qemu-server/${try_id}.conf" ] || [ -f "/etc/pve/lxc/${try_id}.conf" ]; then
      try_id=$((try_id + 1))
      continue
    fi
    if lvs --noheadings -o lv_name | grep -qE "(^|[-_])${try_id}($|[-_])"; then
      try_id=$((try_id + 1))
      continue
    fi
    break
  done
  echo "$try_id"
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  post_update_to_api "done" "none"
  rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
if whiptail --backtitle "Proxmox VE Helper Scripts" --title "Debian 13 VM" --yesno "This will create a New Debian 13 VM. Proceed?" 10 58; then
  :
else
  header_info && echo -e "${CROSS}${RD}User exited script${CL}\n" && exit
fi

# (Toutes les fonctions de settings et vérifications restent identiques ici…)

# --- START SCRIPT LOGIC ---
check_root
arch_check
pve_check
ssh_check
start_script

post_to_api_vm

# Storage validation, VM creation, download of Debian image (identique à ton script existant)...

# --- Après avoir démarré la VM, installer Cura ---
function install_cura() {
    msg_info "Installing Ultimaker Cura..."
    
    # Installer les dépendances requises
    apt-get update -y
    apt-get install -y wget gdebi-core libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6

    # Télécharger le dernier Cura AppImage
    CURA_VERSION="6.1.1"
    wget -q https://github.com/Ultimaker/Cura/releases/download/${CURA_VERSION}/Ultimaker_Cura-${CURA_VERSION}-AppImage -O /usr/local/bin/cura.AppImage
    chmod +x /usr/local/bin/cura.AppImage

    # Créer un lien symbolique pour lancer Cura facilement
    ln -sf /usr/local/bin/cura.AppImage /usr/local/bin/cura

    msg_ok "Ultimaker Cura installation completed!"
}

# Démarrage VM
if [ "$START_VM" == "yes" ]; then
  msg_info "Starting Debian 13 VM"
  qm start $VMID
  msg_ok "Started Debian 13 VM"
fi

# Installer Cura sur la VM
install_cura

msg_ok "Completed Successfully!\n"
echo "More Info at https://github.com/community-scripts/ProxmoxVE/discussions/836"
