#!/usr/bin/env python3
"""Export trained pose model to ONNX."""

from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_PT = ROOT / "runs" / "pose" / "pet_eye_v1" / "weights" / "best.pt"
OUT_DIR = ROOT / "weights"


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--weights", type=Path, default=DEFAULT_PT)
    p.add_argument("--out-dir", type=Path, default=OUT_DIR)
    args = p.parse_args()

    if not args.weights.is_file():
        raise SystemExit(f"Not found: {args.weights}")

    from ultralytics import YOLO

    args.out_dir.mkdir(parents=True, exist_ok=True)
    out_path = args.out_dir / "pet_eye_best.onnx"
    exported = YOLO(str(args.weights)).export(format="onnx", opset=12, simplify=True)
    # ultralytics exports next to weights; copy to weights/
    src = Path(exported)
    if src.resolve() != out_path.resolve():
        out_path.write_bytes(src.read_bytes())
    print(f"ONNX: {out_path}")


if __name__ == "__main__":
    main()
