# Mac 客户端 App — 落地步骤（纯本地，无服务器）

## 1. 目标

做一个 **Mac 桌面 App**，全程在客户端完成：

```
用户选图 / 拖入图片
  → 本地 ONNX 推理（YOLOv8n-pose）
  → 本地贴透明眼睛 PNG
  → 预览 → 保存到本地
```

**不上传服务器、不依赖云端推理、用户电脑无需安装 Python。**

---

## 2. 已有资源

| 文件 | 用途 | 状态 |
|------|------|------|
| `runs/pose/pet_eye_v2/weights/best.pt` | 训练好的模型 | 本地有，需转 ONNX |
| `overlay_eyes.py` | 完整算法（检测 → 自适应缩放 → 贴图） | 可直接移植到 Swift |
| `IMG_20260819_142559_cutout.png` | 透明眼睛素材 | 打包进 App |
| `export_onnx.py` | ONNX 导出脚本 | 已有，待执行 |
| `coverage=0.72`, `conf=0.15` | 自适应缩放与检测阈值 | 写进 Swift 常量 |

贴图常量（与 Python 一致）：

```swift
let overlayLeftEye  = CGPoint(x: 200, y: 220)
let overlayRightEye = CGPoint(x: 671, y: 228)
let overlayTotalWidth: CGFloat = 863
let coverage: CGFloat = 0.72
let confThreshold: Float = 0.15
```

---

## 3. 还缺什么

| 项目 | 说明 |
|------|------|
| ONNX 模型文件 | 从 `best.pt` 导出，约 6~10MB |
| Xcode 工程 | Swift + SwiftUI Mac App |
| 本地推理层 | ONNX Runtime + YOLO pose 后处理 |
| 贴图层 | 从 `overlay_eyes.py` 改写成 Swift |
| Mac UI | 选图、预览、保存 |

**不需要：** 服务器、后端 API、云推理、用户登录、Python 运行时、训练脚本、数据集。

---

## 4. 推荐技术栈

**Swift + SwiftUI + ONNX Runtime**

| 组件 | 选型 | 说明 |
|------|------|------|
| UI | SwiftUI | 原生 Mac 体验 |
| 推理 | ONNX Runtime (macOS) | 支持 Apple Silicon + Intel |
| 图像处理 | Core Graphics / Core Image | 仿射变换、alpha 混合，无需 OpenCV |
| 打包 | Xcode → `.app` / `.dmg` | 标准 Mac 分发 |

### 架构

```
SwiftUI 界面
    ↓
选图 / 拖入图片（NSOpenPanel / onDrop）
    ↓
PoseDetector.swift — ONNX 推理 + YOLO 后处理
    ↓
EyeOverlay.swift — 相似变换 + alpha 混合
    ↓
预览 → NSSavePanel 保存
```

---

## 5. 工程结构（建议）

```
EyesRightMac/
├── EyesRightMac.xcodeproj
├── App/
│   ├── EyesRightMacApp.swift      # 入口
│   ├── ContentView.swift          # 主界面
│   └── PhotoPickerView.swift      # 选图 / 拖拽
├── Core/
│   ├── PoseDetector.swift         # ONNX 推理 + YOLO pose 后处理
│   ├── EyeOverlay.swift           # 贴图（从 overlay_eyes.py 移植）
│   └── ImageProcessor.swift       # 图像读写、letterbox
├── Resources/
│   ├── pet_eye_best.onnx          # 模型（App 内置）
│   └── IMG_20260819_142559_cutout.png
└── Frameworks/
    └── onnxruntime.framework      # Mac 版 ONNX Runtime
```

---

## 6. 落地步骤

### Step 1：导出 ONNX（开发机，一次性）

```bash
cd /Users/mac/Desktop/画眼睛
python3 export_onnx.py --weights runs/pose/pet_eye_v2/weights/best.pt
```

产物：`weights/pet_eye_best.onnx`  
→ 复制到 Xcode 工程的 `Resources/`。

导出后用 Python 再验一次，确保与 `best.pt` 结果一致：

```bash
python3 overlay_eyes.py test.jpg --weights runs/pose/pet_eye_v2/weights/best.pt
# 对比 ONNX 推理输出（可用 onnxruntime 脚本验证）
```

---

### Step 2：创建 Xcode 工程

1. Xcode → New Project → macOS → App
2. Interface: SwiftUI，Language: Swift
3. 勾选 App Sandbox → User Selected File（读/写）
4. 添加 ONNX Runtime：
   - 下载 [ONNX Runtime macOS release](https://github.com/microsoft/onnxruntime/releases)
   - 或 `brew install onnxruntime`（若提供 framework）
   - 拖入 `onnxruntime.framework`，Embed & Sign

---

### Step 3：本地推理层（PoseDetector.swift）

需自行实现（Python 里 Ultralytics 自动完成的部分）：

| 步骤 | 内容 |
|------|------|
| 预处理 | 读图 → resize 640×640 letterbox → 归一化 → NCHW tensor |
| 推理 | `ORTSession.run()` |
| 后处理 | NMS、解析 bbox + 3 关键点（左眼、右眼、鼻子） |
| 过滤 | `conf >= 0.15`，取 box_width 供贴图用 |

输出结构（与 Python `EyePair` 对应）：

```swift
struct EyePair {
    let left: CGPoint
    let right: CGPoint
    let conf: Float
    let boxWidth: CGFloat
}
```

---

### Step 4：贴图层（EyeOverlay.swift）

从 `overlay_eyes.py` 移植：

| Python | Swift |
|--------|-------|
| `similarity_matrix()` | `CGAffineTransform` 或手动 2×3 矩阵 |
| `apply_overlay()` 自适应 scale | `boxWidth * coverage / overlayTotalWidth` |
| `cv2.warpAffine()` | `CIImage.transformed(by:)` 或 `CGContext` |
| `alpha_blend()` | `CGContext` draw with alpha，或 `CIFilter.sourceOverCompositing` |

逻辑与 Python 保持一致：`coverage=0.72`，有 `boxWidth` 时用自适应缩放。

---

### Step 5：Mac UI

| 界面 | 功能 |
|------|------|
| 主页 | 拖入图片 / 按钮打开 NSOpenPanel |
| 处理中 | ProgressView 或简单 loading |
| 结果 | 前后对比预览 +「保存到…」（NSSavePanel） |

Mac 特性（可选）：

- 窗口 `onDrop` 接收拖拽图片
- 菜单栏：文件 → 打开 / 保存
- Dock 图标与 About 窗口

---

### Step 6：权限与打包

| 项 | 说明 |
|----|------|
| App Sandbox | 勾选 User Selected File Read/Write |
| 签名 | Apple Developer 账号；仅自用可用 ad-hoc |
| 分发 | 直接 `.app`，或打 `.dmg` |
| 预估体积 | 模型 ~10MB + ONNX Runtime ~20MB + 素材 ~1MB ≈ **30~50MB** |

---

## 7. 性能预期

| 环境 | 单张推理 |
|------|----------|
| Apple M4 CPU | ~100–300ms |
| Intel Mac | ~200–500ms |

纯本地，无网络延迟；贴图毫秒级。

---

## 8. 实施顺序与时间（单人）

| 步骤 | 内容 | 预估 |
|------|------|------|
| 1 | 导出 ONNX + Python 侧验证 | 0.5 天 |
| 2 | Xcode 工程 + 接入 ONNX Runtime | 1 天 |
| 3 | PoseDetector（推理 + YOLO 后处理） | 2~3 天 |
| 4 | EyeOverlay（贴图） | 0.5~1 天 |
| 5 | SwiftUI 界面 + 选图/保存 | 1~2 天 |
| 6 | 测试、签名、打 DMG | 0.5~1 天 |

**合计约 5~8 天** 可出可安装的 Mac App。

---

## 9. 备选方案（不推荐首选）

| 方案 | 优点 | 缺点 |
|------|------|------|
| PyInstaller 打包 Python | 1~2 天出包 | 体积 ~500MB，非原生体验 |
| Tauri + Rust | 跨平台 | Mac 原生感弱于 Swift |
| Electron | UI 好写 | 体积大、耗电 |

长期维护与 Mac 体验：**Swift + SwiftUI + ONNX Runtime** 优先。

---

## 10. 与仓库其他文档的关系

| 文档 / 脚本 | 关系 |
|-------------|------|
| `落地步骤.md` | 训练与 Python 流水线；Mac App 复用同一模型与贴图逻辑 |
| `overlay_eyes.py` | 贴图与检测阈值的参考实现 |
| `export_onnx.py` | Step 1 导出 ONNX |
| `train_pose.py` | 仅在开发机继续加练，不打包进 App |

---

## 11. 检查清单（上线前）

- [x] `pet_eye_best.onnx` 已打入 App Bundle（`EyesRightMac/Sources/EyesRightMac/Resources/`）
- [x] 素材 PNG 已打入 Resources
- [x] Swift 工程已创建（`EyesRightMac/`）
- [x] CLI 本地测试通过（`--cli input output`）
- [ ] GUI App 手动验证：拖入测试图
- [ ] 与 Python 版对比：同一张测试图眼位与大小一致
- [ ] Sandbox 下可读写用户选择的文件
- [ ] Apple Silicon / Intel 各测一台（若需双架构）

### 当前进度

Mac 客户端已落地，安装包版本 **0.2.0**：

```bash
cd EyesRightMac
./build_app.sh
# 产物：dist/EyesRight-0.2.0-arm64.dmg
# 安装：/Applications/Eyes Right.app
open -a "Eyes Right"
```

本机也可双击桌面替身「Eyes Right」。发给别人时附带 DMG 内的「如何打开.txt」。
