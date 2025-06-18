#!/bin/bash
# 01-configure-chroot.sh - Runs inside the chroot to make the system bootable.
# This script is executed by 00-installer.sh

# --- Strict Mode & Safety ---
# Exit immediately if a command exits with a non-zero status.
# Exit immediately if a pipeline fails.
# Treat unset variables as an error.
set -euo pipefail

# --- Logging Functions ---
# Simple logging for this self-contained script
log() {
    echo -e "\033[0;32m[CHROOT]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
    exit 1
}

# --- Source Configuration ---
# Load all the variables set by the user in the TUI (e.g., USERNAME, HOSTNAME, etc.)
if [ -f /root/install-config.sh ]; then
    log "Loading user configuration..."
    source /root/install-config.sh
else
    error "Configuration file /root/install-config.sh not found. Cannot proceed."
fi

# --- Main Configuration Logic ---

main() {
    log "Starting Stage 1: System Configuration..."

    configure_system_time
    configure_localization
    configure_network
    create_users_and_passwords
    configure_bootloader
    enable_essential_services

    log "Chroot configuration complete. The system is now bootable."
    log "You can now exit the chroot environment."
}

# --- FUNCTION DEFINITIONS ---

configure_system_time() {
    log "Setting timezone to $TIMEZONE..."
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc # Set the hardware clock from the system time
}

configure_localization() {
    log "Configuring system locale to $LOCALE and keyboard layout to $KEYMAP..."
    # Generate the specified locale
    echo "$LOCALE UTF-8" > /etc/locale.gen
    locale-gen
    # Set the system language
    echo "LANG=$LOCALE" > /etc/locale.conf
    # Set the keyboard layout for the virtual console
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
}

configure_network() {
    log "Setting hostname to '$HOSTNAME'..."
    echo "$HOSTNAME" > /etc/hostname
    
    log "Configuring hosts file..."
    cat > /etc/hosts << HOSTS_EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS_EOF
}

create_users_and_passwords() {
    log "Setting root password..."
    echo "root:$ROOT_PASSWORD" | chpasswd

    log "Creating user '$USERNAME' and setting password..."
    # Create user with home directory (-m), add to 'wheel' group for sudo (-G), and set default shell
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chpasswd

    log "Granting sudo privileges to the 'wheel' group..."
    # This is the safe way to grant sudo rights: create a drop-in file.
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
}

configure_bootloader() {
    log "Installing and configuring bootloader: $BOOTLOADER_CHOICE..."
    # Detect CPU vendor to install the correct microcode
    local CPU_VENDOR
    CPU_VENDOR=$(grep "vendor_id" /proc/cpuinfo | head -n 1 | awk '{print $3}')
    
    case "$BOOTLOADER_CHOICE" in
        systemd-boot)
            bootctl install

            log "Creating systemd-boot entry..."
            local LOADER_ENTRY="/boot/loader/entries/arch.conf"
            local ROOT_UUID
            ROOT_UUID=$(blkid -s PARTUUID -o value "$ROOT_PART")

            echo "title   Arch Linux" > "$LOADER_ENTRY"
            echo "linux   /vmlinuz-linux" >> "$LOADER_ENTRY"
            
            # Dynamically add the correct microcode based on CPU vendor
            if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
                echo "initrd  /amd-ucode.img" >> "$LOADER_ENTRY"
            else
                echo "initrd  /intel-ucode.img" >> "$LOADER_ENTRY"
            fi
            
            echo "initrd  /initramfs-linux.img" >> "$LOADER_ENTRY"
            # Point to the root partition using its stable PARTUUID and specify the btrfs subvolume
            echo "options root=PARTUUID=$ROOT_UUID rootflags=subvol=@ rw" >> "$LOADER_ENTRY"
            ;;
        grub)
            log "Configuring GRUB for UEFI..."
            grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCH
            
            # If using BTRFS, enable grub-btrfs for snapshot booting
            if [[ "$FS_CHOICE" == "btrfs" ]]; then
                log "Enabling GRUB BTRFS integration..."
                sed -i 's/#GRUB_BTRFS_OVERRIDE_BOOT_OPTIONS/GRUB_BTRFS_OVERRIDE_BOOT_OPTIONS/' /etc/default/grub
            fi

            # Generate the final GRUB configuration
            grub-mkconfig -o /boot/grub/grub.cfg
            ;;
    esac
}

enable_essential_services() {
    log "Enabling NetworkManager to provide internet connection on first boot..."
    systemctl enable NetworkManager.service
}


# --- Run the Main Function ---
main
