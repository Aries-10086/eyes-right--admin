# Eyes Right — Mac 客户端

纯本地 Mac App：检测猫狗眼睛并叠加透明 PNG，无需 Python、无需联网。

## 一键打包 / 安装

```bash
cd EyesRightMac
./build_app.sh
```

会自动完成：

1. Release 编译
2. 生成 `Eyes Right.app`
3. 打出 DMG：`dist/EyesRight-0.2.1-arm64.dmg`
4. 安装到 `/Applications/Eyes Right.app`
5. 在桌面创建「Eyes Right」替身

打开：

```bash
open -a "Eyes Right"
```

## 分发说明

当前版本：**0.2.1**（build 3）

| 文件 | 用途 |
|------|------|
| `Eyes Right.app` | 可直接运行 |
| `dist/EyesRight-0.2.1-arm64.dmg` | 发给别人：打开后拖到 Applications |
| 桌面替身 | 双击启动（指向 Applications 里的 App） |

### 0.2.1 更新内容

- 修复 letterbox 预处理导致部分照片检测失败
- 修复 CG 贴图坐标系，与原模型 Python 输出对齐
- 贴图逻辑与训练模型一致（不做额外眼点校正）

### 0.2.0 更新内容

- 自定义 App 图标（眼睛素材裁剪）
- 亮色界面 + 流萤印象配色
- DMG 安装包 + 桌面替身
- 本地 ONNX 推理与自适应贴图

当前限制：

- 仅 **Apple Silicon (arm64)**
- **临时签名（adhoc）**，别人电脑可能提示「无法验证开发者」→ 见 `如何打开.txt`

## CLI 测试（无界面）

```bash
swift build -c release
.build/release/EyesRightMac --cli input.jpg output.png
```

## 功能

- 拖入或选择图片
- 本地 ONNX 推理（YOLOv8n-pose）
- 按脸框宽度自适应贴图（coverage=0.72）
- 保存 PNG/JPEG

## 依赖

- macOS 13+
- Swift 5.9+
- ONNX Runtime（SPM 自动拉取）

## 资源

| 文件 | 说明 |
|------|------|
| `Resources/pet_eye_best.onnx` | 训练模型 |
| `Resources/IMG_20260819_142559_cutout.png` | 眼睛素材 |

更新模型：

```bash
cp ../weights/pet_eye_best.onnx Sources/EyesRightMac/Resources/
```
