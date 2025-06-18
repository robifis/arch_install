#!/bin/bash
# 03-base-system.sh - Installs essential base system packages and AUR helper.

log() { echo -e "${BLUE}[BASE]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

log "Starting base system setup..."

# --- Package Installation ---
# Define an array of essential packages that should always be installed.
# These are drawn from your provided list.
essential_packages=(
    # System utilities from your list
    "btop" "htop" "fastfetch" "tree" "unzip" "unarchiver"
    "rsync" "wget" "curl" "git" "openssh"

    # Audio (PipeWire)
    "pipewire" "pipewire-pulse" "pipewire-alsa" "pipewire-jack"
    "wireplumber" "pavucontrol"

    # Base fonts (Nerd Fonts are a good base for icons)
    "ttf-jetbrains-mono-nerd" "nerd-fonts-sf-mono-ligatures"

    # File management essentials
    "thunar" "ffmpegthumbnailer"
    "gvfs" "gvfs-smb" # For network file shares

    # Hardware acceleration base
    "mesa"

    # Wayland essentials
    "wayland" "wayland-protocols" "xorg-xwayland" "xorg-xhost"

    # Notification daemon
    "mako"

    # Terminal emulators
    "alacritty" "kitty"

    # Brightness and clipboard
    "brightnessctl" "wl-clipboard" "cliphist"
    
    # Modern CLI Tools (from your list)
    "bat" "eza" "fd" "fzf" "ripgrep" "zoxide" "starship" "atuin"
)

log "Installing essential system packages..."
sudo pacman -S --noconfirm --needed "${essential_packages[@]}" || error "Failed to install essential packages."

# --- AUR Helper Installation ---
if ! command -v yay &> /dev/null; then
    log "Installing 'yay' AUR helper..."
    # We need base-devel and git to build packages, ensure they are here
    sudo pacman -S --noconfirm --needed "base-devel" "git"
    
    # Standard process to build and install yay from AUR as the user
    su - "$USER" -c 'cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd ~ && rm -rf /tmp/yay'
    log "'yay' has been installed."
else
    log "'yay' is already installed."
fi

# --- Enable Essential Services ---
log "Enabling essential system services..."
# Enable PipeWire for the current user
systemctl --user enable --now pipewire pipewire-pulse wireplumber

log "Base system setup complete."
