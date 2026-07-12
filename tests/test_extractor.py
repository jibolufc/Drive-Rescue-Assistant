from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from drive_rescue.core.extractor import extract_files
from drive_rescue.core.models import ExtractionOptions


class ExtractorTests(unittest.TestCase):
    def test_dry_run_counts_files_without_copying(self):
        with TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "source"
            destination = tmp_path / "destination"
            source.mkdir()
            (source / "hello.txt").write_text("hello", encoding="utf-8")

            report = extract_files(ExtractionOptions(source=source, destination=destination, dry_run=True))

            self.assertEqual(report.files_seen, 1)
            self.assertEqual(report.files_matched, 1)
            self.assertEqual(report.files_copied, 0)
            self.assertEqual(report.bytes_planned, 5)
            self.assertFalse(destination.exists())

    def test_scope_filters_files(self):
        with TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "source"
            destination = tmp_path / "destination"
            source.mkdir()
            (source / "photo.jpg").write_text("photo", encoding="utf-8")
            (source / "notes.txt").write_text("notes", encoding="utf-8")

            report = extract_files(ExtractionOptions(source=source, destination=destination, dry_run=True, scope="photos"))

            self.assertEqual(report.files_seen, 2)
            self.assertEqual(report.files_matched, 1)
            self.assertEqual(report.files_filtered, 1)
            self.assertEqual(report.bytes_planned, 5)

    def test_compress_writes_zip(self):
        with TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "source"
            destination = tmp_path / "destination"
            source.mkdir()
            (source / "hello.txt").write_text("hello", encoding="utf-8")

            report = extract_files(ExtractionOptions(source=source, destination=destination, compress=True))

            self.assertEqual(report.files_copied, 1)
            self.assertTrue((destination / "source-recovered.zip").exists())


if __name__ == "__main__":
    unittest.main()
