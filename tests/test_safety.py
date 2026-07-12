from pathlib import Path
import unittest

from drive_rescue.core.models import DriveInfo
from drive_rescue.core.safety import diagnose_drive


class SafetyTests(unittest.TestCase):
    def test_diagnose_ntfs_read_only_time_machine(self):
        drive = DriveInfo(
            name="Backup",
            mount_path=Path("/Volumes/Backup"),
            filesystem="NTFS",
            is_writable=False,
            is_time_machine=True,
        )

        messages = " ".join(diagnose_drive(drive))

        self.assertIn("read-only", messages)
        self.assertIn("NTFS", messages)
        self.assertIn("Time Machine", messages)


if __name__ == "__main__":
    unittest.main()
