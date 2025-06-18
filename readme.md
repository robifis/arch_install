# Modular Arch Linux Installer

A comprehensive, TUI-driven framework for performing a clean, automated, and highly customizable installation of Arch Linux with the Hyprland window manager. This project is designed to be robust, repeatable, and easy to understand, turning a complex manual installation into a simple, guided process.

-----

## ➤ Overview

This is not a single script, but a multi-stage installation framework designed with best practices in mind. It separates the installation into logical stages to ensure stability and predictability. The primary goal is to provide a professional-grade tool that takes you from a bare-metal machine to a fully configured, personalized desktop environment with minimal manual intervention.

## ✨ Features

  * **User-Friendly TUI:** A Terminal User Interface (TUI) built with `dialog` guides you through the entire setup process. No need to manually type complex commands.
  * **Dynamic & Informative:** The installer provides clear explanations for critical choices like filesystem (Btrfs vs. ext4), bootloader (GRUB vs. systemd-boot), and full disk encryption, empowering you to make informed decisions.
  * **Modular Architecture:** The installation is broken down into small, self-contained, and well-commented scripts, each with a single responsibility. This makes the process easy to understand, customize, and debug.
  * **Btrfs & Snapshot Ready:** First-class support for the Btrfs filesystem, including an automated subvolume layout for snapshots. When paired with GRUB and Snapper, this allows for easy system rollbacks.
  * **Dynamic Package Selection:** After the base system is installed, a TUI checklist allows you to select which software bundles you want (Desktop Environment, Development Tools, Media, etc.).
  * **Automated Dotfile Deployment:** Optionally clone a dotfile repository from GitHub and automatically deploy it using `stow`.
  * **Post-Installation Helpers:** Optionally install a maintenance script to help with common tasks like system updates, cache cleaning, and mirror list optimization.

## ⚠️ Disclaimer & Warning

This framework is designed to perform a complete installation of Arch Linux. The process is **destructive** and will **completely wipe all data** on the disk you select.

  * **Backup your data:** Ensure you have a complete backup of any important data before proceeding.
  * **Use at your own risk:** While thoroughly designed, this is a powerful tool. I am not responsible for any data loss or system issues.
  * **Test in a VM:** It is **highly recommended** that you run this installer in a virtual machine (like QEMU/KVM or VirtualBox) for the first time to ensure it works as you expect before running it on physical hardware.

## 🚀 How to Use

### Prerequisites

1.  A computer with a 64-bit processor, booted in **UEFI mode**.
2.  The latest **Arch Linux ISO** image.
3.  A **USB drive** to write the ISO to.
4.  An active **internet connection** on the target machine (Ethernet is easiest, but Wi-Fi is supported via `iwctl`).

### Step 1: Preparation

1.  Create a bootable Arch Linux USB drive using a tool like `dd`, Rufus, or Balena Etcher.
2.  Clone this repository into a folder named `arch-setup` on the same USB drive.
    ```bash
    # On your current machine, with the USB mounted
    git clone https://github.com/robifis/universal_dotfiles.git /path/to/usb/arch-setup
    ```

### Step 2: Running the Installer (From the Arch ISO)

1.  Boot your target machine from the prepared USB drive.
2.  Once you reach the command prompt, connect to the internet.
      * For Ethernet, this is usually automatic.
      * For Wi-Fi, run `iwctl`, then `station list`, `station <device> connect <SSID>`, etc.
      * Verify your connection with `ping archlinux.org`.
3.  Mount your USB drive to access the scripts.
    ```bash
    # Find your USB drive with `lsblk` (e.g., /dev/sdb1)
    mkdir -p /mnt/usb
    mount /dev/sdX1 /mnt/usb 
    ```
4.  Navigate to the script directory and run the master installer.
    ```bash
    cd /mnt/usb/arch-setup
    ./00-installer.sh
    ```
5.  Follow the on-screen TUI menus to configure your installation. After you give final confirmation, the automated process will begin. The machine will reboot automatically when complete.

### Step 3: Post-Reboot Provisioning

1.  After the reboot, your machine will boot into a minimal, command-line Arch Linux system.
2.  Log in as the user you created in the TUI.
3.  The `arch-setup` directory will be in your home folder. Navigate to it and run the provisioner script.
    ```bash
    cd ~/arch-setup
    ./02-provision.sh
    ```
4.  A new TUI will appear. Select the software bundles you want to install and choose whether to deploy dotfiles.
5.  The script will proceed to install all your selected software, drivers, and configurations. This is the longest part of the process.
6.  When it finishes, it will prompt you to reboot one last time.

After the final reboot, you will be greeted by your fully configured Hyprland desktop. **Welcome to your new system\!**

-----

## 🔧 The Framework Explained

This project is composed of several scripts, each with a specific role.

  * **`00-installer.sh` (Stage 0 - ISO Runner):** The master script. It provides the TUI for gathering all user choices, then automatically partitions and formats the disk, installs the base system (`pacstrap`), and hands off control to the chroot stage.

  * **`01-configure-chroot.sh` (Stage 1 - Chroot Configurator):** Runs automatically inside the `chroot`. Its only job is to make the system bootable by setting the timezone, locale, hostname, user passwords, and bootloader.

  * **`02-provision.sh` (Stage 2 - Post-Reboot Orchestrator):** The user runs this script after the first login. It provides a TUI for selecting software bundles and then calls all the subsequent modular scripts in the correct order.

  * **`03-base-system.sh` to `09-web-tools.sh` (Modular Installers):** These are the workhorses. Each script is responsible for installing a specific category of software (e.g., GPU drivers, developer tools).

  * **`98-dotfiles.sh`:** Handles the logic for either deploying dotfiles from a Git repository or creating default configuration directories.

  * **`99-maintenance.sh`:** An optional helper script that gets installed to provide easy access to common system maintenance tasks.

## 🛠️ Customization

This framework is designed to be easily customized.

  * **Change Software:** To change the software that gets installed, simply edit the `packages` arrays inside the modular scripts (e.g., `06-dev-tools.sh`). You can add or remove packages from the `pacman` or `yay` lists.
  * **Change Dotfiles:** To use your own dotfiles, simply change the GitHub repository URL inside the `98-dotfiles.sh` script. Ensure your repository is structured for use with `stow`.
  * **Add/Remove Modules:** To add a new software category, create a new script (e.g., `10-science-tools.sh`), add it to the checklist in `02-provision.sh`, and add a line to call it.
