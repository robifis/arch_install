#!/bin/bash
# 04-gpu-driver.sh - Installs GPU drivers based on user selection.

log() { echo -e "${BLUE}[GPU]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

log "Setting up GPU drivers for: $GPU_SETUP"

case $GPU_SETUP in
    "intel")
        log "Installing Intel GPU drivers..."
        sudo pacman -S --noconfirm --needed "intel-media-driver" "libva-intel-driver" "vulkan-intel"
        ;;
    "amd")
        log "Installing AMD GPU drivers from your list..."
        sudo pacman -S --noconfirm --needed "vulkan-radeon" "libva-mesa-driver" "mesa-vdpau" "radeontop" "rocm-opencl-runtime"
        ;;
    "nvidia")
        log "Installing NVIDIA GPU drivers..."
        sudo pacman -S --noconfirm --needed "nvidia" "nvidia-settings" "egl-wayland" "opencl-nvidia"
        
        log "Configuring NVIDIA kernel parameters for Wayland..."
        echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf
        echo "GBM_BACKEND=nvidia-drm" | sudo tee -a /etc/environment
        echo "__GLX_VENDOR_LIBRARY_NAME=nvidia" | sudo tee -a /etc/environment
        log "NVIDIA setup requires rebuilding the initramfs. This may take a moment..."
        sudo mkinitcpio -P
        ;;
    "hybrid")
        log "Installing hybrid Intel/NVIDIA drivers (optimus-manager)..."
        sudo pacman -S --noconfirm --needed "intel-media-driver" "nvidia" "nvidia-prime"
        su - "$USER" -c "yay -S --noconfirm --needed optimus-manager"
        log "Enabling optimus-manager service..."
        sudo systemctl enable optimus-manager
        ;;
    *)
        error "Unknown GPU_SETUP value: $GPU_SETUP"
        ;;
esac

log "GPU driver setup complete."
