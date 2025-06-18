#!/bin/bash
# 00-installer.sh - TUI-driven Arch Linux Installer
# The master script to be run from the Arch ISO.

# --- Strict Mode & Safety ---
# Exit immediately if a command exits with a non-zero status, a pipeline fails, or an unset variable is used.
set -euo pipefail

# --- Color & Style Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Logging Functions ---
# Logs will be visible on the underlying terminal (tty1) while dialog runs.
log() {
    echo -e "${BLUE}[INFO]${NC} $1" >/dev/tty1
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >/dev/tty1
    # Display error in a dialog box as well for user visibility
    dialog --title "Error" --msgbox "An error occurred:\n\n$1\n\nSee the console for details. Aborting." 8 70
    exit 1
}

# --- Initial System Checks ---
check_system() {
    log "Performing initial system checks..."
    [[ $EUID -ne 0 ]] && error "This script must be run as root."
    [[ ! -d /sys/firmware/efi/efivars ]] && error "System is not booted in UEFI mode. This script requires a UEFI environment."
    pacman -S --noconfirm --needed dialog || error "Failed to install 'dialog'. Check network connection."
    timedatectl set-ntp true || log "${YELLOW}Warning: Failed to set NTP. Time may be incorrect.${NC}"
}

# --- Variable Declarations ---
# All user choices will be stored in these global variables.
KEYMAP=""
TIMEZONE=""
DISK=""
FS_CHOICE=""
BOOTLOADER_CHOICE=""
CREATE_SWAP=0 # 0=Yes, 1=No
RECOMMENDED_SWAP=0
USERNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""
EFI_PART=""
ROOT_PART=""

# --- Main TUI Flow ---
gather_user_input() {
    # Helper function for consistent dialog calls
    run_dialog() { dialog "$@" 2>&1 >/dev/tty; }

    # Welcome Message
    run_dialog --title "Welcome" --msgbox "Welcome to the Arch Linux Installer!\n\nThis script will guide you through setting up your system with a user-friendly interface.\n\nUse ARROW keys to navigate, SPACE to select, and ENTER to confirm." 12 70

    # Keyboard Layout
    KEYMAP=$(run_dialog --title "Keyboard Layout" --inputbox "Enter your keyboard layout. For most users, the default is fine.\n\nExamples: 'us' (for USA/UK), 'de-latin1', 'fr'" 10 70 "us")
    [[ $? -ne 0 ]] && error "Installation cancelled by user." && exit
    loadkeys "$KEYMAP"

    # --- NEW, IMPROVED TIMEZONE SELECTION ---

    while true; do
    # First, let the user pick a major region.
    TIMEZONE_REGION=$(run_dialog --title "Timezone Selection" --menu "Select your world region." 15 70 5 "Europe" "" "America" "" "Asia" "" "Australia" "" "Etc" "")
    if [[ $? -ne 0 ]]; then error "Installation cancelled by user."; fi

    # Second, generate a list of specific zones within that region.
    # We add a check to ensure this list is not empty.
    ZONE_OPTIONS=$(timedatectl list-timezones | grep "^$TIMEZONE_REGION/" | sed "s#$TIMEZONE_REGION/##" | awk '{print $1 " \"\""}' | tr '\n' ' ')

    if [[ -z "$ZONE_OPTIONS" ]]; then
        # If the list is empty, the region is invalid for this method. Show an error and loop again.
        run_dialog --title "Error" --msgbox "The selected region '$TIMEZONE_REGION' has no sub-zones to choose from.\n\nPlease select another region." 10 70
        continue # Go back to the beginning of the while loop
    fi

    # If the list is valid, show the second menu to select the city/area.
    SUB_TIMEZONE=$(run_dialog --title "City/Area Selection" --menu "Select your city or area." 20 70 15 $(echo "$ZONE_OPTIONS"))
    if [[ $? -ne 0 ]]; then error "Installation cancelled by user."; fi

    # If we have a sub-zone, construct the full timezone, log it, and break the loop.
    if [[ -n "$SUB_TIMEZONE" ]]; then
        TIMEZONE="$TIMEZONE_REGION/$SUB_TIMEZONE"
        log "Timezone set to '$TIMEZONE'."
        break
    else
        # This case handles if the user presses OK on an empty selection in the second menu.
        run_dialog --title "Error" --msgbox "You did not select a valid zone. Please try again." 8 50
    fi
    done
    
    # --- NEW, IMPROVED DISK SELECTION ---

# Create an array to hold the menu entries for the dialog command
declare -a DISK_ENTRIES=()

# Read the output of lsblk line by line
while read -r line; do
    # Each line is expected to be like: /dev/sda 100G SomeModel
    # We use 'read' to safely split the line into variables.
    read -r -a device_info <<< "$line"
    local device_name="${device_info[0]}"
    local device_size="${device_info[1]}"
    # The rest of the line is the model; handles cases where model is empty or has spaces.
    local device_model="${device_info[@]:2}"

    # Add the formatted entry to our array
    DISK_ENTRIES+=("$device_name" "$device_size $device_model")
done < <(lsblk -dpno NAME,SIZE,MODEL | grep 'disk')

# Check if we actually found any disks before trying to show the menu
if [ ${#DISK_ENTRIES[@]} -eq 0 ]; then
    run_dialog --title "Error" --msgbox "No suitable disks found for installation.\n\nPlease check your hardware or virtual machine configuration." 10 60
    error "Could not detect any block devices to install to."
fi

DISK=$(run_dialog --title "Disk Selection" --menu "Select the disk to install Arch Linux on.\nWARNING: THIS DISK WILL BE COMPLETELY WIPED." 20 70 15 "${DISK_ENTRIES[@]}")

# Exit if user hits 'Cancel' or 'Esc'
if [[ $? -ne 0 ]]; then
    error "Installation cancelled by user."
fi

log "Installation target disk set to '$DISK'."
    # Bootloader Choice
    BOOTLOADER_CHOICE=$(run_dialog --title "Bootloader Choice" --radiolist "Select a bootloader." 15 70 2 "systemd-boot" "Simple, fast, and clean (for single-OS setups)" ON "grub" "Feature-rich (for multi-boot & snapshot booting)" OFF)
    [[ $? -ne 0 ]] && error "Installation cancelled by user." && exit
    case $BOOTLOADER_CHOICE in
        systemd-boot) run_dialog --title "Explainer: systemd-boot" --msgbox "You chose 'systemd-boot'.\n\nA minimal and extremely fast boot manager. It is perfect if Arch Linux will be the only operating system on this machine." 11 70 ;;
        grub) run_dialog --title "Explainer: GRUB" --msgbox "You chose 'GRUB'.\n\nA powerful bootloader that can handle complex dual-booting with Windows. It is required if you want to boot into BTRFS snapshots from the boot menu." 11 70 ;;
    esac

    # Swap File
    local TOTAL_MEM_GIB
    TOTAL_MEM_GIB=$(free -g | awk '/^Mem:/ {print $2}')
    RECOMMENDED_SWAP=$((TOTAL_MEM_GIB))
    run_dialog --title "Swap File" --yesno "Your system has ${TOTAL_MEM_GIB}GiB of RAM.\n\nA swap file acts as overflow memory and is required for hibernation. It's recommended to create a swap file equal to your RAM size (${RECOMMENDED_SWAP}GiB).\n\nDo you want to create a swap file?" 12 70
    CREATE_SWAP=$?

    # User Account
    while true; do
        USERNAME=$(run_dialog --title "User Creation" --inputbox "Enter your desired username (lowercase, no spaces)." 10 70)
        if [[ $? -ne 0 ]]; then error "Installation cancelled."; fi
        if [[ -z "$USERNAME" ]]; then run_dialog --title "Error" --msgbox "Username cannot be empty." 8 40; else break; fi
    done
    while true; do
        USER_PASSWORD=$(run_dialog --title "User Password" --passwordbox "Enter a password for user '$USERNAME'." 10 70)
        if [[ $? -ne 0 ]]; then error "Installation cancelled."; fi
        local USER_PASSWORD_CONFIRM
        USER_PASSWORD_CONFIRM=$(run_dialog --title "Confirm Password" --passwordbox "Confirm the password." 10 70)
        if [[ $? -ne 0 ]]; then error "Installation cancelled."; fi
        if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]]; then break; else run_dialog --title "Error" --msgbox "Passwords do not match." 8 40; fi
    done
    
    # Root Password
    while true; do
        ROOT_PASSWORD=$(run_dialog --title "Root Password" --passwordbox "Enter the root (administrator) password." 10 70)
        if [[ $? -ne 0 ]]; then error "Installation cancelled."; fi
        local ROOT_PASSWORD_CONFIRM
        ROOT_PASSWORD_CONFIRM=$(run_dialog --title "Confirm Root Password" --passwordbox "Confirm the root password." 10 70)
        if [[ $? -ne 0 ]]; then error "Installation cancelled."; fi
        if [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]]; then break; else run_dialog --title "Error" --msgbox "Passwords do not match." 8 40; fi
    done

    # Final Confirmation
    local SUMMARY="Your Arch Linux installation is ready to begin with the following settings:\n\n\
    Disk:            $DISK\n\
    Filesystem:      $FS_CHOICE\n\
    Bootloader:      $BOOTLOADER_CHOICE\n\
    Create Swap:     $(if [ $CREATE_SWAP -eq 0 ]; then echo 'Yes'; else echo 'No'; fi)\n\
    Username:        $USERNAME\n\
    Timezone:        $TIMEZONE\n\n\
    WARNING: The disk $DISK will be completely erased. This is your final chance to cancel."
    run_dialog --title "Confirm Installation" --yesno "$SUMMARY" 20 70
    [[ $? -ne 0 ]] && error "Installation cancelled by user." && exit
}

# --- Execution Engine ---
partition_and_format() {
    log "Wiping disk and creating new partitions on $DISK..."
    umount -A --recursive /mnt 2>/dev/null || true
    wipefs -af "$DISK"
    sgdisk -Zo "$DISK"

    log "Creating EFI (1GiB) and Root partitions..."
    parted -s "$DISK" mklabel gpt \
        mkpart "EFI" fat32 1MiB 1025MiB set 1 esp on \
        mkpart "ROOT" "${FS_CHOICE}" 1025MiB 100%

    if [[ "$DISK" =~ "nvme" ]]; then EFI_PART="${DISK}p1" && ROOT_PART="${DISK}p2"; else EFI_PART="${DISK}1" && ROOT_PART="${DISK}2"; fi

    log "Formatting partitions (EFI: FAT32, ROOT: ${FS_CHOICE})..."
    mkfs.fat -F32 "$EFI_PART"
    case "$FS_CHOICE" in
        btrfs) mkfs.btrfs -f -L "ARCH_ROOT" "$ROOT_PART" ;;
        ext4) mkfs.ext4 -F -L "ARCH_ROOT" "$ROOT_PART" ;;
    esac
}

mount_filesystems() {
    log "Mounting filesystems..."
    case "$FS_CHOICE" in
        btrfs)
            mount -t btrfs "$ROOT_PART" /mnt
            btrfs subvolume create /mnt/@
            btrfs subvolume create /mnt/@home
            btrfs subvolume create /mnt/@var
            btrfs subvolume create /mnt/@.snapshots
            btrfs subvolume create /mnt/@swap # For swapfile
            umount /mnt
            mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "$ROOT_PART" /mnt
            mkdir -p /mnt/{home,var,.snapshots,boot,swap}
            mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "$ROOT_PART" /mnt/home
            mount -o noatime,compress=zstd,space_cache=v2,subvol=@var "$ROOT_PART" /mnt/var
            mount -o noatime,compress=zstd,space_cache=v2,subvol=@.snapshots "$ROOT_PART" /mnt/.snapshots
            mount -o noatime,subvol=@swap "$ROOT_PART" /mnt/swap
            ;;
        ext4)
            mount -t ext4 "$ROOT_PART" /mnt
            mkdir -p /mnt/{boot,home}
            ;;
    esac
    mount "$EFI_PART" /mnt/boot
}

create_swapfile() {
    if [ "$CREATE_SWAP" -eq 0 ]; then
        log "Creating ${RECOMMENDED_SWAP}GiB swap file..."
        local SWAP_PATH="/mnt/swap/swapfile"
        # Disable Copy-on-Write for the swapfile on BTRFS
        [[ "$FS_CHOICE" == "btrfs" ]] && touch "$SWAP_PATH" && chattr +C "$SWAP_PATH"
        dd if=/dev/zero of="$SWAP_PATH" bs=1G count="$RECOMMENDED_SWAP" status=progress
        chmod 600 "$SWAP_PATH"
        mkswap "$SWAP_PATH"
        swapon "$SWAP_PATH"
        log "Swap file created and enabled."
    fi
}

install_base_system() {
    log "Installing base system packages with pacstrap..."
    local packages=(base base-devel linux linux-firmware)
    [[ "$FS_CHOICE" == "btrfs" ]] && packages+=(btrfs-progs)
    [[ "$BOOTLOADER_CHOICE" == "grub" ]] && packages+=(grub efibootmgr)
    pacstrap -K /mnt "${packages[@]}"
    genfstab -U /mnt >> /mnt/etc/fstab
}

prepare_and_enter_chroot() {
    log "Preparing chroot environment..."
    # This file passes all our choices into the chroot
    cat > /mnt/root/install-config.sh <<EOF
USERNAME="$USERNAME"
USER_PASSWORD="$USER_PASSWORD"
ROOT_PASSWORD="$ROOT_PASSWORD"
HOSTNAME="$HOSTNAME"
TIMEZONE="$TIMEZONE"
LOCALE="en_GB.UTF-8"
KEYMAP="$KEYMAP"
BOOTLOADER_CHOICE="$BOOTLOADER_CHOICE"
FS_CHOICE="$FS_CHOICE"
ROOT_PART="$ROOT_PART"
EOF
    # Copy the entire script directory into the new system
    local SCRIPT_DIR
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    mkdir -p /mnt/root/arch-setup
    cp -r "$SCRIPT_DIR"/* /mnt/root/arch-setup/

    log "Entering chroot and running Stage 1 configuration..."
    arch-chroot /mnt /root/arch-setup/01-configure-chroot.sh
}

finish_installation() {
    log "Stage 0 and 1 complete. The system is now ready for the first boot."
    dialog --title "Installation Complete" --msgbox "The base system has been installed.\n\nThe system will now unmount filesystems and reboot in 10 seconds.\n\nAfter rebooting, log in as '$USERNAME' and run the provisioning script:\n\n'cd ~/arch-setup && ./02-provision.sh'" 15 70
    sleep 10
    umount -A --recursive /mnt
    reboot
}

# --- Main Program Flow ---
check_system
gather_user_input
partition_and_format
mount_filesystems
create_swapfile
install_base_system
prepare_and_enter_chroot
finish_installation
