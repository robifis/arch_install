#!/bin/bash
# 99-maintenance.sh - Installs the maintenance helper script.

log() { echo -e "${BLUE}[MAINTENANCE]${NC} $1"; }

log "Installing maintenance script to ~/.local/bin/maintenance..."

# Create the target directory
mkdir -p "$HOME/.local/bin"

# Use a HEREDOC to create the script file
cat > "$HOME/.local/bin/maintenance" << 'EOF'
#!/bin/bash
# A helper script for common system maintenance tasks.

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

update_system() {
    echo -e "${BLUE}=== Updating System ===${NC}"
    sudo pacman -Syu && yay -Sua
    echo -e "${GREEN}System update complete.${NC}"
}

clean_cache() {
    echo -e "${BLUE}=== Cleaning Package Caches ===${NC}"
    sudo paccache -rk2
    yay -Sc --noconfirm
    echo -e "${GREEN}Caches cleaned.${NC}"
}

update_mirrors() {
    echo -e "${BLUE}=== Updating Mirror List ===${NC}"
    sudo reflector --verbose --latest 20 --country "United Kingdom,Germany,France" --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    echo -e "${GREEN}Mirror list updated.${NC}"
}

show_menu() {
    clear
    echo -e "${GREEN}Arch Linux Maintenance Script${NC}"
    echo "-----------------------------"
    echo "1. Update System (pacman & yay)"
    echo "2. Clean Package Caches"
    echo "3. Update Mirror List"
    echo "q. Quit"
    echo "-----------------------------"
}

while true; do
    show_menu
    read -rp "Select an option: " choice
    case "$choice" in
        1) update_system ;;
        2) clean_cache ;;
        3) update_mirrors ;;
        q|Q) echo "Exiting."; exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}" && sleep 1 ;;
    esac
    read -rp "Press Enter to continue..."
done
EOF

# Make the script executable
chmod +x "$HOME/.local/bin/maintenance"

chown "$USER":"$USER" -R "$HOME/.local"

log "Maintenance script installed. You can run it by typing 'maintenance'."
