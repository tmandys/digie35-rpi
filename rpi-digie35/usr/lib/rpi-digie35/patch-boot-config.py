#!/usr/bin/env python3
"""Maintain one section-aware Digie35 block in Raspberry Pi boot configuration."""
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

BEGIN = "# BEGIN DIGIE35"
END = "# END DIGIE35"
SETTINGS = {
    "all": (
        "dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4",
        "dtoverlay=act-led,gpio=26",
        "dtoverlay=i2c-rtc,mcp7941x",
        "usb_max_current_enable=1",
    ),
    "pi3": ("enable_uart=1", "dtoverlay=disable-bt"),
    "pi4": ("enable_uart=1", "dtoverlay=disable-bt"),
    "pi5": ("avoid_warnings=1", "dtparam=pciex1=on", "dtoverlay=uart0-pi5"),
}


def key(line):
    if line.startswith("dtoverlay="):
        return line.split(",", 1)[0]
    if line.startswith("dtparam="):
        return "=".join(line.split("=", 2)[:2])
    return line.split("=", 1)[0]


def patch_config(text):
    result = []
    section = "all"
    in_block = False
    owned = {section: {key(line) for line in lines} for section, lines in SETTINGS.items()}
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == BEGIN:
            if in_block:
                raise ValueError("Nested Digie35 configuration block")
            in_block = True
            continue
        if stripped == END:
            if not in_block:
                raise ValueError("Unexpected end of Digie35 configuration block")
            in_block = False
            section = "all"  # the managed block always ends in [all]
            continue
        if in_block:
            continue
        match = re.fullmatch(r"\[([^]]+)\](?:\s*#.*)?", stripped)
        if match:
            section = match[1]
        # Replace active settings only in the section we manage. Preserve comments
        # and settings for other boards. Migrate Pi 5 values misplaced by old postinst.
        managed = owned.get(section, set())
        if section == "all":
            managed = managed | owned["pi5"]
            # UART0 routing must be model-specific, including on upgraded images.
            managed = managed | owned["pi3"]
        if section in ("all", "pi3", "pi4"):
            managed = managed | {"dtoverlay=miniuart-bt", "dtoverlay=pi3-miniuart-bt",
                                 "dtoverlay=pi3-disable-bt"}
        if not stripped.startswith("#") and key(stripped) in managed:
            continue
        result.append(line)
    if in_block:
        raise ValueError("Unterminated Digie35 configuration block")
    result = "\n".join(result).rstrip() + "\n\n" + BEGIN + "\n"
    for section, settings in SETTINGS.items():
        result += "[" + section + "]\n" + "\n".join(settings) + "\n"
    return result + "[all]\n" + END + "\n"


def patch_cmdline(text):
    # Keep the display console and all unrelated kernel options.
    tokens = [token for token in text.split()
              if not re.match(r"^console=(serial[01]|ttyAMA0|ttyS0)(,|$)", token)]
    return " ".join(tokens) + "\n"


def update_file(filename, transform):
    path = Path(filename).resolve()
    original = path.read_text()
    updated = transform(original)
    if original == updated:
        return
    # Write beside the original, then rename; never truncate the live boot config.
    descriptor, temporary = tempfile.mkstemp(prefix=".digie35-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(updated)
            os.fchmod(stream.fileno(), stat.S_IMODE(path.stat().st_mode))
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    update_file(sys.argv[1], patch_config)
    if len(sys.argv) > 2:
        update_file(sys.argv[2], patch_cmdline)
