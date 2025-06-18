#!/bin/bash
# 09-web-tools.sh - Installs web browsers and remote desktop clients.
log() { echo -e "${BLUE}[WEB]${NC} $1"; }
log "Installing Web & Communication tools..."
su - "$USER" -c 'yay -S --noconfirm --needed google-chrome anydesk-bin teamviewer'
sudo systemctl enable anydesk.service
log "Web tools setup complete."
