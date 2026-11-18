#!/usr/bin/env python3
"""Configure the pi desktop on Wayfire and labwc without replacing user settings."""
from pathlib import Path
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET


def enable_numlock(text):
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.fromstring(text, parser=parser)
    namespace = root.tag.split('}')[0] + '}' if root.tag.startswith('{') else ''
    if root.tag not in (namespace + 'labwc_config', namespace + 'openbox_config'):
        raise ValueError('Expected labwc_config or openbox_config XML root')
    if namespace:
        ET.register_namespace('', namespace[1:-1])
    keyboard = root.find(namespace + 'keyboard')
    if keyboard is None:
        keyboard = ET.SubElement(root, namespace + 'keyboard')
    numlock = keyboard.find(namespace + 'numlock')
    if numlock is None:
        numlock = ET.SubElement(keyboard, namespace + 'numlock')
    numlock.text = 'on'
    return ET.tostring(root, encoding='unicode') + '\n'


def configure(home, etc=Path('/etc'), labwc=None, wayfire=None):
    config = Path(home) / '.config'
    if labwc is None:
        labwc = shutil.which('labwc') is not None
    if wayfire is None:
        wayfire = shutil.which('wayfire') is not None

    wayfire_file = config / 'wayfire.ini'
    if wayfire or wayfire_file.exists():
        config.mkdir(parents=True, exist_ok=True)
        subprocess.run(['crudini', '--set', str(wayfire_file), 'input',
                        'kb_numlock_default_state', 'true'], check=True)

    labwc_file = config / 'labwc/rc.xml'
    if labwc or labwc_file.exists():
        # Start from distro defaults so a new per-user file retains Pi bindings.
        source = next((p for p in (labwc_file, etc / 'xdg/labwc/rc.xml',
                                   etc / 'skel/.config/labwc/rc.xml') if p.exists()), None)
        original = source.read_text() if source else '<labwc_config/>'
        updated = enable_numlock(original)
        labwc_file.parent.mkdir(parents=True, exist_ok=True)
        if not labwc_file.exists() or labwc_file.read_text() != updated:
            labwc_file.write_text(updated)

    # Support both panel config locations; edit only existing configurations.
    # A missing panel config is normal before the first desktop login.
    panels = [p for p in (config / 'wf-panel-pi/wf-panel-pi.ini',
                           config / 'wf-panel-pi.ini') if p.exists()]
    for panel in panels:
        subprocess.run(['crudini', '--set', str(panel), 'panel',
                        'launcher_900004', 'wvkbd.desktop'], check=True)
    if not panels:
        print('No user panel configuration yet; wvkbd remains available in the applications menu.')


if __name__ == '__main__':
    configure(Path(sys.argv[1]))
