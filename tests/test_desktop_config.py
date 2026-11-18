import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    'desktop_config', ROOT / 'rpi-digie35/usr/lib/rpi-digie35/patch-desktop-config.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DesktopConfigTests(unittest.TestCase):
    def test_raspberry_pi_openbox_config(self):
        original = ('<?xml version="1.0" encoding="UTF-8"?>'
                    '<openbox_config xmlns="http://openbox.org/3.4/rc">'
                    '<!-- Pi bindings --><keyboard><numlock>off</numlock>'
                    '<default/><keybind key="C-A-t"><action name="Execute">'
                    '<command>lxterminal</command></action></keybind></keyboard>'
                    '</openbox_config>')
        with tempfile.TemporaryDirectory() as directory:
            home, etc = Path(directory) / 'home', Path(directory) / 'etc'
            source = etc / 'xdg/labwc/rc.xml'
            source.parent.mkdir(parents=True)
            source.write_text(original)
            module.configure(home, etc, labwc=True, wayfire=False)
            target = home / '.config/labwc/rc.xml'
            updated = target.read_text()
            ns = '{http://openbox.org/3.4/rc}'
            root = ET.fromstring(updated)
            self.assertEqual(root.tag, ns + 'openbox_config')
            self.assertEqual(root.findtext(ns + 'keyboard/' + ns + 'numlock'), 'on')
            self.assertIn('<!-- Pi bindings -->', updated)
            self.assertIn('<command>lxterminal</command>', updated)
            self.assertEqual(source.read_text(), original)
            module.configure(home, etc, labwc=True, wayfire=False)
            self.assertEqual(target.read_text(), updated)

    def test_rejects_unrelated_xml(self):
        with self.assertRaises(ValueError):
            module.enable_numlock('<unrelated/>')

    def test_numlock_preserves_bindings_comments_and_namespace(self):
        for namespace in ('', ' xmlns="urn:labwc"'):
            original = ('<labwc_config' + namespace + '><!-- keep -->'
                        '<keyboard><numlock>off</numlock><keybind key="A-Tab"/>'
                        '</keyboard><theme><name>Pi</name></theme></labwc_config>')
            updated = module.enable_numlock(original)
            self.assertIn('<!-- keep -->', updated)
            self.assertIn('key="A-Tab"', updated)
            self.assertIn('<name>Pi</name>', updated)
            self.assertIn('<numlock>on</numlock>', updated)
            self.assertEqual(module.enable_numlock(updated), updated)

    def test_labwc_copies_defaults_and_preserves_user_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            home, etc = Path(directory) / 'home', Path(directory) / 'etc'
            defaults = etc / 'xdg/labwc/rc.xml'
            defaults.parent.mkdir(parents=True)
            defaults.write_text('<labwc_config><theme><name>Pi</name></theme></labwc_config>')
            module.configure(home, etc, labwc=True, wayfire=False)
            target = home / '.config/labwc/rc.xml'
            self.assertIn('<name>Pi</name>', target.read_text())
            self.assertEqual(ET.fromstring(target.read_text()).findtext('keyboard/numlock'), 'on')
            target.write_text(target.read_text().replace('>Pi<', '>Custom<'))
            module.configure(home, etc, labwc=True, wayfire=False)
            self.assertIn('<name>Custom</name>', target.read_text())

    def test_bookworm_wayfire_and_both_panel_locations(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(module.subprocess, 'run') as run:
            home = Path(directory)
            config = home / '.config'
            (config / 'wf-panel-pi').mkdir(parents=True)
            panels = [config / 'wf-panel-pi.ini', config / 'wf-panel-pi/wf-panel-pi.ini']
            for panel in panels:
                panel.write_text('[panel]\nlauncher_000001=terminal.desktop\n')
            module.configure(home, home / 'etc', labwc=False, wayfire=True)
            calls = [call.args[0] for call in run.call_args_list]
            self.assertIn(['crudini', '--set', str(config / 'wayfire.ini'),
                           'input', 'kb_numlock_default_state', 'true'], calls)
            for panel in panels:
                self.assertIn(['crudini', '--set', str(panel), 'panel',
                               'launcher_900004', 'wvkbd.desktop'], calls)
            self.assertFalse((config / 'labwc').exists())

    def test_no_desktop_does_not_create_configuration(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(module.subprocess, 'run') as run:
            module.configure(Path(directory), Path(directory) / 'etc', labwc=False, wayfire=False)
            run.assert_not_called()
            self.assertFalse((Path(directory) / '.config').exists())

    def test_invalid_xml_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / '.config/labwc/rc.xml'
            target.parent.mkdir(parents=True)
            target.write_text('<broken')
            with self.assertRaises(ET.ParseError):
                module.configure(Path(directory), labwc=True, wayfire=False)
            self.assertEqual(target.read_text(), '<broken')


if __name__ == '__main__':
    unittest.main()
