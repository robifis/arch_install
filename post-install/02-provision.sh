#!/bin/bash
# 02-provision.sh - Master script to provision the new system after first boot.
# This script is run by the user.

# --- Strict Mode & Safety ---
set -euo pipefail

# --- Get Script Directory ---
# This allows the script to find all the other modular scripts.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# --- Color & Style Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Logging Function ---
log() {
    echo -e "${BLUE}[PROVISION]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# --- Main Provisioning Logic ---
main() {
    # 1. Prepare Environment (update system, check network, etc.)
    prepare_environment

    # 2. Ask User for Choices via TUI
    gather_user_choices

    # 3. Execute Installation Stages based on choices
    run_installation_modules

    log "${GREEN}System provisioning complete!${NC}"
    dialog --title "Setup Complete" --msgbox "All selected software and configurations have been installed.\n\nIt is highly recommended to reboot now for all changes to take effect." 10 60
}

# --- FUNCTION DEFINITIONS ---

prepare_environment() {
    log "Starting post-reboot provisioning..."
    
    # Ensure dialog is available
    sudo pacman -S --noconfirm --needed dialog
    
    # Cache sudo password at the beginning to avoid repeated prompts
    log "Requesting sudo privileges for the duration of the script..."
    sudo -v
    # Keep-alive: update existing sudo time stamp regularly.
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    # Wait for a stable network connection before proceeding
    log "Checking for network connection..."
    while ! ping -c 1 -W 1 archlinux.org &>/dev/null; do
        log "${YELLOW}Waiting for network connection...${NC}"
        sleep 2
    done
    log "${GREEN}Network connection established.${NC}"

    # Update package databases and keyring first to prevent signature errors
    log "Synchronizing package databases and updating archlinux-keyring..."
    sudo pacman -Syu --noconfirm --needed archlinux-keyring || error "Failed to update keyring."
    sudo pacman -Syu --noconfirm || error "Failed to perform initial system update."
}

gather_user_choices() {
    log "Gathering user choices for software installation..."
    
    # Use global variables to store the choices for other scripts to use
    declare -gA PACKAGE_CHOICES
    declare -g DEPLOY_DOTFILES
    declare -g INSTALL_HELPERS

    # Use dialog to present a checklist of software bundles
    # The output is a quoted string, e.g., "CoreDesktop" "Utilities"
    local selections
    selections=$(dialog --title "Software Selection" --checklist "Select the software bundles you wish to install.\nUse SPACE to toggle, ENTER to confirm." 20 80 7 \
        "CoreDesktop" "Base Hyprland desktop experience" ON \
        "Utilities" "Essential terminals, file managers, tools" ON \
        "DevSuite" "Full suite for software development" OFF \
        "Admin" "System backup, filesharing, remote access" OFF \
        "Media" "OBS Studio, media players, etc." OFF \
        "Web" "Google Chrome, remote desktop clients" OFF 2>&1 >/dev/tty)
    
    [[ $? -ne 0 ]] && error "Installation cancelled by user."

    # Populate the associative array based on selections for easy lookup
    for selection in $selections; do
        # Remove quotes from dialog's output
        PACKAGE_CHOICES[${selection//\"/}]="yes"
    done

    # Ask about dotfile configuration
    dialog --title "Dotfile Configuration" --yesno "Do you want to download and deploy the recommended dotfiles from 'github.com/robifis/universal_dotfiles'?\n\n- YES: Clones the repo and links the configs.\n- NO: Creates basic default configuration files." 12 70
    DEPLOY_DOTFILES=$? # 0 for Yes, 1 for No

    # Ask about maintenance scripts
    dialog --title "Maintenance Scripts" --yesno "Do you want to install optional helper scripts for system maintenance (e.g., snapshot management, mirror updates)?" 10 70
    INSTALL_HELPERS=$? # 0 for Yes, 1 for No
}

run_installation_modules() {
    log "Executing selected installation modules..."

    # Source the mandatory base system and GPU driver scripts first
    # These contain packages needed by almost everything else.
    source "$SCRIPT_DIR/03-base-system.sh"
    source "$SCRIPT_DIR/04-gpu-driver.sh"
    
    # Conditionally source the optional scripts based on user choices
    [[ ${PACKAGE_CHOICES[CoreDesktop]} ]] && source "$SCRIPT_DIR/05-desktop-env.sh"
    [[ ${PACKAGE_CHOICES[DevSuite]} ]] && source "$SCRIPT_DIR/06-dev-tools.sh"
    [[ ${PACKAGE_CHOICES[Media]} ]] && source "$SCRIPT_DIR/07-media-tools.sh"
    [[ ${PACKAGE_CHOICES[Admin]} ]] && source "$SCRIPT_DIR/08-admin-tools.sh"
    [[ ${PACKAGE_CHOICES[Web]} ]] && source "$SCRIPT_DIR/09-web-tools.sh"
    # The "Utilities" and "CLITools" from the checklist can be merged into 03-base-system.sh or have their own script.

    # Handle dotfile deployment based on the choice
    # We create a dedicated script for this complex logic
    source "$SCRIPT_DIR/98-dotfiles.sh"

    # Handle maintenance script installation
    if [ "$INSTALL_HELPERS" -eq 0 ]; then
        source "$SCRIPT_DIR/99-maintenance.sh"
    else
        log "Skipping installation of maintenance scripts."
    fi
}


# --- Run the Main Function ---
# Load user choices from the initial installation to inform this script.
if [ -f "$SCRIPT_DIR/install-config.sh" ]; then
    source "$SCRIPT_DIR/install-config.sh"
else
    error "Could not find 'install-config.sh'. Make sure you are running this script from the 'arch-setup' directory."
fi

main
