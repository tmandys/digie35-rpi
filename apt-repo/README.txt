# Digie35 installation: Raspberry Pi OS Bookworm / Trixie, 64-bit
# Follow sections in order, in a terminal logged in as pi. This is an interactive
# guide, not an unattended script. Stop if a command fails. Use Raspberry Pi OS
# with desktop; create user pi and configure network/SSH in Raspberry Pi Imager.

# 1. Prepare Raspberry Pi OS on SD
# Write Raspberry Pi OS to SD with Imager, configure pi/network/SSH and boot it.
# Install BOTH rpi-digie35 and the Python application on this SD using sections
# 2-6 below. For NVMe, clone this fully configured system in section 7.
# For SD-only operation, finish after section 6.
# Connect the NVMe SSD/adapter to Raspberry Pi 5 only while powered off.

findmnt /
findmnt /boot/firmware
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS

# At this stage / and /boot/firmware are on SD (normally mmcblk0 partitions).
# EEPROM belongs to the board; installed packages belong to the system disk.
# Our package's postinst sets BOOT_ORDER=0xf461 (SD -> NVMe -> USB -> repeat)
# and enables PCIe on Pi 5 with dtparam=pciex1=on. A separate raspi-config boot
# order step is not needed for this workflow. Reboot after package installation
# to apply the pending EEPROM configuration before cloning.
# Non-HAT+ adapters may additionally require PCIE_PROBE=1 in EEPROM; our package
# does not set it. Consult the adapter instructions if NVMe is not detected.

# 2. Check OS and prepare repository tools
. /etc/os-release
arch=$(dpkg --print-architecture)
printf 'OS: %s; codename: %s; architecture: %s\n' "$PRETTY_NAME" "$VERSION_CODENAME" "$arch"
whoami
# Expected: bookworm or trixie, arm64, pi. Digie35 publishes an ARM64 APT index.

sudo apt update
sudo apt install ca-certificates curl gnupg
sudo install -d -m 0755 /etc/apt/keyrings

# 3. Register repositories; use the real OS codename, not Bookworm on Trixie.
# On existing installations, avoid duplicate entries if the same repository
# is already configured in a .sources file.

# log2ram: RAM-backed /var/log to reduce SD writes.
curl -fsSL https://azlux.fr/repo.gpg -o /tmp/digie35-azlux.gpg
sudo install -m 0644 /tmp/digie35-azlux.gpg /etc/apt/keyrings/azlux.gpg
rm -f /tmp/digie35-azlux.gpg
echo "deb [signed-by=/etc/apt/keyrings/azlux.gpg] https://packages.azlux.fr/debian/ $VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/azlux.list

# Digie35
url=https://repos.digie35.com/debian
curl -fsSL "$url/repo.gpg.key" -o /tmp/digie35-repo-key.asc
sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/digie35.gpg /tmp/digie35-repo-key.asc
sudo chmod 0644 /etc/apt/keyrings/digie35.gpg
rm -f /tmp/digie35-repo-key.asc
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/digie35.gpg] $url $VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/digie35.list

# Microsoft VS Code; use the OS architecture instead of hardcoded amd64.
url=https://packages.microsoft.com
curl -fsSL "$url/keys/microsoft.asc" -o /tmp/digie35-microsoft-key.asc
sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg /tmp/digie35-microsoft-key.asc
sudo chmod 0644 /etc/apt/keyrings/microsoft.gpg
rm -f /tmp/digie35-microsoft-key.asc
echo "deb [arch=$arch signed-by=/etc/apt/keyrings/microsoft.gpg] $url/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list

sudo apt update
apt-cache policy rpi-digie35 log2ram code
# Each package must have a candidate. If the Digie35 suite is missing/outdated,
# publish the updated package/index for that codename before continuing.
# Local source changes do not automatically update repos.digie35.com.

# 4. Install system dependencies and hardware configuration
sudo apt full-upgrade
sudo apt install rpi-digie35
sudo reboot

# Reconnect as pi after reboot. The package generates a hostname such as
# digie35-153c2582; connect using the IP address or the new hostname.
# Reboot applies UART, EEPROM, group membership, desktop and log2ram changes.
# Legacy GPIO tools are recommendations: available on Bookworm, optional on
# Trixie. Avoid --no-install-recommends if you want available legacy tools.

# 5. Install the Python application as pi, not root
# This guide retains installation under ~/.local with pip --user. Run outside
# an activated virtual environment. The updated rpi-digie35 package removes
# EXTERNALLY-MANAGED using the system Python's actual stdlib path; no manual
# deletion or hardcoded Python 3.11 path is needed.
# Install the newest compatible published release instead of pinning old 0.6.
/usr/bin/python3 -m pip install --user --upgrade --find-links=https://repos.digie35.com/python/ digie35_ctrl

# Make tools available immediately; standard Raspberry Pi OS ~/.profile also
# adds ~/.local/bin on future logins once the directory exists.
export PATH="$HOME/.local/bin:$PATH"
. "$HOME/.profile"
/usr/bin/python3 -m pip show digie35_ctrl

# Use a normal pi login session (desktop terminal or SSH), not sudo su/root.
# HEAD is the default board; substitute GULP, NIKI or ALPHA as appropriate.
# Allow nginx to traverse the home directory containing the web application.
chmod a+x "$HOME"
digie35_install -i -b HEAD

# 6. Verify installation and optionally rename the device
systemctl --user status digie35@HEAD.service hdmi-streamer.service
sudo nginx -t
systemctl status log2ram.service
findmnt /var/log
hostnamectl

# Custom hostname, retained on package upgrades (normalized to lowercase):
#   sudo digie35-set-hostname --hostname Digie35-2
# Restore a hardware-derived name:
#   sudo digie35-set-hostname --auto
# After booting a cloned image on a different Pi:
#   sudo digie35-set-hostname
# This sets the hostname only; it does not regenerate SSH keys or machine-id.
# Reboot after renaming if services still advertise the previous name.

# 7. Optional: move the prepared SD system to NVMe
# Complete sections 2-6 on SD first, including the reboot in section 4.
# Shut down cleanly before making an offline clone:
#   sudo poweroff
# On another computer with suitable SD/NVMe adapters, copy the WHOLE SD disk
# (partition table, boot and root partitions) to NVMe, directly or via a disk
# image. For a raw whole-disk clone the destination must be at least as large
# as the source SD. Verify source and destination: cloning erases the NVMe.
# Do not write a fresh Raspberry Pi OS image to NVMe at this point: that would
# omit the packages, application and configuration just prepared on SD.
# Reconnect NVMe to the powered-off Pi, REMOVE the SD card, and power it on.
# Keep the SD removed: it has boot priority and a raw clone shares disk IDs.
# Confirm that BOTH the root and boot filesystems now come from NVMe:
#   findmnt /
#   findmnt /boot/firmware
#   lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
# Expected: nvme0n1 partitions. Repeat the service checks from section 6.
# No package or Python application reinstall is needed on the cloned NVMe.
# On the same Pi the hostname stays valid; on another Pi run the hostname
# script described above. If the cloned partitions do not fill a larger NVMe,
# expand the root filesystem using raspi-config after verifying NVMe boot.

# References:
# https://www.raspberrypi.com/documentation/computers/raspberry-pi.html
# https://packages.azlux.fr/
# https://code.visualstudio.com/docs/setup/linux
# https://pip.pypa.io/en/stable/cli/pip_install/
