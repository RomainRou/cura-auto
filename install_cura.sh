#!/bin/bash
USER="cura"

apt update && apt upgrade -y
apt install -y xorg openbox xinit xserver-xorg-video-fbdev wget \
    libglu1-mesa libxi6 libxrender1 libxrandr2 libxinerama1

# Cura AppImage
sudo -u $USER wget -O /home/$USER/Cura.AppImage https://download.ultimaker.com/software/Ultimaker_Cura-5.x.x.AppImage
sudo -u $USER chmod +x /home/$USER/Cura.AppImage

# Lancement automatique
echo '#!/bin/bash
/home/cura/Cura.AppImage' > /home/cura/.xinitrc
chmod +x /home/cura/.xinitrc
chown cura:cura /home/cura/.xinitrc

# Autologin sur TTY1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOT > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOT

systemctl daemon-reexec

# Auto-start X
echo 'if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    startx
fi' >> /home/cura/.bash_profile
chown cura:cura /home/cura/.bash_profile

# Nettoyage
systemctl disable apache2 bluetooth cups

echo "✅ Installation terminée – Cura démarrera automatiquement au prochain boot."
