#!/bin/bash
# 07-admin-tools.sh - Installs system administration and backup tools.
log() { echo -e "${BLUE}[ADMIN]${NC} $1"; }
log "Installing System Administration & Backup tools..."
sudo pacman -S --noconfirm --needed "timeshift" "snapper" "snap-pac" "samba" "syncthing" "tailscale"
su - "$USER" -c 'yay -S --noconfirm --needed grub-btrfs'
systemctl --user enable --now syncthing.service
sudo systemctl enable --now tailscaled.service
# ... (snapper config logic from previous response) ...
log "Admin tools setup complete."
