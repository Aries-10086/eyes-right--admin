#!/usr/bin/env python3
"""Evaluate eye-center error on val set (normalized by inter-eye distance)."""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / "dataset" / "pet_face_detection_dataset_1"
DEFAULT_WEIGHTS = ROOT / "runs" / "pose" / "pet_eye_v1" / "weights" / "best.pt"


def read_gt(label_path: Path, w: int, h: int) -> list[tuple[tuple[float, float], tuple[float, float]]]:
    pairs = []
    if not label_path.is_file():
        return pairs
    for line in label_path.read_text().strip().splitlines():
        parts = line.split()
        if len(parts) < 11:
            continue
        lx, ly = float(parts[5]) * w, float(parts[6]) * h
        rx, ry = float(parts[8]) * w, float(parts[9]) * h
        if lx > rx:
            lx, rx = rx, lx
            ly, ry = ry, ly
        pairs.append(((lx, ly), (rx, ry)))
    return pairs


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--weights", type=Path, default=DEFAULT_WEIGHTS)
    parser.add_argument("--split", default="val", choices=["val", "test"])
    parser.add_argument("--conf", type=float, default=0.25)
    parser.add_argument("--max-images", type=int, default=0)
    args = parser.parse_args()

    from ultralytics import YOLO

    model = YOLO(str(args.weights))
    img_dir = DATASET / "images" / args.split
    lab_dir = DATASET / "labels" / args.split

    errors: list[float] = []
    missed = 0
    images = sorted(img_dir.glob("*"))
    if args.max_images:
        images = images[: args.max_images]

    for img_path in images:
        image = cv2.imread(str(img_path))
        if image is None:
            continue
        h, w = image.shape[:2]
        gt_pairs = read_gt(lab_dir / f"{img_path.stem}.txt", w, h)
        if not gt_pairs:
            continue

        res = model(image, verbose=False, conf=args.conf)[0]
        if res.keypoints is None or len(res.keypoints) == 0:
            missed += len(gt_pairs)
            continue

        preds = []
        for kpts in res.keypoints.xy:
            if len(kpts) < 2:
                continue
            left = (float(kpts[0][0]), float(kpts[0][1]))
            right = (float(kpts[1][0]), float(kpts[1][1]))
            if left[0] > right[0]:
                left, right = right, left
            preds.append((left, right))

        for i, (gt_l, gt_r) in enumerate(gt_pairs):
            if i >= len(preds):
                missed += 1
                continue
            pl, pr = preds[i]
            gl, gr = gt_pairs[i]
            eye_dist = max(((gr[0] - gl[0]) ** 2 + (gr[1] - gl[1]) ** 2) ** 0.5, 1e-6)
            err = (
                ((pl[0] - gl[0]) ** 2 + (pl[1] - gl[1]) ** 2) ** 0.5
                + ((pr[0] - gr[0]) ** 2 + (pr[1] - gr[1]) ** 2) ** 0.5
            ) / (2 * eye_dist)
            errors.append(err)

    if not errors:
        print("No errors computed. Check weights and dataset paths.")
        return

    arr = np.array(errors)
    print(f"split={args.split}  n={len(arr)}  missed_faces={missed}")
    print(f"mean error (× eye dist): {arr.mean():.4f}")
    print(f"median: {np.median(arr):.4f}  p95: {np.percentile(arr, 95):.4f}")
    print(f"pass <5%: {(arr < 0.05).mean() * 100:.1f}%")


if __name__ == "__main__":
    main()
