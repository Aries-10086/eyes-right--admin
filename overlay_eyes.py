#!/usr/bin/env python3
"""Detect pet eyes with YOLOv8n-pose and overlay transparent eye PNG."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent
DEFAULT_OVERLAY = ROOT / "IMG_20260819_142559_cutout.png"
DEFAULT_WEIGHTS = ROOT / "runs" / "pose" / "pet_eye_v1" / "weights" / "best.pt"

# Overlay template eye centers (from cutout PNG)
OVERLAY_LEFT_EYE = (200.0, 220.0)
OVERLAY_RIGHT_EYE = (671.0, 228.0)


@dataclass(frozen=True)
class EyePair:
    left: tuple[float, float]
    right: tuple[float, float]
    conf: float
    box_width: float = 0.0


def load_overlay_bgra(path: Path) -> np.ndarray:
    overlay = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if overlay is None:
        raise FileNotFoundError(f"Cannot read overlay: {path}")
    if overlay.shape[2] == 3:
        overlay = cv2.cvtColor(overlay, cv2.COLOR_BGR2BGRA)
    return overlay


def detect_eye_pairs(image_bgr: np.ndarray, model, conf: float = 0.35) -> list[EyePair]:
    results = model(image_bgr, verbose=False, conf=conf)[0]
    pairs: list[EyePair] = []

    if results.keypoints is None or len(results.keypoints) == 0:
        return pairs

    boxes = results.boxes
    kpts_xy = results.keypoints.xy
    kpts_conf = results.keypoints.conf

    for i in range(len(kpts_xy)):
        pts = kpts_xy[i]
        if len(pts) < 2:
            continue
        left = (float(pts[0][0]), float(pts[0][1]))
        right = (float(pts[1][0]), float(pts[1][1]))
        if left[0] > right[0]:
            left, right = right, left

        box_conf = float(boxes.conf[i]) if boxes is not None and len(boxes) else 1.0
        kpt_conf = 1.0
        if kpts_conf is not None and len(kpts_conf[i]) >= 2:
            kpt_conf = float(min(kpts_conf[i][0], kpts_conf[i][1]))
        bw = float(boxes.xywh[i][2]) if boxes is not None and len(boxes) > i else 0.0
        pairs.append(EyePair(left=left, right=right, conf=min(box_conf, kpt_conf), box_width=bw))

    return pairs


def similarity_matrix(
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


def alpha_blend(base_bgra: np.ndarray, overlay_bgra: np.ndarray) -> np.ndarray:
    base = base_bgra.astype(np.float32)
    over = overlay_bgra.astype(np.float32)
    alpha = over[:, :, 3:4] / 255.0
    out = base.copy()
    out[:, :, :3] = over[:, :, :3] * alpha + base[:, :, :3] * (1.0 - alpha)
    out[:, :, 3] = np.maximum(base[:, :, 3], over[:, :, 3])
    return out.astype(np.uint8)


OVERLAY_TOTAL_WIDTH = 863.0  # overlay PNG width in pixels

def apply_overlay(
    image_bgr: np.ndarray,
    overlay_bgra: np.ndarray,
    pair: EyePair,
    scale_boost: float,
    coverage: float = 0.55,
) -> np.ndarray:
    """coverage: overlay width as fraction of detected face box width."""
    h, w = image_bgr.shape[:2]

    # Adaptive scale: if box_width available, compute boost so overlay
    # covers `coverage` of face width regardless of inter-eye distance.
    if pair.box_width > 0:
        inter_eye_overlay = np.linalg.norm(
            np.array(OVERLAY_RIGHT_EYE) - np.array(OVERLAY_LEFT_EYE)
        )
        inter_eye_real = max(np.linalg.norm(
            np.array(pair.right) - np.array(pair.left)
        ), 1e-6)
        desired_overlay_width = pair.box_width * coverage
        base_scale = inter_eye_real / inter_eye_overlay
        needed_scale = desired_overlay_width / OVERLAY_TOTAL_WIDTH
        adaptive_boost = needed_scale / base_scale
        scale_boost = adaptive_boost

    matrix = similarity_matrix(
        OVERLAY_LEFT_EYE,
        OVERLAY_RIGHT_EYE,
        pair.left,
        pair.right,
        scale_boost=scale_boost,
    )
    warped = cv2.warpAffine(
        overlay_bgra,
        matrix,
        (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(0, 0, 0, 0),
    )
    base_bgra = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2BGRA)
    blended = alpha_blend(base_bgra, warped)
    return cv2.cvtColor(blended, cv2.COLOR_BGRA2BGR)


def process_image(
    input_path: Path,
    output_path: Path,
    weights: Path,
    overlay_path: Path,
    scale_boost: float,
    conf: float,
    preview_path: Path | None,
    coverage: float = 0.55,
) -> int:
    from ultralytics import YOLO

    model = YOLO(str(weights))
    image_bgr = cv2.imread(str(input_path))
    if image_bgr is None:
        raise RuntimeError(f"Cannot read image: {input_path}")

    overlay_bgra = load_overlay_bgra(overlay_path)
    pairs = detect_eye_pairs(image_bgr, model, conf=conf)
    if not pairs:
        raise RuntimeError("未检测到猫/狗脸或眼点，请换更清晰正脸照片。")

    result = image_bgr.copy()
    for pair in pairs:
        result = apply_overlay(result, overlay_bgra, pair, scale_boost, coverage=coverage)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(output_path), result)

    if preview_path is not None:
        preview = result.copy()
        for pair in pairs:
            lx, ly = map(int, pair.left)
            rx, ry = map(int, pair.right)
            cv2.circle(preview, (lx, ly), 6, (0, 255, 0), 2)
            cv2.circle(preview, (rx, ry), 6, (0, 255, 0), 2)
            cv2.line(preview, (lx, ly), (rx, ry), (0, 255, 255), 2)
        cv2.imwrite(str(preview_path), preview)

    return len(pairs)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Overlay eyes on cat/dog photos using YOLOv8n-pose.")
    p.add_argument("input", type=Path, help="Input image path")
    p.add_argument("-o", "--output", type=Path, default=None)
    p.add_argument("--weights", type=Path, default=DEFAULT_WEIGHTS)
    p.add_argument("--overlay", type=Path, default=DEFAULT_OVERLAY)
    p.add_argument("--scale-boost", type=float, default=1.2, help="Fixed boost (overridden by adaptive if box detected)")
    p.add_argument("--coverage", type=float, default=0.72, help="Overlay width as fraction of face box width")
    p.add_argument("--conf", type=float, default=0.35)
    p.add_argument("--preview", type=Path, default=None, help="Debug image with eye points")
    return p


def main() -> None:
    args = build_parser().parse_args()
    output = args.output or args.input.with_name(f"{args.input.stem}_eyes{args.input.suffix}")

    if not args.weights.is_file():
        raise SystemExit(
            f"模型不存在: {args.weights}\n请先运行: python3 train_pose.py --export-onnx"
        )

    count = process_image(
        args.input,
        output,
        args.weights,
        args.overlay,
        args.scale_boost,
        args.conf,
        args.preview,
        coverage=args.coverage,
    )
    print(f"已处理 {count} 张脸，输出: {output}")
    if args.preview:
        print(f"调试图: {args.preview}")


if __name__ == "__main__":
    main()
