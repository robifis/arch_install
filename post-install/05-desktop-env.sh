#!/bin/bash
# 05-desktop-env.sh - Installs the Hyprland desktop environment.

log() { echo -e "${BLUE}[DESKTOP]${NC} $1"; }

log "Installing Hyprland desktop environment packages..."

desktop_packages=(
    "hyprland"
    "xdg-desktop-portal-hyprland"
    "qt5-wayland"
    "qt6-wayland"
    "polkit-gnome"
    "waybar"
    "wofi"
    "swww"
    "nwg-displays"
    "nwg-look"
    "pavucontrol"
)

sudo pacman -S --noconfirm --needed "${desktop_packages[@]}"

log "Desktop environment setup complete."
