from __future__ import annotations

import queue
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from .core.extractor import extract_files, preview_paths
from .core.models import DriveInfo, ExtractionOptions
from .platforms.current import platform_adapter


SCOPES = ("all", "documents", "photos", "videos", "audio", "archives")


def format_bytes(value: int | None) -> str:
    if value is None:
        return "Unknown"
    amount = float(value)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if amount < 1024 or unit == "TB":
            return f"{int(amount)} {unit}" if unit == "B" else f"{amount:.2f} {unit}"
        amount /= 1024
    return f"{value} B"


class DriveRescueDesktop(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Drive Rescue Assistant")
        self.geometry("1040x700")
        self.minsize(860, 600)

        self.drives: list[DriveInfo] = []
        self.preview_items: list[tuple[Path, int]] = []
        self.worker_messages: queue.Queue[tuple[str, object]] = queue.Queue()

        self.source_var = tk.StringVar()
        self.destination_var = tk.StringVar()
        self.scope_var = tk.StringVar(value="all")
        self.compress_var = tk.BooleanVar(value=False)
        self.status_var = tk.StringVar(value="Connect a drive or choose a source folder.")
        self.summary_var = tk.StringVar(value="No preview yet")

        self._configure_style()
        self._build_ui()
        self.after(100, self._poll_worker)
        self.refresh_drives()

    def _configure_style(self) -> None:
        style = ttk.Style(self)
        available = style.theme_names()
        if "vista" in available:
            style.theme_use("vista")
        elif "clam" in available:
            style.theme_use("clam")
        style.configure("Title.TLabel", font=("TkDefaultFont", 20, "bold"))
        style.configure("Section.TLabel", font=("TkDefaultFont", 11, "bold"))
        style.configure("Muted.TLabel", foreground="#666666")
        style.configure("Primary.TButton", padding=(14, 8))

    def _build_ui(self) -> None:
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=1)

        sidebar = ttk.Frame(self, padding=(16, 18))
        sidebar.grid(row=0, column=0, sticky="nsew")
        sidebar.rowconfigure(2, weight=1)
        ttk.Label(sidebar, text="Connected Drives", style="Section.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Button(sidebar, text="Refresh", command=self.refresh_drives).grid(row=1, column=0, sticky="ew", pady=(10, 10))
        self.drive_list = tk.Listbox(sidebar, width=28, height=18, exportselection=False)
        self.drive_list.grid(row=2, column=0, sticky="nsew")
        self.drive_list.bind("<<ListboxSelect>>", self._drive_selected)

        content = ttk.Frame(self, padding=(28, 22))
        content.grid(row=0, column=1, sticky="nsew")
        content.columnconfigure(0, weight=1)
        content.rowconfigure(8, weight=1)

        ttk.Label(content, text="Drive Rescue Assistant", style="Title.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(
            content,
            text="Preview and copy readable files without changing the source.",
            style="Muted.TLabel",
        ).grid(row=1, column=0, sticky="w", pady=(2, 18))

        source = ttk.Frame(content)
        source.grid(row=2, column=0, sticky="ew")
        source.columnconfigure(0, weight=1)
        ttk.Label(source, text="Source", style="Section.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Entry(source, textvariable=self.source_var, state="readonly").grid(row=1, column=0, sticky="ew", pady=(6, 0))
        ttk.Button(source, text="Choose Folder", command=self.choose_source).grid(row=1, column=1, padx=(8, 0), pady=(6, 0))

        destination = ttk.Frame(content)
        destination.grid(row=3, column=0, sticky="ew", pady=(15, 0))
        destination.columnconfigure(0, weight=1)
        ttk.Label(destination, text="Extraction Destination", style="Section.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Entry(destination, textvariable=self.destination_var, state="readonly").grid(row=1, column=0, sticky="ew", pady=(6, 0))
        ttk.Button(destination, text="Choose Folder", command=self.choose_destination).grid(row=1, column=1, padx=(8, 0), pady=(6, 0))

        options = ttk.Frame(content)
        options.grid(row=4, column=0, sticky="ew", pady=(16, 0))
        ttk.Label(options, text="File type").grid(row=0, column=0, sticky="w")
        scope = ttk.Combobox(options, textvariable=self.scope_var, values=SCOPES, state="readonly", width=16)
        scope.grid(row=0, column=1, padx=(8, 24))
        scope.bind("<<ComboboxSelected>>", lambda _event: self._clear_preview())
        ttk.Checkbutton(options, text="Compress selection to ZIP", variable=self.compress_var).grid(row=0, column=2, sticky="w")

        actions = ttk.Frame(content)
        actions.grid(row=5, column=0, sticky="ew", pady=(18, 12))
        self.preview_button = ttk.Button(actions, text="Preview Files", command=self.preview, style="Primary.TButton")
        self.preview_button.grid(row=0, column=0)
        self.extract_button = ttk.Button(actions, text="Extract Selected", command=self.extract, state="disabled", style="Primary.TButton")
        self.extract_button.grid(row=0, column=1, padx=(8, 0))

        preview_header = ttk.Frame(content)
        preview_header.grid(row=6, column=0, sticky="ew")
        preview_header.columnconfigure(0, weight=1)
        ttk.Label(preview_header, text="Preview", style="Section.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(preview_header, textvariable=self.summary_var, style="Muted.TLabel").grid(row=0, column=1, padx=(8, 12))
        ttk.Button(preview_header, text="Select All", command=self.select_all).grid(row=0, column=2)
        ttk.Button(preview_header, text="Clear", command=self.clear_selection).grid(row=0, column=3, padx=(6, 0))

        columns = ("path", "size")
        self.preview_tree = ttk.Treeview(content, columns=columns, show="headings", selectmode="extended")
        self.preview_tree.heading("path", text="File")
        self.preview_tree.heading("size", text="Size")
        self.preview_tree.column("path", minwidth=320, width=560, stretch=True)
        self.preview_tree.column("size", minwidth=90, width=110, stretch=False, anchor="e")
        self.preview_tree.grid(row=8, column=0, sticky="nsew", pady=(7, 0))
        self.preview_tree.bind("<<TreeviewSelect>>", lambda _event: self._update_selected_summary())

        status = ttk.Frame(content)
        status.grid(row=9, column=0, sticky="ew", pady=(12, 0))
        status.columnconfigure(0, weight=1)
        ttk.Label(status, textvariable=self.status_var, wraplength=680).grid(row=0, column=0, sticky="w")
        self.progress = ttk.Progressbar(status, mode="indeterminate", length=150)
        self.progress.grid(row=0, column=1, padx=(12, 0))

    def refresh_drives(self) -> None:
        self.status_var.set("Scanning connected drives...")
        self._set_busy(True)
        self._run_worker("drives", self._scan_drives)

    @staticmethod
    def _scan_drives() -> list[DriveInfo]:
        adapter = platform_adapter()
        return adapter.scan_drives() if hasattr(adapter, "scan_drives") else []

    def _drive_selected(self, _event: object = None) -> None:
        selection = self.drive_list.curselection()
        if not selection:
            return
        drive = self.drives[selection[0]]
        if drive.mount_path is None:
            self.status_var.set("This drive is visible but not mounted. Mount it in the operating system first.")
            return
        self.source_var.set(str(drive.mount_path))
        self.status_var.set(f"Source selected: {drive.name}. Preview before extracting.")
        self._clear_preview()

    def choose_source(self) -> None:
        path = filedialog.askdirectory(title="Choose a source drive or folder")
        if path:
            self.source_var.set(path)
            self.status_var.set("Source selected. Choose a destination, then preview.")
            self._clear_preview()

    def choose_destination(self) -> None:
        path = filedialog.askdirectory(title="Choose an extraction destination")
        if path:
            self.destination_var.set(path)
            self.status_var.set("Destination selected. Preview is ready when you are.")

    def preview(self) -> None:
        source = self._validated_source()
        if source is None:
            return
        self.status_var.set("Reading file names and sizes. The source is not being changed...")
        self._set_busy(True)
        self._run_worker("preview", lambda: preview_paths(source, self.scope_var.get(), include_hidden=False))

    def extract(self) -> None:
        source = self._validated_source()
        destination = self._validated_destination()
        if source is None or destination is None:
            return
        if source == destination or source in destination.parents:
            messagebox.showerror("Choose another destination", "The destination must not be inside the source folder.")
            return
        selected_ids = self.preview_tree.selection()
        if not selected_ids:
            messagebox.showinfo("Nothing selected", "Select at least one file from the preview.")
            return
        selected = frozenset(self.preview_items[int(item_id)][0] for item_id in selected_ids)
        options = ExtractionOptions(
            source=source,
            destination=destination,
            include_hidden=False,
            scope=self.scope_var.get(),
            compress=self.compress_var.get(),
            selected_paths=selected,
        )
        self.status_var.set("Copying selected files. Keep both drives connected...")
        self._set_busy(True)
        self._run_worker("extract", lambda: extract_files(options))

    def select_all(self) -> None:
        items = self.preview_tree.get_children()
        if items:
            self.preview_tree.selection_set(items)
            self._update_selected_summary()

    def clear_selection(self) -> None:
        self.preview_tree.selection_remove(self.preview_tree.selection())
        self._update_selected_summary()

    def _validated_source(self) -> Path | None:
        if not self.source_var.get():
            messagebox.showinfo("Choose a source", "Choose a connected drive or source folder first.")
            return None
        path = Path(self.source_var.get()).expanduser().resolve()
        if not path.is_dir():
            messagebox.showerror("Source unavailable", "The source is not mounted or is no longer available.")
            return None
        return path

    def _validated_destination(self) -> Path | None:
        if not self.destination_var.get():
            messagebox.showinfo("Choose a destination", "Choose where the extracted files should be saved.")
            return None
        return Path(self.destination_var.get()).expanduser().resolve()

    def _clear_preview(self) -> None:
        self.preview_items = []
        for item in self.preview_tree.get_children():
            self.preview_tree.delete(item)
        self.summary_var.set("No preview yet")
        self.extract_button.configure(state="disabled")

    def _show_preview(self, items: list[tuple[Path, int]]) -> None:
        self._clear_preview()
        self.preview_items = items
        for index, (path, size) in enumerate(items):
            self.preview_tree.insert("", "end", iid=str(index), values=(str(path), format_bytes(size)))
        if items:
            self.select_all()
            self.extract_button.configure(state="normal")
            self.status_var.set("Preview complete. Deselect anything you do not want to extract.")
        else:
            self.status_var.set("No readable files matched this file type.")

    def _update_selected_summary(self) -> None:
        selection = self.preview_tree.selection()
        total = sum(self.preview_items[int(item_id)][1] for item_id in selection)
        self.summary_var.set(f"{len(selection)} selected, {format_bytes(total)}")
        self.extract_button.configure(state="normal" if selection else "disabled")

    def _run_worker(self, kind: str, operation) -> None:
        def run() -> None:
            try:
                self.worker_messages.put((kind, operation()))
            except Exception as exc:  # GUI boundary: show actionable errors instead of crashing.
                self.worker_messages.put(("error", exc))

        threading.Thread(target=run, daemon=True).start()

    def _poll_worker(self) -> None:
        try:
            kind, payload = self.worker_messages.get_nowait()
        except queue.Empty:
            self.after(100, self._poll_worker)
            return

        self._set_busy(False)
        if kind == "drives":
            self.drives = payload  # type: ignore[assignment]
            self.drive_list.delete(0, tk.END)
            for drive in self.drives:
                detail = str(drive.mount_path) if drive.mount_path else "Not mounted"
                self.drive_list.insert(tk.END, f"{drive.name}  -  {detail}")
            self.status_var.set(f"Found {len(self.drives)} mounted drive{'s' if len(self.drives) != 1 else ''}.")
        elif kind == "preview":
            self._show_preview(payload)  # type: ignore[arg-type]
        elif kind == "extract":
            report = payload
            self.status_var.set(
                f"Finished: {report.files_copied} files copied, {report.files_failed} failed, "
                f"{format_bytes(report.bytes_copied)} written."
            )
            messagebox.showinfo("Extraction complete", self.status_var.get())
        else:
            self.status_var.set(f"Could not complete the operation: {payload}")
            messagebox.showerror("Drive Rescue Assistant", str(payload))
        self.after(100, self._poll_worker)

    def _set_busy(self, busy: bool) -> None:
        if busy:
            self.progress.start(12)
            self.preview_button.configure(state="disabled")
            self.extract_button.configure(state="disabled")
        else:
            self.progress.stop()
            self.preview_button.configure(state="normal")
            if self.preview_tree.selection():
                self.extract_button.configure(state="normal")


def main() -> int:
    app = DriveRescueDesktop()
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
