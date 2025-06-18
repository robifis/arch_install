#!/bin/bash
# 08-media-tools.sh - Installs media and content creation tools.
log() { echo -e "${BLUE}[MEDIA]${NC} $1"; }
log "Installing Media & Content Creation tools..."
sudo pacman -S --noconfirm --needed "obs-studio" "mpv"
su - "$USER" -c 'yay -S --noconfirm --needed obs-vaapi'
log "Media tools setup complete."
