#!/bin/bash
# 98-dotfiles.sh - Deploys dotfiles or creates default configs.

log() { echo -e "${BLUE}[DOTFILES]${NC} $1"; }

if [ "$DEPLOY_DOTFILES" -eq 0 ]; then
    log "Deploying dotfiles from github.com/robifis/universal_dotfiles..."
    sudo pacman -S --noconfirm --needed "stow" "git"
    
    # Run git/stow as the user for correct permissions
    su - "$USER" -c "git clone https://github.com/robifis/universal_dotfiles.git ~/.dotfiles && cd ~/.dotfiles && stow ."
    
    log "Dotfiles deployed successfully."
else
    log "Skipping remote dotfile deployment. Creating default config directories..."
    mkdir -p ~/{.config,Documents,Downloads,Music,Pictures,Videos}
    mkdir -p ~/.config/{hypr,waybar,wofi,kitty,alacritty,neovim,fish}
    log "Default directories created."
fi
