import 'package:flutter/material.dart';

import '../models/eye_models.dart';

/// 可扩展功能模块（对齐 B 站「分区 / 频道」思路：先登记，再进首页创作）
enum FeatureStatus { live, beta, comingSoon }

/// 玩法墙分区：创作（按主体）/ 工具 / 规划
enum FeatureCategory {
  create('创作', '先选主体，再在首页切换贴图样式'),
  tools('工具', '辅助能力，配合创作使用'),
  soon('即将上线', '规划中，敬请期待');

  const FeatureCategory(this.label, this.hint);
  final String label;
  final String hint;
}

class AppFeature {
  const AppFeature({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.category,
    this.badge,
    this.faceKind = FaceKind.pet,
    this.stickerModes = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final FeatureStatus status;
  final FeatureCategory category;
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
      id: 'pet_stickers',
      title: '宠物贴图',
      subtitle: '猫狗正脸 · 啊啊啊 / 加一道光 / 小丑鼻子',
      icon: Icons.pets_rounded,
      status: FeatureStatus.live,
      category: FeatureCategory.create,
      badge: '热门',
      faceKind: FaceKind.pet,
      stickerModes: [
        OverlayMode.ahAhAh,
        OverlayMode.addLight,
        OverlayMode.clownNose,
      ],
    ),
    AppFeature(
      id: 'anime_eyes',
      title: '动漫贴眼',
      subtitle: '二次元正脸 · 啊啊啊 / 加一道光',
      icon: Icons.face_retouching_natural_rounded,
      status: FeatureStatus.live,
      category: FeatureCategory.create,
      badge: '新品',
      faceKind: FaceKind.anime,
      stickerModes: [OverlayMode.ahAhAh, OverlayMode.addLight],
    ),
    AppFeature(
      id: 'region_live',
      title: '区域贴眼',
      subtitle: '框选屏幕区域，实时叠加当前贴图',
      icon: Icons.crop_free_rounded,
      status: FeatureStatus.comingSoon,
      category: FeatureCategory.tools,
      badge: '电脑端',
    ),
    AppFeature(
      id: 'batch',
      title: '批量贴眼',
      subtitle: '一次处理多张照片',
      icon: Icons.collections_rounded,
      status: FeatureStatus.comingSoon,
      category: FeatureCategory.soon,
      badge: '即将上线',
    ),
    AppFeature(
      id: 'video_frame',
      title: '视频抽帧',
      subtitle: '从视频截取正脸再贴图',
      icon: Icons.movie_filter_rounded,
      status: FeatureStatus.comingSoon,
      category: FeatureCategory.soon,
      badge: '即将上线',
    ),
    AppFeature(
      id: 'sticker_shop',
      title: '贴图工坊',
      subtitle: '更多眼罩与素材包',
      icon: Icons.storefront_rounded,
      status: FeatureStatus.comingSoon,
      category: FeatureCategory.soon,
      badge: '策划中',
    ),
  ];

  static AppFeature byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => all.first);

  static List<AppFeature> get live =>
      all.where((f) => f.status == FeatureStatus.live).toList();

  static List<AppFeature> modulesIn(FeatureCategory category) =>
      all.where((f) => f.category == category).toList();
}
