# digie35-rpi

Install intended packages and updates configuration. 

For the complete fresh-install procedure (SD or NVMe, repositories, system
package, Python application and verification), see [apt-repo/README.txt](apt-repo/README.txt).

## Build a package for manual transfer

On Debian/Ubuntu or Raspberry Pi OS (including a Linux environment under WSL):

```sh
sudo apt install dpkg-dev
sh build_pkg.sh --package-only
```

This writes `apt-repo/pool/main/rpi-digie35_0.6-0_all.deb` on the first build;
subsequent builds increment the release suffix. No signing keys or APT repository
generation are needed. The package is architecture-independent and can be built
on an x86 Linux computer for installation on the Raspberry Pi.

Builds record root ownership for system files regardless of the build user's
UID/GID. During installation, `postinst` assigns the packaged `/home/pi` directory
and its `.vimrc` and `.tmux.conf` files to `pi` and its primary group on the target machine. It does not
recursively change other home files; desktop configuration is written as `pi`.

Copy the resulting file to the Pi, then install it there:

```sh
scp apt-repo/pool/main/rpi-digie35_0.6-0_all.deb pi@RPI_IP:/home/pi/
ssh pi@RPI_IP
sudo apt install ./rpi-digie35_0.6-0_all.deb
```

Replace `RPI_IP` and the filename as appropriate. Run the installation from the
directory containing the transferred file. APT resolves dependencies from the
Pi's configured repositories; the external log2ram repository is still required.
The local `.deb` does not require adding the Digie35 APT repository or its key.
Installation runs `postinst`, including hostname setup; reboot afterwards.

Without `--package-only`, `build_pkg.sh` also generates and signs the APT
repository and requires the existing keys in `pgp/`.

## Raspberry Pi OS Bookworm and Trixie

The package targets Raspberry Pi OS (64-bit) with an existing `pi` user.
Enable the external log2ram repository before installing; log2ram is not in
the standard Debian/Raspberry Pi package indexes.

- `chromium-browser | chromium` and `fuse3 | fuse` allow either package name;
  FUSE 2 and FUSE 3 tools are not required simultaneously.
- Legacy `raspi-gpio`, `pigpio` and `pigpio-tools` remain in `Recommends`:
  APT normally installs available recommendations on Bookworm, while unavailable
  legacy packages do not prevent installation on Trixie. `raspi-utils` remains
  required. This does not provide pigpio functionality on systems lacking it.
- NumLock is configured for installed Wayfire/labwc desktops, including labwc
  on updated Bookworm. A new labwc user configuration starts from distro defaults.
  Both known user panel configuration paths are supported. If neither exists
  before the first desktop login, the panel shortcut is skipped; wvkbd is still
  in the applications menu. Desktop changes take effect after logging in again.
- Desktop configuration is written as `pi`. The installer checks that account
  before making changes.
- As requested, installation removes `EXTERNALLY-MANAGED` from the standard
  library directory reported by `/usr/bin/python3` via `sysconfig`, rather than
  assuming Python 3.11. An activated virtual environment does not change the target.
  `python3-venv` is included; existing virtual environments are not modified.

Package names were checked against the Bookworm/Trixie ARM64 Debian and Raspberry
Pi indexes. Installation and hardware operation still need testing on each OS.

## Hostname after installation or cloning

Package configuration runs `/usr/bin/digie35-set-hostname`. The default name is
`digie35-<8 hex digits>`, using the first eight digits of SHA-256 of the full
lowercase hardware serial. This provides 32 bits of identifier space; for 100
boards the approximate probability of any collision is 0.000115% (not a guarantee).
The script reads the device tree serial, falling back to `/proc/cpuinfo`, and
rejects missing, invalid or all-zero serials before changing the system.

After booting a cloned SD card **on the destination Raspberry Pi**, run:

```sh
sudo digie35-set-hostname
```

Before installing the package, the same script can be run from this repository:

```sh
sudo sh rpi-digie35/usr/bin/digie35-set-hostname
```

Use `sudo digie35-set-hostname --hostname Digie35-2` to set an exact custom name
(normalized to `digie35-2`). Use `sudo digie35-set-hostname --auto` to return to
the generated name. Names must be a single label of at most 63 ASCII letters,
digits or internal hyphens. Custom-name uniqueness is the administrator's choice.
The name and board serial are saved in `/etc/rpi-digie35/hostname-state` and
reused on upgrades and subsequent runs on the same board. On a different board,
the script discards the cloned name and generates a new one from its serial.
Running the script again on the same board is idempotent.
It requires root and a running systemd; `hostnamectl` updates the active hostname
and `/etc/hostname`, and the script updates or adds the `127.0.1.1` mapping in
`/etc/hosts`, preserving unrelated entries, aliases and comments. An installation
replaces an existing hostname with this generated name. Subsequent upgrades
preserve names selected through this script.

This is a hostname setup script, not full image personalization: it does not
regenerate machine-id or SSH host keys, and cloning does not trigger it
automatically. Restart services or reboot if they still advertise the old name.

## UART for the TMC2208 adapter

Installation prepares PL011 UART0 on GPIO14 (TX) and GPIO15 (RX):

- Raspberry Pi 3/4: `enable_uart=1` and `dtoverlay=disable-bt`. This disables
  onboard Bluetooth; the installer also disables/stops `hciuart` when present.
- Raspberry Pi 5: `dtoverlay=uart0-pi5`. Bluetooth is left enabled.

The installer removes `console=serial0`, `console=serial1`, `console=ttyAMA0`
and `console=ttyS0` kernel arguments, preserving the display console and other
arguments. Serial login services for ttyAMA0, serial0 and ttyS0 are masked.
The existing target user `pi` is added to `dialout`.

Reboot after installation. Verify `/dev/ttyAMA0` and GPIO14/15 on the actual board
before running the application's UART diagnostics. Merely installing pyserial or
changing a GPIO alternate function does not enable the Linux UART device.
This configuration targets a standard Raspberry Pi OS boot layout with
`config.txt` and `cmdline.txt` together in `/boot/firmware` (or `/boot` on older OS).

Configuration tests without Raspberry Pi hardware:

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
sh tests/test_shell.sh
sh tests/test_hostname.sh
```
