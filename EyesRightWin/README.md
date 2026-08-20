# Eyes Right — Windows 客户端（Win10 / Win11）

纯本地 PC App：检测猫狗眼睛并叠加透明 PNG。与 Mac 版共用同一 ONNX 模型与贴图参数（`coverage=0.72`，`conf=0.15`）。

**运行时不需要联网，不需要安装 Python（打包成 exe 后）。**

## 系统要求

- Windows 10 或 Windows 11（64 位）
- 约 200MB 磁盘（含 ONNX Runtime）

## 开发者：本机运行

```bat
cd EyesRightWin
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

命令行测试：

```bat
python main.py --cli input.jpg output.png
```

## 打包成 exe（在 Windows 上执行）

双击或在 PowerShell 中：

```bat
build_exe.bat
```

或：

```powershell
.\build_exe.ps1
```

产物：

```
dist\EyesRight\
  EyesRight.exe
  （依赖 dll / 资源）
```

把整个 **`dist\EyesRight` 文件夹打成 zip** 发给别人即可。对方解压后双击 `EyesRight.exe`。

> 当前环境是 Mac，无法在此直接打出 Windows exe；请在一台 Win10/Win11 电脑上跑打包脚本。

## 功能

- 选择图片（jpg / png / bmp / webp 等）
- Windows 下支持拖拽进窗口（需 `windnd`，打包已包含）
- 本地 ONNX 推理 + 自适应贴图
- 保存 PNG / JPEG

## 资源

| 文件 | 说明 |
|------|------|
| `resources/pet_eye_best.onnx` | 与 Mac 相同的姿态模型 |
| `resources/IMG_20260819_142559_cutout.png` | 眼睛素材 |

更新模型：把新的 `pet_eye_best.onnx` 拷进 `resources/` 后重新打包。

## 与 Mac 版对应关系

| Mac | Windows |
|-----|---------|
| `EyesRightMac/` SwiftUI | `EyesRightWin/` Python + tkinter |
| `build_app.sh` → DMG | `build_exe.bat` → `dist\EyesRight\` |
| ONNX Runtime (SPM) | onnxruntime (pip) |
