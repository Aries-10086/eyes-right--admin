"""Eyes Right — Windows desktop GUI (Win10 / Win11)."""

from __future__ import annotations

import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

import cv2
import numpy as np
from PIL import Image, ImageTk

from app.pipeline import EyePipeline, PipelineError

APP_TITLE = "Eyes Right"
SUPPORTED = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff"}


class EyesRightApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title(APP_TITLE)
        self.minsize(960, 640)
        self.geometry("1100x720")
        self.configure(bg="#F7FAF9")

        self._pipeline: EyePipeline | None = None
        self._source_path: Path | None = None
        self._source_bgr: np.ndarray | None = None
        self._result_bgr: np.ndarray | None = None
        self._photo_source: ImageTk.PhotoImage | None = None
        self._photo_result: ImageTk.PhotoImage | None = None
        self._busy = False

        self._build_style()
        self._build_ui()
        self.after(50, self._load_model_async)

    def _build_style(self) -> None:
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("TFrame", background="#F7FAF9")
        style.configure("Card.TFrame", background="#FFFFFF")
        style.configure("TLabel", background="#F7FAF9", foreground="#1A2E2A", font=("Segoe UI", 11))
        style.configure("Title.TLabel", background="#F7FAF9", foreground="#0F766E", font=("Segoe UI Semibold", 20))
        style.configure("Muted.TLabel", background="#F7FAF9", foreground="#5B6F6A", font=("Segoe UI", 10))
        style.configure("Status.TLabel", background="#F7FAF9", foreground="#0F766E", font=("Segoe UI", 10))
        style.configure(
            "Accent.TButton",
            font=("Segoe UI Semibold", 11),
            padding=(16, 8),
        )
        style.map(
            "Accent.TButton",
            background=[("!disabled", "#14B8A6"), ("disabled", "#B6D5D0")],
            foreground=[("!disabled", "#FFFFFF"), ("disabled", "#F0F0F0")],
        )
        style.configure("TButton", font=("Segoe UI", 11), padding=(14, 8))

    def _build_ui(self) -> None:
        root = ttk.Frame(self, padding=20)
        root.pack(fill=tk.BOTH, expand=True)

        header = ttk.Frame(root)
        header.pack(fill=tk.X, pady=(0, 12))
        ttk.Label(header, text=APP_TITLE, style="Title.TLabel").pack(side=tk.LEFT)
        ttk.Label(header, text="本地贴眼 · Win10 / Win11", style="Muted.TLabel").pack(
            side=tk.LEFT, padx=(12, 0), pady=(8, 0)
        )

        actions = ttk.Frame(root)
        actions.pack(fill=tk.X, pady=(0, 12))
        self.btn_open = ttk.Button(actions, text="选择图片", style="Accent.TButton", command=self.open_image)
        self.btn_open.pack(side=tk.LEFT)
        self.btn_save = ttk.Button(actions, text="保存结果", command=self.save_result, state=tk.DISABLED)
        self.btn_save.pack(side=tk.LEFT, padx=(10, 0))
        self.status = ttk.Label(actions, text="正在加载模型…", style="Status.TLabel")
        self.status.pack(side=tk.LEFT, padx=(16, 0))

        panels = ttk.Frame(root)
        panels.pack(fill=tk.BOTH, expand=True)
        panels.columnconfigure(0, weight=1)
        panels.columnconfigure(1, weight=1)
        panels.rowconfigure(1, weight=1)

        ttk.Label(panels, text="原图", style="Muted.TLabel").grid(row=0, column=0, sticky="w", pady=(0, 6))
        ttk.Label(panels, text="结果", style="Muted.TLabel").grid(row=0, column=1, sticky="w", pady=(0, 6), padx=(12, 0))

        self.source_canvas = tk.Label(
            panels,
            text="点击「选择图片」或把图片拖到这里",
            bg="#FFFFFF",
            fg="#7A8B86",
            font=("Segoe UI", 12),
            relief=tk.SOLID,
            bd=1,
            highlightthickness=0,
        )
        self.source_canvas.grid(row=1, column=0, sticky="nsew", padx=(0, 6))

        self.result_canvas = tk.Label(
            panels,
            text="处理后显示在这里",
            bg="#FFFFFF",
            fg="#7A8B86",
            font=("Segoe UI", 12),
            relief=tk.SOLID,
            bd=1,
            highlightthickness=0,
        )
        self.result_canvas.grid(row=1, column=1, sticky="nsew", padx=(6, 0))

        self._enable_drop(self.source_canvas)
        self._enable_drop(self)

    def _enable_drop(self, widget: tk.Misc) -> None:
        """Optional drag-and-drop (windnd on Windows)."""
        try:
            import windnd  # type: ignore

            def _dropped(files: list) -> None:
                if not files:
                    return
                path = Path(files[0] if isinstance(files[0], str) else files[0].decode("utf-8", errors="ignore"))
                self.after(0, lambda: self.process_path(path))

            windnd.hook_dropfiles(widget, func=_dropped)
        except Exception:
            pass

    def _load_model_async(self) -> None:
        def work() -> None:
            try:
                pipeline = EyePipeline()
                self.after(0, lambda: self._on_model_ready(pipeline, None))
            except Exception as exc:  # noqa: BLE001
                self.after(0, lambda: self._on_model_ready(None, exc))

        threading.Thread(target=work, daemon=True).start()

    def _on_model_ready(self, pipeline: EyePipeline | None, error: Exception | None) -> None:
        if error is not None or pipeline is None:
            msg = str(error) if error else "模型加载失败"
            self.status.configure(text=msg)
            messagebox.showerror(APP_TITLE, msg)
            return
        self._pipeline = pipeline
        self.status.configure(text="模型已就绪，请选择图片")

    def open_image(self) -> None:
        path = filedialog.askopenfilename(
            title="选择图片",
            filetypes=[
                ("图片", "*.jpg *.jpeg *.png *.bmp *.webp *.tif *.tiff"),
                ("全部文件", "*.*"),
            ],
        )
        if path:
            self.process_path(Path(path))

    def process_path(self, path: Path) -> None:
        if self._busy:
            return
        if self._pipeline is None:
            messagebox.showinfo(APP_TITLE, "模型尚未加载完成，请稍候")
            return
        if path.suffix.lower() not in SUPPORTED:
            messagebox.showwarning(APP_TITLE, f"不支持的格式：{path.suffix}")
            return

        self._busy = True
        self.btn_open.configure(state=tk.DISABLED)
        self.btn_save.configure(state=tk.DISABLED)
        self.status.configure(text=f"处理中… {path.name}")

        def work() -> None:
            try:
                assert self._pipeline is not None
                source = cv2.imread(str(path))
                if source is None:
                    raise PipelineError(f"无法读取图片：{path.name}")
                result = self._pipeline.process_bgr(source)
                self.after(0, lambda: self._on_done(path, source, result, None))
            except Exception as exc:  # noqa: BLE001
                self.after(0, lambda: self._on_done(path, None, None, exc))

        threading.Thread(target=work, daemon=True).start()

    def _on_done(
        self,
        path: Path,
        source: np.ndarray | None,
        result: np.ndarray | None,
        error: Exception | None,
    ) -> None:
        self._busy = False
        self.btn_open.configure(state=tk.NORMAL)
        if error is not None or source is None or result is None:
            self.status.configure(text=str(error) if error else "处理失败")
            if error:
                messagebox.showerror(APP_TITLE, str(error))
            return

        self._source_path = path
        self._source_bgr = source
        self._result_bgr = result
        self._show_bgr(self.source_canvas, source, is_source=True)
        self._show_bgr(self.result_canvas, result, is_source=False)
        self.btn_save.configure(state=tk.NORMAL)
        self.status.configure(text=f"完成：{path.name}")

    def _show_bgr(self, label: tk.Label, bgr: np.ndarray, is_source: bool) -> None:
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        image = Image.fromarray(rgb)
        label.update_idletasks()
        max_w = max(label.winfo_width(), 400)
        max_h = max(label.winfo_height(), 400)
        image.thumbnail((max_w - 8, max_h - 8), Image.Resampling.LANCZOS)
        photo = ImageTk.PhotoImage(image)
        if is_source:
            self._photo_source = photo
        else:
            self._photo_result = photo
        label.configure(image=photo, text="")

    def save_result(self) -> None:
        if self._result_bgr is None:
            return
        default_name = "eyes_result.png"
        if self._source_path is not None:
            default_name = f"{self._source_path.stem}_eyes.png"
        path = filedialog.asksaveasfilename(
            title="保存结果",
            defaultextension=".png",
            initialfile=default_name,
            filetypes=[("PNG", "*.png"), ("JPEG", "*.jpg;*.jpeg")],
        )
        if not path:
            return
        out = Path(path)
        ext = out.suffix.lower()
        ok = cv2.imwrite(str(out), self._result_bgr)
        if not ok:
            messagebox.showerror(APP_TITLE, "保存失败")
            return
        if ext in {".jpg", ".jpeg"}:
            # ensure jpeg path written; OpenCV uses extension
            pass
        self.status.configure(text=f"已保存：{out.name}")


def run() -> None:
    app = EyesRightApp()
    app.mainloop()
