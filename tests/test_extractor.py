from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from drive_rescue.core.extractor import (
    ExtractionCancelled,
    InsufficientSpaceError,
    extract_files,
    preview_paths,
)
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

    def test_progress_reports_plan_and_completed_files(self):
        with TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "source"
            destination = tmp_path / "destination"
            source.mkdir()
            (source / "one.txt").write_text("one", encoding="utf-8")
            (source / "two.txt").write_text("two", encoding="utf-8")
            events = []

            report = extract_files(
                ExtractionOptions(
                    source=source,
                    destination=destination,
                    progress_callback=events.append,
                )
            )

            self.assertEqual(report.status, "complete")
            self.assertEqual(events[0].phase, "planned")
            self.assertEqual(events[0].files_total, 2)
            self.assertEqual(events[-1].phase, "complete")
            self.assertEqual(events[-1].files_completed, 2)
            self.assertEqual(events[-1].bytes_completed, 6)

    def test_dry_run_progress_lists_preview_items(self):
        with TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "source"
            destination = tmp_path / "destination"
            source.mkdir()
            (source / "one.txt").write_text("one", encoding="utf-8")
            events = []

            extract_files(
                ExtractionOptions(
                    source=source,
                    destination=destination,
                    dry_run=True,
                    progress_callback=events.append,
                )
            )

            preview_items = [event for event in events if event.phase == "preview_item"]
            self.assertEqual(len(preview_items), 1)
            self.assertEqual(preview_items[0].current_path, Path("one.txt"))
            self.assertEqual(preview_items[0].current_size, 3)

    def test_low_space_stops_before_destination_is_created(self):
        with TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "source"
            destination = tmp_path / "destination"
            source.mkdir()
            (source / "large.bin").write_bytes(b"12345")

            with patch("drive_rescue.core.extractor.available_capacity", return_value=4):
                with self.assertRaises(InsufficientSpaceError):
                    extract_files(ExtractionOptions(source=source, destination=destination))

            self.assertFalse(destination.exists())

    def test_destination_inside_source_is_rejected(self):
        with TemporaryDirectory() as tmp:
            source = Path(tmp) / "source"
            source.mkdir()
            (source / "keep.txt").write_text("keep", encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "outside the source"):
                extract_files(ExtractionOptions(source=source, destination=source / "recovered"))

            self.assertFalse((source / "recovered").exists())

    def test_cancelled_zip_removes_partial_archive(self):
        with TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "source"
            destination = tmp_path / "destination"
            source.mkdir()
            (source / "one.txt").write_text("one", encoding="utf-8")
            cancel_requested = False

            def progress(event):
                nonlocal cancel_requested
                if event.phase == "copying":
                    cancel_requested = True

            with self.assertRaises(ExtractionCancelled) as context:
                extract_files(
                    ExtractionOptions(
                        source=source,
                        destination=destination,
                        compress=True,
                        progress_callback=progress,
                        cancel_check=lambda: cancel_requested,
                    )
                )

            self.assertEqual(context.exception.report.status, "cancelled")
            self.assertFalse((destination / "source-recovered.zip").exists())
            self.assertFalse((destination / "source-recovered.zip.partial").exists())

    def test_copy_error_is_recorded_without_stopping_other_files(self):
        with TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "source"
            destination = tmp_path / "destination"
            source.mkdir()
            (source / "bad.txt").write_text("bad", encoding="utf-8")
            (source / "good.txt").write_text("good", encoding="utf-8")
            real_copy = __import__("shutil").copy2

            def copy_with_one_failure(source_path, destination_path):
                if Path(source_path).name == "bad.txt":
                    raise OSError("simulated unreadable file")
                return real_copy(source_path, destination_path)

            with patch("drive_rescue.core.extractor.shutil.copy2", side_effect=copy_with_one_failure):
                report = extract_files(ExtractionOptions(source=source, destination=destination))

            self.assertEqual(report.status, "complete_with_errors")
            self.assertEqual(report.files_copied, 1)
            self.assertEqual(report.files_failed, 1)
            self.assertTrue((destination / "good.txt").exists())
            self.assertFalse((destination / "bad.txt").exists())


if __name__ == "__main__":
    unittest.main()
