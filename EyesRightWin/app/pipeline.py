"""Eyes Right Windows — local ONNX pose + eye overlay pipeline."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort

OVERLAY_LEFT_EYE = (200.0, 220.0)
OVERLAY_RIGHT_EYE = (671.0, 228.0)
OVERLAY_TOTAL_WIDTH = 863.0
COVERAGE = 0.72
CONF_THRESHOLD = 0.15
INPUT_SIZE = 640


@dataclass(frozen=True)
class EyePair:
    left: tuple[float, float]
    right: tuple[float, float]
    confidence: float
    box_width: float


class PipelineError(RuntimeError):
    pass


def resource_dir() -> Path:
    """Dev tree or PyInstaller bundle."""
    import sys

    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS) / "resources"
    return Path(__file__).resolve().parent.parent / "resources"


@dataclass
class Letterbox:
    tensor: np.ndarray  # (1, 3, 640, 640) float32
    scale: float
    pad_left: float
    pad_top: float


def letterbox_bgr(image_bgr: np.ndarray, size: int = INPUT_SIZE) -> Letterbox:
    """Ultralytics-style letterbox → NCHW RGB float32 in [0, 1]."""
    h, w = image_bgr.shape[:2]
    scale = min(size / h, size / w)
    new_w = int(round(w * scale))
    new_h = int(round(h * scale))
    resized = cv2.resize(image_bgr, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
    canvas = np.full((size, size, 3), 114, dtype=np.uint8)
    pad_left = (size - new_w) // 2
    pad_top = (size - new_h) // 2
    canvas[pad_top : pad_top + new_h, pad_left : pad_left + new_w] = resized
    rgb = cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
    tensor = np.transpose(rgb, (2, 0, 1))[None, ...]
    return Letterbox(tensor=tensor, scale=scale, pad_left=float(pad_left), pad_top=float(pad_top))


def map_point(x: float, y: float, lb: Letterbox) -> tuple[float, float]:
    return (x - lb.pad_left) / lb.scale, (y - lb.pad_top) / lb.scale


class EyePipeline:
    def __init__(self, model_path: Path | None = None, overlay_path: Path | None = None) -> None:
        root = resource_dir()
        model_path = model_path or (root / "pet_eye_best.onnx")
        overlay_path = overlay_path or (root / "IMG_20260819_142559_cutout.png")
        if not model_path.is_file():
            raise PipelineError(f"找不到模型：{model_path}")
        if not overlay_path.is_file():
            raise PipelineError(f"找不到眼睛素材：{overlay_path}")

        opts = ort.SessionOptions()
        opts.log_severity_level = 3
        providers = ["CPUExecutionProvider"]
        self._session = ort.InferenceSession(str(model_path), sess_options=opts, providers=providers)
        self._input_name = self._session.get_inputs()[0].name
        overlay = cv2.imread(str(overlay_path), cv2.IMREAD_UNCHANGED)
        if overlay is None:
            raise PipelineError(f"无法读取眼睛素材：{overlay_path}")
        if overlay.ndim == 2:
            raise PipelineError("眼睛素材格式无效")
        if overlay.shape[2] == 3:
            overlay = cv2.cvtColor(overlay, cv2.COLOR_BGR2BGRA)
        self._overlay = overlay

    def detect(self, image_bgr: np.ndarray, conf: float = CONF_THRESHOLD) -> list[EyePair]:
        lb = letterbox_bgr(image_bgr)
        outputs = self._session.run(None, {self._input_name: lb.tensor})
        out = outputs[0]
        # (1, 14, 8400) → (14, 8400)
        if out.ndim == 3:
            out = out[0]
        if out.shape[0] != 14 and out.shape[1] == 14:
            out = out.T
        count = out.shape[1]
        scores = out[4]
        idxs = np.where(scores >= conf)[0]
        if idxs.size == 0:
            return []

        best_i = int(idxs[np.argmax(scores[idxs])])
        score = float(scores[best_i])
        box_w = float(out[2, best_i]) / lb.scale

        kpts: list[tuple[tuple[float, float], float]] = []
        for k in range(3):
            base = 5 + k * 3
            px, py = map_point(float(out[base, best_i]), float(out[base + 1, best_i]), lb)
            kpts.append(((px, py), float(out[base + 2, best_i])))

        left, right = kpts[0][0], kpts[1][0]
        if left[0] > right[0]:
            left, right = right, left
        kpt_conf = min(kpts[0][1], kpts[1][1])
        return [
            EyePair(
                left=left,
                right=right,
                confidence=min(score, kpt_conf),
                box_width=box_w,
            )
        ]

    def apply_overlay(self, image_bgr: np.ndarray, pair: EyePair, coverage: float = COVERAGE) -> np.ndarray:
        h, w = image_bgr.shape[:2]
        scale_boost = 1.0
        if pair.box_width > 0:
            inter_overlay = float(
                np.linalg.norm(np.array(OVERLAY_RIGHT_EYE) - np.array(OVERLAY_LEFT_EYE))
            )
            inter_real = max(
                float(np.linalg.norm(np.array(pair.right) - np.array(pair.left))),
                1e-6,
            )
            desired = pair.box_width * coverage
            base_scale = inter_real / inter_overlay
            needed = desired / OVERLAY_TOTAL_WIDTH
            scale_boost = needed / base_scale

        matrix = _similarity_matrix(
            OVERLAY_LEFT_EYE,
            OVERLAY_RIGHT_EYE,
            pair.left,
            pair.right,
            scale_boost=scale_boost,
        )
        warped = cv2.warpAffine(
            self._overlay,
            matrix,
            (w, h),
            flags=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=(0, 0, 0, 0),
        )
        base = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2BGRA).astype(np.float32)
        over = warped.astype(np.float32)
        alpha = over[:, :, 3:4] / 255.0
        out = base.copy()
        out[:, :, :3] = over[:, :, :3] * alpha + base[:, :, :3] * (1.0 - alpha)
        out[:, :, 3] = np.maximum(base[:, :, 3], over[:, :, 3])
        return cv2.cvtColor(out.astype(np.uint8), cv2.COLOR_BGRA2BGR)

    def process_bgr(self, image_bgr: np.ndarray) -> np.ndarray:
        pairs = self.detect(image_bgr)
        if not pairs:
            raise PipelineError("未检测到猫/狗脸或眼点，请换更清晰正脸照片")
        return self.apply_overlay(image_bgr, pairs[0])

    def process_file(self, input_path: Path) -> np.ndarray:
        image = cv2.imread(str(input_path))
        if image is None:
            raise PipelineError(f"无法读取图片：{input_path.name}")
        return self.process_bgr(image)


def _similarity_matrix(
    src_left: tuple[float, float],
    src_right: tuple[float, float],
    dst_left: tuple[float, float],
    dst_right: tuple[float, float],
    scale_boost: float = 1.0,
) -> np.ndarray:
    src_c = np.array(
        [(src_left[0] + src_right[0]) / 2, (src_left[1] + src_right[1]) / 2],
        dtype=np.float32,
    )
    dst_c = np.array(
        [(dst_left[0] + dst_right[0]) / 2, (dst_left[1] + dst_right[1]) / 2],
        dtype=np.float32,
    )
    src_v = np.array([src_right[0] - src_left[0], src_right[1] - src_left[1]], dtype=np.float32)
    dst_v = np.array([dst_right[0] - dst_left[0], dst_right[1] - dst_left[1]], dtype=np.float32)
    src_dist = max(float(np.linalg.norm(src_v)), 1e-6)
    dst_dist = float(np.linalg.norm(dst_v)) * scale_boost
    scale = dst_dist / src_dist
    angle = float(np.arctan2(dst_v[1], dst_v[0]) - np.arctan2(src_v[1], src_v[0]))
    cos_a = np.cos(angle) * scale
    sin_a = np.sin(angle) * scale
    tx = dst_c[0] - (cos_a * src_c[0] - sin_a * src_c[1])
    ty = dst_c[1] - (sin_a * src_c[0] + cos_a * src_c[1])
    return np.array([[cos_a, -sin_a, tx], [sin_a, cos_a, ty]], dtype=np.float32)
