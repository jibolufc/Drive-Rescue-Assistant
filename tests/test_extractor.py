from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from drive_rescue.core.extractor import extract_files, preview_paths
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

    def test_selected_paths_only_copy_selected_preview_files(self):
        with TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "source"
            destination = tmp_path / "destination"
            source.mkdir()
            (source / "keep.txt").write_text("keep", encoding="utf-8")
            (source / "skip.txt").write_text("skip", encoding="utf-8")

            preview = preview_paths(source, scope="documents")
            self.assertEqual({path for path, _size in preview}, {Path("keep.txt"), Path("skip.txt")})

            report = extract_files(
                ExtractionOptions(
                    source=source,
                    destination=destination,
                    scope="documents",
                    selected_paths=frozenset({Path("keep.txt")}),
                )
            )

            self.assertEqual(report.files_copied, 1)
            self.assertTrue((destination / "keep.txt").exists())
            self.assertFalse((destination / "skip.txt").exists())


if __name__ == "__main__":
    unittest.main()
