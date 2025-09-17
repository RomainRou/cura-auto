#!/bin/bash
set -e

# Mise à jour et installation des dépendances
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

echo "[+] Cura installé. Il se lancera automatiquement au prochain démarrage."
