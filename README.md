# digie35-rpi

Install intended packages and updates configuration. 

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
```
