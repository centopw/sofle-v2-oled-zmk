#!/usr/bin/env python3
"""
Automated ZMK Firmware Flashing Tool for Sofle V2
This script automates the process of flashing ZMK firmware to your Sofle V2 keyboard.
"""

import os
import sys
import time
import glob
import shutil
import platform
from pathlib import Path

def print_banner():
    print("=" * 60)
    print("🔧 Sofle V2 ZMK Firmware Flasher")
    print("=" * 60)
    print()

def detect_platform():
    """Detect the operating system and return appropriate mount paths"""
    system = platform.system().lower()
    if system == "darwin":  # macOS
        return ["/Volumes"]
    elif system == "linux":
        return ["/media", "/mnt", "/run/media"]
    elif system == "windows":
        # Windows drives
        return [f"{chr(i)}:\\" for i in range(65, 91)]  # A:\ to Z:\
    else:
        return []

def find_keyboard_drive():
    """Find the keyboard when it's in bootloader mode"""
    mount_paths = detect_platform()
    keyboard_drives = []
    
    for mount_base in mount_paths:
        if not os.path.exists(mount_base):
            continue
            
        try:
            for item in os.listdir(mount_base):
                full_path = os.path.join(mount_base, item)
                if os.path.isdir(full_path):
                    # Check if this looks like a keyboard in bootloader mode
                    # Look for typical bootloader indicators
                    info_file = os.path.join(full_path, "INFO_UF2.TXT")
                    if os.path.exists(info_file):
                        keyboard_drives.append(full_path)
        except (PermissionError, OSError):
            continue
    
    return keyboard_drives

def find_firmware_files():
    """Find firmware files in the current directory"""
    firmware_files = {
        'left': None,
        'right': None,
        'reset': None
    }
    
    # Look for firmware files with clear naming
    for pattern, key in [
        ("*LEFT*.uf2", 'left'),
        ("*left*.uf2", 'left'),
        ("*RIGHT*.uf2", 'right'), 
        ("*right*.uf2", 'right'),
        ("*RESET*.uf2", 'reset'),
        ("*reset*.uf2", 'reset')
    ]:
        files = glob.glob(pattern)
        if files and not firmware_files[key]:
            firmware_files[key] = files[0]
    
    return firmware_files

def flash_firmware(firmware_path, drive_path):
    """Flash firmware to the keyboard"""
    try:
        firmware_name = os.path.basename(firmware_path)
        target_path = os.path.join(drive_path, firmware_name)
        
        print(f"📁 Copying {firmware_name} to {drive_path}")
        shutil.copy2(firmware_path, target_path)
        
        print("✅ Firmware copied successfully!")
        print("⏳ Waiting for keyboard to reboot...")
        time.sleep(3)
        return True
    except Exception as e:
        print(f"❌ Error flashing firmware: {e}")
        return False

def wait_for_keyboard():
    """Wait for keyboard to appear in bootloader mode"""
    print("🔍 Waiting for keyboard in bootloader mode...")
    print("💡 Press the BOOT button twice quickly on your keyboard")
    print()
    
    for i in range(30):  # Wait up to 30 seconds
        drives = find_keyboard_drive()
        if drives:
            print(f"🎯 Found keyboard drive: {drives[0]}")
            return drives[0]
        
        print(f"⏳ Searching... ({i+1}/30)", end="\r")
        time.sleep(1)
    
    print("\n❌ Timeout: Could not find keyboard in bootloader mode")
    return None

def main():
    print_banner()
    
    # Check for firmware files
    firmware_files = find_firmware_files()
    available_files = {k: v for k, v in firmware_files.items() if v}
    
    if not available_files:
        print("❌ No firmware files found in current directory!")
        print("💡 Please download firmware files from the GitHub releases")
        print("   and place them in the same directory as this script.")
        return 1
    
    print("📦 Found firmware files:")
    for side, filepath in available_files.items():
        print(f"   {side.upper()}: {os.path.basename(filepath)}")
    print()
    
    # Interactive mode
    while True:
        print("🔧 Choose what to flash:")
        options = []
        if firmware_files['reset']:
            options.append(("reset", "Reset settings (recommended first)"))
        if firmware_files['left']:
            options.append(("left", "Left side (flash second)"))
        if firmware_files['right']:
            options.append(("right", "Right side (flash first)"))
        options.append(("quit", "Exit"))
        
        for i, (key, desc) in enumerate(options, 1):
            print(f"   {i}. {desc}")
        
        try:
            choice = input("\nEnter your choice (1-{}): ".format(len(options)))
            choice_idx = int(choice) - 1
            
            if choice_idx == len(options) - 1:  # Quit option
                print("👋 Goodbye!")
                return 0
                
            selected_side = options[choice_idx][0]
            firmware_path = firmware_files[selected_side]
            
            if not firmware_path:
                print("❌ Firmware file not available!")
                continue
                
        except (ValueError, IndexError):
            print("❌ Invalid choice!")
            continue
        
        # Wait for keyboard
        drive_path = wait_for_keyboard()
        if not drive_path:
            print("❌ Please try again or flash manually")
            continue
        
        # Flash firmware
        success = flash_firmware(firmware_path, drive_path)
        
        if success:
            print("🎉 Flashing completed!")
            if selected_side in ['left', 'right']:
                print("💡 Remember to flash the other side too!")
        
        print("\n" + "="*60)

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n👋 Interrupted by user. Goodbye!")
        sys.exit(0)
