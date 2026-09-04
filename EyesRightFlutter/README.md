# Eyes Right — Flutter（iOS / Android）

纯本地移动端：相册/拍照 → ONNX 检眼 →「啊啊啊 / 加一道光」贴图 → 保存相册。

## 环境

```bash
export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 运行

```bash
cd EyesRightFlutter
flutter pub get
flutter run
```

## 版本

- App：`0.1.0`
- 模型：与 Mac 共用 `pet_eye_best.onnx`

一期不做区域实时贴眼。详见仓库根目录 `Flutter跨端落地计划.md`。
