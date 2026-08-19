#!/usr/bin/env python3
"""
Train YOLOv8n-pose on pet face dataset (cat + dog, 3 keypoints).

Supports multi-round training (~30 min per round):
  Round 1:  python3 train_pose.py --epochs 20
  Round 2+: python3 train_pose.py --resume
  ...keep resuming until satisfied or early-stop triggers.
"""

from __future__ import annotations

import argparse
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATASET_DIR = ROOT / "dataset" / "pet_face_detection_dataset_1"
YAML_PATH = ROOT / "dataset" / "pet_pose.yaml"


def write_yaml() -> Path:
    """Write yaml with absolute dataset path for Ultralytics."""
    content = f"""# Auto-generated for YOLOv8n-pose pet eyes
path: {DATASET_DIR.as_posix()}
train: images/train
val: images/val
test: images/test

nc: 1
names:
  0: pet

kpt_shape: [3, 3]
flip_idx: [1, 0, 2]
"""
    YAML_PATH.write_text(content, encoding="utf-8")
    return YAML_PATH


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Train YOLOv8n-pose on cat/dog pet faces (multi-round)."
    )
    p.add_argument("--model", default="yolov8n-pose.pt", help="Base or last.pt checkpoint")
    p.add_argument("--epochs", type=int, default=20, help="Epochs THIS round (default 20≈30min on M4 CPU)")
    p.add_argument("--imgsz", type=int, default=640)
    p.add_argument("--batch", type=int, default=8, help="Lower to 4 if OOM")
    p.add_argument("--patience", type=int, default=30, help="Early stop patience (across all rounds)")
    p.add_argument("--device", default="", help="cuda:0, mps, cpu, or empty=auto")
    p.add_argument("--project", default=str(ROOT / "runs" / "pose"))
    p.add_argument("--name", default="pet_eye_v1")
    p.add_argument("--fraction", type=float, default=1.0, help="Subset for debug, e.g. 0.02")
    p.add_argument("--resume", action="store_true", help="Resume from last.pt of this run")
    p.add_argument("--export-onnx", action="store_true", help="Export best.pt to ONNX after this round")
    return p


def find_last_pt(project: str, name: str) -> Path | None:
    last = Path(project) / name / "weights" / "last.pt"
    if last.is_file():
        return last
    return None


def main() -> None:
    if not DATASET_DIR.is_dir():
        raise SystemExit(f"Dataset not found: {DATASET_DIR}")

    args = build_parser().parse_args()
    yaml_path = write_yaml()

    from ultralytics import YOLO

    # Determine starting checkpoint
    if args.resume:
        last_pt = find_last_pt(args.project, args.name)
        if last_pt is None:
            raise SystemExit(
                f"--resume 但找不到 last.pt: {Path(args.project)/args.name/'weights'/'last.pt'}\n"
                f"第一次训练请去掉 --resume"
            )
        print(f"▶ 继续训练 from: {last_pt}")
        model = YOLO(str(last_pt))
        train_kw = {
            "resume": True,
            "epochs": args.epochs,  # additional epochs on top
        }
    else:
        model = YOLO(args.model)
        train_kw = {
            "data": str(yaml_path),
            "epochs": args.epochs,
            "imgsz": args.imgsz,
            "batch": args.batch,
            "patience": args.patience,
            "project": args.project,
            "name": args.name,
            "exist_ok": True,
            "pretrained": True,
            "verbose": True,
            "hsv_h": 0.015,
            "hsv_s": 0.7,
            "hsv_v": 0.4,
            "degrees": 10.0,
            "translate": 0.1,
            "scale": 0.5,
            "fliplr": 0.5,
            "flipud": 0.0,
            "fraction": args.fraction,
        }
        if args.device:
            train_kw["device"] = args.device

    t0 = time.time()
    print(f"{'═'*50}")
    print(f"  本轮训练: epochs={args.epochs}  batch={args.batch}")
    print(f"  项目: {args.project}/{args.name}")
    print(f"  预计: ~30 min (M4 CPU, batch=8, 13.5k images)")
    print(f"{'═'*50}")

    results = model.train(**train_kw)

    elapsed = time.time() - t0
    best = Path(args.project) / args.name / "weights" / "best.pt"
    last = Path(args.project) / args.name / "weights" / "last.pt"

    print(f"\n{'═'*50}")
    print(f"  本轮完成: {elapsed/60:.1f} min")
    print(f"  best.pt: {best} ({'存在' if best.is_file() else '缺失'})")
    print(f"  last.pt: {last} ({'存在' if last.is_file() else '缺失'})")
    print(f"{'═'*50}")
    print(f"\n继续加练下一轮:")
    print(f"  python3 train_pose.py --resume")
    print(f"\n或调整 epoch 数:")
    print(f"  python3 train_pose.py --resume --epochs 30")
    print(f"\n满意后导出 ONNX:")
    print(f"  python3 export_onnx.py")

    if args.export_onnx and best.is_file():
        exported = YOLO(str(best)).export(format="onnx", opset=12, simplify=True)
        print(f"\nExported ONNX: {exported}")


if __name__ == "__main__":
    main()
