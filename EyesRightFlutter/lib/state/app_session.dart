import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import '../features/app_feature.dart';
import '../models/eye_models.dart';
import '../pipeline/eye_pipeline.dart';

enum PreviewTab { source, result }

/// 跨 Tab 共享会话：首页创作 / 玩法选模块 / 我的 共用
class AppSession extends ChangeNotifier {
  AppSession() {
    selectedFeature = FeatureCatalog.live.first;
    stickerMode = selectedFeature.defaultSticker ?? OverlayMode.ahAhAh;
    _initPipeline();
  }

  final ImagePicker _picker = ImagePicker();
  EyePipeline? _pipeline;

  AppFeature selectedFeature = FeatureCatalog.live.first;
  OverlayMode stickerMode = OverlayMode.ahAhAh;
  PreviewTab previewTab = PreviewTab.source;
  Uint8List? sourceBytes;
  Uint8List? resultBytes;
  String status = '正在加载模型…';
  bool busy = false;
  bool ready = false;

  FaceKind get faceKind => selectedFeature.faceKind;

  Future<void> _initPipeline() async {
    try {
      final pipeline = await EyePipeline.create();
      _pipeline = pipeline;
      ready = true;
      status = '选一张正脸照，本地贴眼不上传';
    } catch (e) {
      ready = false;
      status = '模型加载失败：$e';
    }
    notifyListeners();
  }

  void selectFeature(AppFeature feature) {
    if (!feature.isAvailable) {
      status = '「${feature.title}」即将上线，先试试首页可用玩法';
      notifyListeners();
      return;
    }
    selectedFeature = feature;
    if (feature.defaultSticker != null) {
      stickerMode = feature.defaultSticker!;
    }
    resultBytes = null;
    previewTab = PreviewTab.source;
    status = '已选择「${feature.title}」，去首页开始创作';
    notifyListeners();
  }

  void setStickerMode(OverlayMode mode) {
    if (!selectedFeature.stickerModes.contains(mode)) return;
    if (stickerMode == mode) return;
    stickerMode = mode;
    resultBytes = null;
    previewTab = PreviewTab.source;
    status = '贴图样式 · ${mode.label}';
    notifyListeners();
  }

  void setPreviewTab(PreviewTab tab) {
    previewTab = tab;
    notifyListeners();
  }

  Future<void> pick(ImageSource source) async {
    if (!ready || busy) return;
    final file = await _picker.pickImage(source: source, imageQuality: 95);
    if (file == null) return;
    sourceBytes = await file.readAsBytes();
    resultBytes = null;
    previewTab = PreviewTab.source;
    status = '已选图，点「开始贴眼」';
    notifyListeners();
  }

  Future<void> process() async {
    final pipeline = _pipeline;
    final source = sourceBytes;
    if (pipeline == null || source == null || busy) return;
    if (!selectedFeature.isAvailable || !selectedFeature.canProcess) {
      status = '当前玩法暂不可用';
      notifyListeners();
      return;
    }

    busy = true;
    status = '检测中，请稍候…';
    resultBytes = null;
    notifyListeners();

    try {
      final result = await pipeline.processBytes(
        source,
        stickerMode,
        faceKind: faceKind,
      );
      resultBytes = result;
      previewTab = PreviewTab.result;
      final tag = faceKind == FaceKind.anime
          ? '动漫·${stickerMode.label}'
          : selectedFeature.title;
      status = '贴眼完成 · $tag';
    } catch (e) {
      status = e is PipelineException ? e.message : '处理失败：$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> save() async {
    final bytes = resultBytes;
    if (bytes == null || busy) return '没有可保存的结果';
    try {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        status = '需要相册写入权限才能保存';
        notifyListeners();
        return status;
      }
      await Gal.putImageBytes(
        bytes,
        name: 'eyes_right_${DateTime.now().millisecondsSinceEpoch}',
      );
      status = '已保存到相册';
      notifyListeners();
      return null;
    } catch (e) {
      status = '保存失败：$e';
      notifyListeners();
      return status;
    }
  }

  @override
  void dispose() {
    _pipeline?.dispose();
    super.dispose();
  }
}
