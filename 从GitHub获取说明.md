# 从 GitHub 获取 Eyes Right（Mac 应用）

仓库地址：

```
git@github.com:Aries-10086/eyes-right--admin.git
```

HTTPS：

```
https://github.com/Aries-10086/eyes-right--admin
```

---

## 先搞清楚：你要哪一种？

| 目的 | 推荐方式 | 要不要从 GitHub 拉代码 |
|------|----------|------------------------|
| **只想用 App，不想编译** | 让作者发你 **DMG 安装包**（`EyesRight-0.2.0-arm64.dmg`） | 不需要 |
| **自己编译 / 改代码 / 二次开发** | 从 GitHub 克隆仓库，进入 `EyesRightMac/` 构建 | 需要 |

> **说明：** DMG 安装包体积约 19MB，**没有放进 GitHub**（在 `.gitignore` 里）。GitHub 上存的是**源码 + 模型 + 构建脚本**，拉下来后需要在本机编译一次。

---

## 方式一：直接用（推荐给普通用户）

1. 向作者索取 `EyesRight-0.2.0-arm64.dmg`
2. 双击打开 DMG，把 **Eyes Right** 拖到 **Applications**
3. 若提示「无法验证开发者」，看 DMG 里的 **`如何打开.txt`**（仓库根目录也有同名文件）

**系统要求：** Apple 芯片 Mac（M1/M2/M3/M4），macOS 13+

---

## 方式二：从 GitHub 拉源码自己构建

### 需要拉哪些文件？

**最简单：拉整个 `EyesRightMac/` 文件夹即可**，不要只挑几个 Swift 文件——缺任何一项都编不过。

下面这张表对应 GitHub 上**已提交**的全部 Mac 客户端文件（共 21 个）：

```
EyesRightMac/
├── Package.swift              # Swift 工程定义、依赖（ONNX Runtime）
├── Package.resolved           # 依赖版本锁定
├── Info.plist                 # App 版本、图标等
├── build_app.sh               # 一键编译、打包 DMG、安装
├── README.md                  # Mac 端说明
├── 如何打开.txt               # 发给朋友：Gatekeeper 打开方法
└── Sources/EyesRightMac/
    ├── main.swift
    ├── EyesRightMacApp.swift
    ├── ContentView.swift
    ├── AppViewModel.swift
    ├── PhotoDropTarget.swift
    ├── Theme.swift
    ├── Core/
    │   ├── AppResources.swift
    │   ├── EyeOverlay.swift
    │   ├── EyePair.swift
    │   ├── ImageProcessor.swift
    │   ├── Pipeline.swift
    │   └── PoseDetector.swift
    └── Resources/
        ├── pet_eye_best.onnx          # 推理模型（约 12MB，已在仓库里）
        ├── IMG_20260819_142559_cutout.png   # 眼睛贴图素材
        └── AppIcon.icns               # App 图标
```

**不必单独拉：** 仓库根目录的 Python 训练脚本（`overlay_eyes.py`、`train_pose.py` 等）——**跑 Mac App 用不到**。

**GitHub 上没有、本地构建才会生成：**

| 路径 | 说明 |
|------|------|
| `dist/*.dmg` | 安装包（执行 `build_app.sh` 后生成） |
| `Eyes Right.app` | 编译产物 |
| `.build/` | Swift 编译缓存 |

---

### 克隆命令

**整仓克隆（推荐）：**

```bash
git clone https://github.com/Aries-10086/eyes-right--admin.git
cd eyes-right--admin/EyesRightMac
```

**只要 Mac 客户端（稀疏检出，省流量）：**

```bash
git clone --filter=blob:none --sparse https://github.com/Aries-10086/eyes-right--admin.git
cd eyes-right--admin
git sparse-checkout set EyesRightMac
cd EyesRightMac
```

---

### 构建与运行

**环境要求：**

- macOS 13 或更高
- Apple 芯片 Mac（当前版本仅 arm64）
- Xcode 或 Xcode Command Line Tools（含 Swift 5.9+）
- 首次构建需联网（Swift Package Manager 会自动下载 ONNX Runtime）

**一键构建：**

```bash
cd EyesRightMac
chmod +x build_app.sh
./build_app.sh
```

脚本会：

1. Release 编译
2. 生成 `Eyes Right.app`
3. 打出 `dist/EyesRight-0.2.0-arm64.dmg`
4. 安装到 `/Applications/Eyes Right.app`
5. 在桌面创建「Eyes Right」替身

**打开 App：**

```bash
open -a "Eyes Right"
```

**无界面命令行测试：**

```bash
swift build -c release
.build/release/EyesRightMac --cli 输入图.jpg 输出.png
```

---

### 分发给别人

自己构建完成后，把 **`dist/EyesRight-0.2.0-arm64.dmg`** 和 **`如何打开.txt`** 一并发给对方即可；对方**不需要**再访问 GitHub。

当前版本为 **临时签名（adhoc）**，别人电脑上可能提示「无法验证开发者」——按 `如何打开.txt` 里「右键 → 打开」即可。

---

## 常见问题

**Q：为什么克隆下来没有 `.dmg`？**  
A：安装包是构建产物，体积大，故意不提交到 Git。本地执行 `./build_app.sh` 后会出现在 `dist/`。

**Q：模型文件在不在仓库里？**  
A：在。`EyesRightMac/Sources/EyesRightMac/Resources/pet_eye_best.onnx` 已跟踪，克隆后自带，无需再训练或导出。

**Q：Intel Mac 能用吗？**  
A：当前构建脚本和 DMG 仅支持 **Apple Silicon (arm64)**。

**Q：需要装 Python 吗？**  
A：不需要。Mac App 运行时纯本地 Swift + ONNX，与仓库里的 Python 脚本无关。

---

## 相关文档

| 文件 | 内容 |
|------|------|
| `EyesRightMac/README.md` | Mac 端功能与构建说明 |
| `如何打开.txt` | 无法打开 App 时的操作步骤 |
| `Mac客户端落地步骤.md` | 开发与架构说明（给维护者看） |
