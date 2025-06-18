#!/bin/bash
# 06-dev-tools.sh - Installs development tools if selected by the user.

log() { echo -e "${BLUE}[DEV]${NC} $1"; }

log "Installing development tools..."

dev_pacman=(
    "neovim" "vim" "kate" "git" "git-delta" "docker" "docker-compose"
    "python" "python-pip" "nodejs" "npm" "rustup"
)
log "Installing packages from official repositories..."
sudo pacman -S --noconfirm --needed "${dev_pacman[@]}"

dev_aur=(
    "visual-studio-code-bin" "lazygit" "hyperfine" "procs" "duf" "dust" "tealdeer"
)
log "Installing packages from the AUR..."
su - "$USER" -c "yay -S --noconfirm --needed ${dev_aur[*]}"

log "Configuring development tools..."
sudo usermod -aG docker "$USER"
sudo systemctl enable docker.service
su - "$USER" -c "rustup default stable"

log "Development tools setup complete. Please log out and log back in for docker group changes to take effect."
