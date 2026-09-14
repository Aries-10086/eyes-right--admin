import 'package:flutter/material.dart';

import '../models/eye_models.dart';

/// 可扩展功能模块（对齐 B 站「分区 / 频道」思路：先登记，再进首页创作）
enum FeatureStatus { live, beta, comingSoon }

class AppFeature {
  const AppFeature({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    this.badge,
    this.faceKind = FaceKind.pet,
    this.stickerModes = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final FeatureStatus status;
  final String? badge;
  final FaceKind faceKind;
  final List<OverlayMode> stickerModes;

  bool get isAvailable => status != FeatureStatus.comingSoon;
  OverlayMode? get defaultSticker =>
      stickerModes.isEmpty ? null : stickerModes.first;
  bool get hasStickerPicker => stickerModes.length >= 2;
  bool get canProcess => defaultSticker != null;
}

/// 新功能只在这里登记即可出现在「玩法」页
class FeatureCatalog {
  static const List<AppFeature> all = [
    AppFeature(
      id: 'ah_ah_ah',
      title: '啊啊啊',
      subtitle: '宠物双眼一体眼罩贴图',
      icon: Icons.visibility_rounded,
      status: FeatureStatus.live,
      badge: '热门',
      faceKind: FaceKind.pet,
      stickerModes: [OverlayMode.ahAhAh],
    ),
    AppFeature(
      id: 'add_light',
      title: '加一道光',
      subtitle: '宠物左右眼各贴同一张图',
      icon: Icons.auto_awesome_rounded,
      status: FeatureStatus.live,
      badge: '推荐',
      faceKind: FaceKind.pet,
      stickerModes: [OverlayMode.addLight],
    ),
    AppFeature(
      id: 'clown_nose',
      title: '小丑鼻子',
      subtitle: '识别鼻尖贴上红色小丑鼻',
      icon: Icons.sentiment_very_satisfied_rounded,
      status: FeatureStatus.live,
      badge: '新品',
      faceKind: FaceKind.pet,
      stickerModes: [OverlayMode.clownNose],
    ),
    AppFeature(
      id: 'anime_eyes',
      title: '动漫贴眼',
      subtitle: '二次元脸检测，可选啊啊啊 / 加一道光',
      icon: Icons.face_retouching_natural_rounded,
      status: FeatureStatus.live,
      badge: '新品',
      faceKind: FaceKind.anime,
      stickerModes: [OverlayMode.ahAhAh, OverlayMode.addLight],
    ),
    AppFeature(
      id: 'region_live',
      title: '区域贴眼',
      subtitle: '框选屏幕区域实时贴图',
      icon: Icons.crop_free_rounded,
      status: FeatureStatus.comingSoon,
      badge: '电脑端',
    ),
    AppFeature(
      id: 'batch',
      title: '批量贴眼',
      subtitle: '一次处理多张照片',
      icon: Icons.collections_rounded,
      status: FeatureStatus.comingSoon,
      badge: '即将上线',
    ),
    AppFeature(
      id: 'video_frame',
      title: '视频抽帧',
      subtitle: '从视频截取正脸再贴眼',
      icon: Icons.movie_filter_rounded,
      status: FeatureStatus.comingSoon,
      badge: '即将上线',
    ),
    AppFeature(
      id: 'sticker_shop',
      title: '贴图工坊',
      subtitle: '更多眼罩与素材包',
      icon: Icons.storefront_rounded,
      status: FeatureStatus.comingSoon,
      badge: '策划中',
    ),
  ];

  static AppFeature byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => all.first);

  static List<AppFeature> get live =>
      all.where((f) => f.status == FeatureStatus.live).toList();
}
