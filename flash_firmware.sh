#!/bin/bash
# Simple ZMK Firmware Flashing Script for Sofle V2
# This script helps automate the flashing process

set -e

echo "=========================================="
echo "🔧 Sofle V2 ZMK Firmware Flasher"
echo "=========================================="
echo

# Function to find keyboard drive
find_keyboard_drive() {
    local drives=()
    
    # Check different mount points based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        for drive in /Volumes/*; do
            if [[ -f "$drive/INFO_UF2.TXT" ]]; then
                drives+=("$drive")
            fi
        done
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        for mount_point in /media /mnt /run/media; do
            if [[ -d "$mount_point" ]]; then
                for user_dir in "$mount_point"/*; do
                    if [[ -d "$user_dir" ]]; then
                        for drive in "$user_dir"/*; do
                            if [[ -f "$drive/INFO_UF2.TXT" ]]; then
                                drives+=("$drive")
                            fi
                        done
                    fi
                done
            fi
        done
        # Also check direct mount points
        for drive in /mnt/*; do
            if [[ -f "$drive/INFO_UF2.TXT" ]]; then
                drives+=("$drive")
            fi
        done
    fi
    
    echo "${drives[@]}"
}

# Function to wait for keyboard
wait_for_keyboard() {
    echo "🔍 Waiting for keyboard in bootloader mode..."
    echo "💡 Press the BOOT button twice quickly on your keyboard"
    echo
    
    for i in {1..30}; do
        drives=($(find_keyboard_drive))
        if [[ ${#drives[@]} -gt 0 ]]; then
            echo "🎯 Found keyboard drive: ${drives[0]}"
            echo "${drives[0]}"
            return 0
        fi
        echo -ne "⏳ Searching... ($i/30)\r"
        sleep 1
    done
    
    echo
    echo "❌ Timeout: Could not find keyboard in bootloader mode"
    return 1
}

# Function to flash firmware
flash_firmware() {
    local firmware_file="$1"
    local drive_path="$2"
    
    if [[ ! -f "$firmware_file" ]]; then
        echo "❌ Firmware file not found: $firmware_file"
        return 1
    fi
    
    echo "📁 Copying $(basename "$firmware_file") to $drive_path"
    cp "$firmware_file" "$drive_path/"
    
    echo "✅ Firmware copied successfully!"
    echo "⏳ Waiting for keyboard to reboot..."
    sleep 3
    return 0
}

# Main script
echo "📦 Checking for firmware files..."

# Find firmware files
LEFT_FW=$(ls *LEFT*.uf2 *left*.uf2 2>/dev/null | head -n1 || echo "")
RIGHT_FW=$(ls *RIGHT*.uf2 *right*.uf2 2>/dev/null | head -n1 || echo "")
RESET_FW=$(ls *RESET*.uf2 *reset*.uf2 2>/dev/null | head -n1 || echo "")

if [[ -z "$LEFT_FW" && -z "$RIGHT_FW" && -z "$RESET_FW" ]]; then
    echo "❌ No firmware files found in current directory!"
    echo "💡 Please download firmware files from GitHub releases"
    echo "   and place them in the same directory as this script."
    exit 1
fi

echo "Found firmware files:"
[[ -n "$RESET_FW" ]] && echo "   RESET: $(basename "$RESET_FW")"
[[ -n "$LEFT_FW" ]] && echo "   LEFT: $(basename "$LEFT_FW")"
[[ -n "$RIGHT_FW" ]] && echo "   RIGHT: $(basename "$RIGHT_FW")"
echo

# Interactive flashing
while true; do
    echo "🔧 Choose what to flash:"
    options=()
    
    [[ -n "$RESET_FW" ]] && options+=("reset:Reset settings (recommended first)")
    [[ -n "$RIGHT_FW" ]] && options+=("right:Right side (flash first)")
    [[ -n "$LEFT_FW" ]] && options+=("left:Left side (flash second)")
    options+=("quit:Exit")
    
    for i in "${!options[@]}"; do
        IFS=':' read -r key desc <<< "${options[$i]}"
        echo "   $((i+1)). $desc"
    done
    
    echo
    read -p "Enter your choice (1-${#options[@]}): " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#options[@]} ]]; then
        echo "❌ Invalid choice!"
        continue
    fi
    
    selected_option="${options[$((choice-1))]}"
    IFS=':' read -r selected_side desc <<< "$selected_option"
    
    if [[ "$selected_side" == "quit" ]]; then
        echo "👋 Goodbye!"
        exit 0
    fi
    
    # Get the firmware file
    case "$selected_side" in
        "reset") firmware_file="$RESET_FW" ;;
        "left") firmware_file="$LEFT_FW" ;;
        "right") firmware_file="$RIGHT_FW" ;;
    esac
    
    if [[ -z "$firmware_file" ]]; then
        echo "❌ Firmware file not available!"
        continue
    fi
    
    # Wait for keyboard and flash
    if drive_path=$(wait_for_keyboard); then
        if flash_firmware "$firmware_file" "$drive_path"; then
            echo "🎉 Flashing completed!"
            [[ "$selected_side" =~ ^(left|right)$ ]] && echo "💡 Remember to flash the other side too!"
        else
            echo "❌ Flashing failed!"
        fi
    else
        echo "❌ Please try again or flash manually"
    fi
    
    echo
    echo "=========================================="
done
