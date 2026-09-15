import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../features/app_feature.dart';
import '../../state/app_session.dart';
import '../shell/app_shell.dart';
import '../theme.dart';

/// 首页看板：入口卡片，真正贴图在「创作」页
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onOpenStudio, required this.onOpenWorkshop});

  final VoidCallback onOpenStudio;
  final VoidCallback onOpenWorkshop;

  @override
  Widget build(BuildContext context) {
    return PinkPageScaffold(
      headerTrailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          '首页',
          style: GoogleFonts.notoSansSc(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.pink,
          ),
        ),
      ),
      child: Consumer<AppSession>(
        builder: (context, session, _) {
          final create = FeatureCatalog.modulesIn(FeatureCategory.create)
              .where((f) => f.isAvailable)
              .toList();
          final tools = FeatureCatalog.modulesIn(FeatureCategory.tools)
              .where((f) => f.isAvailable)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(
                '本地贴图，选主体开始',
                style: GoogleFonts.notoSansSc(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '照片只在本机处理。点卡片进入创作台。',
                style: GoogleFonts.notoSansSc(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              _SectionLabel(title: '开始创作', hint: '进入创作台选图贴图'),
              const SizedBox(height: 10),
              for (final feature in create) ...[
                _StartCard(
                  feature: feature,
                  selected: session.selectedFeature.id == feature.id,
                  onTap: () {
                    session.selectFeature(feature);
                    onOpenStudio();
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (tools.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionLabel(title: '工具', hint: '配合创作使用'),
                const SizedBox(height: 10),
                for (final feature in tools) ...[
                  _StartCard(
                    feature: feature,
                    selected: session.selectedFeature.id == feature.id,
                    onTap: () {
                      session.selectFeature(feature);
                      onOpenStudio();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 6),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onOpenWorkshop,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.grid_view_rounded, color: AppTheme.pink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '浏览全部玩法',
                                style: GoogleFonts.notoSansSc(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '即将上线与素材规划也在这里',
                                style: GoogleFonts.notoSansSc(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.notoSansSc(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hint,
            style: GoogleFonts.notoSansSc(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.feature,
    required this.selected,
    required this.onTap,
  });

  final AppFeature feature;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.pink : AppTheme.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.pinkSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(feature.icon, color: AppTheme.pink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: GoogleFonts.notoSansSc(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feature.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansSc(
                        fontSize: 12,
                        height: 1.3,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_circle_right_rounded, color: AppTheme.pink.withValues(alpha: 0.85)),
            ],
          ),
        ),
      ),
    );
  }
}
