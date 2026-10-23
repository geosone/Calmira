"""Native DOS/Windows tests must not silently opt into host KVM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUNNERS = ROOT / 'tests/dos'


class QemuDefaultsTests(unittest.TestCase):
    def test_native_runners_default_to_software_emulation(self):
        checked = 0
        for path in sorted(RUNNERS.glob('*.sh')):
            if path.name == 'replay_dos_bridge.sh':
                continue
            for line in path.read_text().splitlines():
                if '| qemu-system-i386 ' in line:
                    with self.subTest(runner=path.name):
                        self.assertIn('-accel "${QEMU_ACCEL:-tcg}"', line)
                    checked += 1
        self.assertGreater(checked, 0)

    def test_replay_defaults_to_tcg_only(self):
        text = (RUNNERS / 'replay_dos_bridge.sh').read_text()
        self.assertIn('for accel in ${BRIDGE_ACCELS:-tcg}; do', text)


if __name__ == '__main__':
    unittest.main()
