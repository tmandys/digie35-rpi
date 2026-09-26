import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("boot_config", ROOT / "rpi-digie35/usr/lib/rpi-digie35/patch-boot-config.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BootConfigTests(unittest.TestCase):
    def test_sections_and_idempotence(self):
        for original in ("[all]\n", "[pi4]\n# settings\n", "", "[all]\navoid_warnings=1\ndtparam=pciex1=on\n"):
            with self.subTest(original=original):
                patched = module.patch_config(original)
                self.assertEqual(module.patch_config(patched), patched)
                self.assertEqual(patched.count("dtparam=pciex1=on"), 1)
                self.assertIn("[pi5]\navoid_warnings=1\ndtparam=pciex1=on\ndtoverlay=uart0-pi5\n[all]", patched)

    def test_uart_routing_by_model_and_migration(self):
        original = "[all]\nenable_uart=0\ndtoverlay=miniuart-bt\ndtoverlay=disable-bt\ndtoverlay=uart0-pi5\n"
        patched = module.patch_config(original)
        sections = {}
        section = "all"
        for line in patched.splitlines():
            if line.startswith("["):
                section = line[1:-1]
            else:
                sections.setdefault(section, []).append(line)
        for model in ("pi3", "pi4"):
            self.assertIn("enable_uart=1", sections[model])
            self.assertIn("dtoverlay=disable-bt", sections[model])
        self.assertIn("dtoverlay=uart0-pi5", sections["pi5"])
        self.assertNotIn("dtoverlay=disable-bt", sections["pi5"])
        self.assertNotIn("dtoverlay=disable-bt", sections["all"])
        self.assertNotIn("dtoverlay=miniuart-bt", patched)
        self.assertEqual(module.patch_config(patched), patched)

    def test_kernel_console_preserves_display_and_other_options(self):
        original = "console=serial0,115200 console=tty1 root=PARTUUID=123 quiet console=ttyAMA0,9600 console=ttyS0,115200 console=serial1,115200\n"
        expected = "console=tty1 root=PARTUUID=123 quiet\n"
        self.assertEqual(module.patch_cmdline(original), expected)
        self.assertEqual(module.patch_cmdline(expected), expected)

    def test_existing_overlay_and_other_sections(self):
        original = "[all]\ndtoverlay=act-led\n# dtoverlay=act-led,gpio=1\n[pi4]\ndtoverlay=act-led,gpio=2\n"
        patched = module.patch_config(original)
        self.assertNotIn("dtoverlay=act-led\n", patched)
        self.assertIn("# dtoverlay=act-led,gpio=1", patched)
        self.assertIn("[pi4]\ndtoverlay=act-led,gpio=2", patched)

    def test_refuses_unterminated_block(self):
        with self.assertRaises(ValueError):
            module.patch_config("[all]\n# BEGIN DIGIE35\nuser_setting=1\n")


if __name__ == "__main__":
    unittest.main()
