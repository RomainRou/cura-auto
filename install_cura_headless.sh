#!/usr/bin/env bash
# Script Proxmox VE pour installer une VM Debian 12 pour Cura

set -e

# Fonction pour afficher le header
function header_info {
  clear
  echo "==============================="
  echo "   Installer Cura sur Proxmox   "
  echo "==============================="
}

header_info

# Vérification des droits root
if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERREUR] Ce script doit être exécuté en root"
  exit 1
fi

# Détecter le prochain VMID disponible
NEXTID=$(pvesh get /cluster/nextid)
echo "[INFO] Prochain VMID disponible : $NEXTID"

# Menu whiptail pour les paramètres
VMID=$(whiptail --inputbox "Entrez le VMID" 8 50 "$NEXTID" --title "VMID" 3>&1 1>&2 2>&3)
HN=$(whiptail --inputbox "Nom de la VM" 8 50 "cura" --title "Hostname" 3>&1 1>&2 2>&3)
RAM=$(whiptail --inputbox "Mémoire RAM (Mo)" 8 50 "4096" --title "RAM" 3>&1 1>&2 2>&3)
CPU=$(whiptail --inputbox "Nombre de cores CPU" 8 50 "2" --title "CPU" 3>&1 1>&2 2>&3)
BRG=$(whiptail --inputbox "Bridge réseau" 8 50 "vmbr0" --title "Bridge" 3>&1 1>&2 2>&3)

# Menu de sélection du stockage
STORAGE=$(whiptail --radiolist "Choisir le stockage pour la VM" 16 60 6 \
$(pvesm status -content images | awk 'NR>1 {print $1 " " $2 " " "OFF"}') 3>&1 1>&2 2>&3)

if [[ -z "$STORAGE" ]]; then
  echo "[ERREUR] Aucun stockage sélectionné"
  exit 1
fi
echo "[INFO] Stockage choisi : $STORAGE"

# Génération d'une MAC aléatoire
MAC=02:$(openssl rand -hex 5 | sed 's/\(..\)/\1:/g; s/:$//')

# Télécharger l'image Debian 12 cloud
URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
FILE=$(basename $URL)
echo "[INFO] Téléchargement de l'image Debian 12..."
wget -q --show-progress $URL

# Détecter le type de stockage pour choisir le format
ST_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
if [[ "$ST_TYPE" == "lvmthin" ]]; then
  DISK_FORMAT="raw"
else
  DISK_FORMAT="qcow2"
fi
echo "[INFO] Format disque utilisé : $DISK_FORMAT"

# Créer la VM
qm create $VMID -name $HN -memory $RAM -cores $CPU -net0 virtio,bridge=$BRG,macaddr=$MAC -ostype l26 -scsihw virtio-scsi-pci

# Allouer le disque et importer l'image
pvesm alloc $STORAGE $VMID vm-${VMID}-disk-0 20G 1>/dev/null
qm importdisk $VMID $FILE $STORAGE -format $DISK_FORMAT

# Configurer la VM pour boot EFI
qm set $VMID -scsi0 ${STORAGE}:vm-${VMID}-disk-0 -boot order=scsi0 -efidisk0 ${STORAGE}:vm-${VMID}-disk-0,format=raw
qm set $VMID -serial0 socket -vga qxl

# Optionnel : démarrer la VM
if whiptail --yesno "Démarrer la VM maintenant ?" 8 40; then
  qm start $VMID
  echo "[INFO] VM démarrée"
else
  echo "[INFO] VM créée mais non démarrée"
fi

echo "[INFO] Installation terminée ! VMID=$VMID, Nom=$HN"
