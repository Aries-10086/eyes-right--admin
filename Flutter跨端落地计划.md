# Eyes Right — Flutter 跨端（iOS / Android）落地计划

## 1. 目标

用 **Flutter** 做一套可同时上架/分发的移动端 App：用户从相册选图（或拍照），**纯本地**用现有 `pet_eye_best.onnx` 检测猫/狗眼点，叠加「啊啊啊 / 加一道光」贴图，预览并保存到相册。

**一期不做：** 区域实时贴眼、云端上传、账号体系、视频逐帧处理、Windows/Mac 桌面 Flutter 化。

桌面端（`EyesRightMac` / `EyesRightWin`）继续独立维护；移动端与桌面 **共用模型与贴图规则**，UI 与打包分开。

---

## 2. 范围与非目标

| 纳入（一期） | 不纳入（一期） |
|-------------|----------------|
| iOS 15+、Android 8+（API 26+）建议下限 | 区域采集 / 悬浮实时贴眼 |
| 相册选图 + 可选拍照 | 改训练流程 / 换新模型结构 |
| ONNX 本地推理（复用 `pet_eye_best.onnx`） | 云端推理、用户数据上报 |
| 「啊啊啊」「加一道光」两种模式 | 批量多图流水线（可二期） |
| 预览、保存到相册、基础失败提示 | 完整设计系统重做、社交分享 SDK |
| 中文界面、本地隐私说明 | 与 Mac 像素级 UI 一致 |

---

## 3. 总体架构

```
相册 / 相机
    ↓
解码为位图（注意 EXIF 方向）
    ↓
letterbox → 640 → ONNX Runtime（移动端）
    ↓
解析 pose 关键点 → EyePair（左眼 / 右眼 / boxWidth）
    ↓
按 OverlayMode 合成贴图（对齐现有 Mac/Python 规则）
    ↓
预览 → 保存相册 / 分享系统面板（可选）
```

与现有桌面静态图链路对齐：

| 环节 | Mac / Win（现有） | Flutter 一期 |
|------|-------------------|--------------|
| 输入 | 文件 / 拖图 | 相册 / 拍照 |
| 检测 | PoseDetector + ONNX | 同模型，ort mobile |
| 贴图 | EyeOverlay 两种模式 | Dart/原生绘制，规则一致 |
| 输出 | 预览 / 另存 | 预览 / 写入相册 |
| 实时区域 | Mac 已有（本期跨端忽略） | 不做 |

---

## 4. 技术选型

| 模块 | 推荐 | 说明 |
|------|------|------|
| UI | **Flutter 3.x** | 一套代码出 iOS / Android |
| 状态 | 轻量即可（如 `Riverpod` 或 `Provider`） | 流程短，避免过度架构 |
| 选图/拍照 | `image_picker` | 权限文案要写清「仅本地处理」 |
| 图片编解码 | `image` / `flutter_image_compress`（按需） | **必须纠正 EXIF orientation** |
| 推理 | **ONNX Runtime Mobile**（官方或成熟 FFI 插件） | 优先复用现有 `.onnx`，少做格式分叉 |
| 贴图绘制 | Dart `Canvas` / `Image` 合成，或 FFI 调共享绘制 | 一期可用 Dart 对齐公式；瓶颈再下沉 |
| 存相册 | `gal` / `image_gallery_saver` 类插件 | iOS/Android 权限分流 |
| 资源 | 模型 + 两张贴图素材进 `assets/` | 与 Mac `Resources` 同源 |

备选（仅当 ort 插件卡死时）：导出 **Core ML（iOS）+ TFLite（Android）** —— 成本高，作 Plan B，不作为一期默认。

---

## 5. 功能拆解

### 5.1 主流程

1. 启动 → 加载模型（失败则明确提示）  
2. 选图 / 拍照  
3. 选择模式：「啊啊啊」|「加一道光」  
4. 一键处理（可显示进度）  
5. 原图 / 结果对比预览  
6. 保存到相册；未检出眼点时提示换更清晰正脸图  

### 5.2 与现有逻辑对齐（验收标准）

用同一批测试图（仓库内已有样例）对比 Mac 输出：

- 检出成功/失败一致（允许置信边界少量差异）  
- 贴图中心、尺度、左右眼关系肉眼接近  
- 「加一道光」：**右眼不镜像**；半跨距 / 覆盖比例与现网常量一致  

建议把 Mac 侧常量抽成「规格说明」写进计划附录（`coverage`、`perEyeHalfSpanFromBox` 等），Flutter 按同一数字实现。

### 5.3 权限与隐私

- 相册读取、（可选）相机、写入相册  
- 文案统一：**完全本地、不上传**  
- 系统权限弹窗与应用内说明页各一份  

### 5.4 非功能

- 中等手机单张推理目标：约 **1–3 s 内出图**（视机型）  
- 大图先最长边限制（如 2048）再推理，避免 OOM  
- 不在一期做后台保活、推送  

---

## 6. 仓库与工程结构（建议）

在现有 monorepo 新增目录，不改动桌面端行为：

```
EyesRightFlutter/          # 或 apps/mobile/
  pubspec.yaml
  lib/
    main.dart
    app.dart
    ui/                    # 首页、预览、模式切换
    pipeline/              # letterbox、decode、compose
    inference/             # ONNX session 封装
    models/                # EyePair、OverlayMode
  assets/
    models/pet_eye_best.onnx
    overlays/...
  ios/
  android/
```

版本号建议与产品线对齐（例如移动端从 **0.1.0** 起，功能对齐桌面静态图能力后再考虑与桌面大版本同步）。

---

## 7. 里程碑与工期（参考）

| 阶段 | 交付 | 估时 |
|------|------|------|
| M0 脚手架 | Flutter 工程、主题壳、选图页、空管道 | 0.5–1 天 |
| M1 推理接通 | ort 加载模型、letterbox、解析关键点、调试可视化（画点） | 1.5–2 天 |
| M2 贴图对齐 | 两种模式合成；与 Mac 样例对比调参 | 1.5–2 天 |
| M3 产品闭环 | 预览、保存相册、错误文案、权限、简单 loading | 1 天 |
| M4 双端发包 | iOS 真机 / Android 真机；TestFlight 或内测包 | 1–1.5 天 |
| **合计** | 可内测的双端相册版 | **约 5–8 人天** |

风险缓冲：ORT 插件兼容性、iOS 签名与相册权限、大图内存 —— 预留 **+2 天**。

---

## 8. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| Flutter ORT 插件不成熟 / ABI 问题 | 卡住推理 | 先做最小 FFI 自封装；Plan B 双格式导出 |
| EXIF 未旋转 | 贴偏、检不出 | 解码统一 `bake` 方向 |
| 坐标 Y 轴与 Mac/OpenCV 不一致 | 贴偏 | 以现有 Mac/Python 为金标准写对照测试 |
| 大图 OOM | 闪退 | 推理前缩放；原图仅用于最终合成 |
| 商店审核（相册用途） | 拒审 | 隐私政策 + 本地处理说明；无隐蔽采集 |
| 与桌面行为漂移 | 用户投诉「手机版不准」 | 固定测试集 + 对照截图进 CI/手工清单 |

---

## 9. 验收清单（一期）

- [ ] iPhone / 主流 Android 真机：选图 → 两种模式出图 → 保存成功  
- [ ] 未检出时有明确中文提示，不白屏  
- [ ] 断网可用（飞行模式抽测）  
- [ ] 与 Mac 同图对比：贴图位置/模式行为基本一致  
- [ ] 权限拒绝时有引导，不崩溃  
- [ ] 安装包体积可接受（模型约 12MB 级，需在说明里写明）  

---

## 10. 二期（明确延后）

- 区域实时贴眼（Android 悬浮窗可评估；iOS 基本不做系统级盖层）  
- 批量处理、视频抽帧  
- 更多贴图包 / 商城  
- Flutter 桌面（意义有限，已有原生 Mac/Win）  
- 统一设计语言跨三端  

---

## 11. 决策摘要

| 项 | 决定 |
|----|------|
| 跨端框架 | **Flutter** |
| 一期范围 | **仅静态图贴眼**（对齐现有桌面静态流程） |
| 模型 | **继续 ONNX** `pet_eye_best.onnx` |
| 与桌面关系 | **并行产品线**，共享算法规格，代码仓可 monorepo |
| 区域贴眼 | **不在本期** |

---

## 12. 建议下一步（仍可不写业务代码）

1. 确认最低系统版本与是否要上架 App Store / 国内安卓商店（影响证书与包名）  
2. 定包名 / Bundle ID（如 `com.eyesright.mobile`）  
3. 拉一份「贴图常量规格」从 Mac `OverlayConstants` 固化成文档  
4. 再开工：`flutter create` + 接通 ORT 最小推理 Demo  

确认本计划后，可按 M0→M4 开工。

---

## 13. 实施进度（2026-09-03）

| 阶段 | 状态 | 说明 |
|------|------|------|
| M0 脚手架 | ✅ | `EyesRightFlutter/` 已创建，资源与中文壳页就绪 |
| M1 推理 | ✅ 代码完成 | `PoseDetector` + letterbox；需真机验证 |
| M2 贴图 | ✅ 代码完成 | 两种模式常量对齐 Mac |
| M3 闭环 | ✅ 代码完成 | 相册/拍照/保存/错误文案 |
| M4 发包 | ⏳ | 本机缺完整 Xcode / Android SDK，待装工具链后真机跑 |

运行：

```bash
export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
cd EyesRightFlutter && flutter pub get && flutter run
```
