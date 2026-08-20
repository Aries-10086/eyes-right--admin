"""Eyes Right Windows entrypoint."""

from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    # Allow `python main.py` from EyesRightWin/
    root = Path(__file__).resolve().parent
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    if len(sys.argv) >= 4 and sys.argv[1] == "--cli":
        from app.pipeline import EyePipeline, PipelineError
        import cv2

        inp = Path(sys.argv[2])
        out = Path(sys.argv[3])
        try:
            result = EyePipeline().process_file(inp)
            out.parent.mkdir(parents=True, exist_ok=True)
            if not cv2.imwrite(str(out), result):
                print("保存失败", file=sys.stderr)
                return 1
            print(f"Saved: {out}")
            return 0
        except PipelineError as exc:
            print(str(exc), file=sys.stderr)
            return 1

    from app.gui import run

    run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
