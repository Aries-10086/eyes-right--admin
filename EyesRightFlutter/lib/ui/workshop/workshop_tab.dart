import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../features/app_feature.dart';
import '../../state/app_session.dart';
import '../shell/app_shell.dart';
import '../theme.dart';

/// 分区玩法墙：点选模块 → 进创作台
class WorkshopTab extends StatelessWidget {
  const WorkshopTab({super.key, required this.onOpenStudio});

  final VoidCallback onOpenStudio;

  @override
  Widget build(BuildContext context) {
    return PinkPageScaffold(
      headerTrailing: Text(
        '分区',
        style: GoogleFonts.notoSansSc(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.pink,
        ),
      ),
      child: Consumer<AppSession>(
        builder: (context, session, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(
                '玩法',
                style: GoogleFonts.notoSansSc(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '按主体选创作模块；贴图样式在首页切换',
                style: GoogleFonts.notoSansSc(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              for (final category in FeatureCategory.values) ...[
                _CategoryBlock(
                  category: category,
                  selectedId: session.selectedFeature.id,
                  onSelect: (feature) {
                    session.selectFeature(feature);
                    if (feature.isAvailable) onOpenStudio();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    required this.category,
    required this.selectedId,
    required this.onSelect,
  });

  final FeatureCategory category;
  final String selectedId;
  final ValueChanged<AppFeature> onSelect;

  @override
  Widget build(BuildContext context) {
    final modules = FeatureCatalog.modulesIn(category);
    if (modules.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.label,
          style: GoogleFonts.notoSansSc(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          category.hint,
          style: GoogleFonts.notoSansSc(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.12,
          ),
          itemBuilder: (context, index) {
            final feature = modules[index];
            return _FeatureCard(
              feature: feature,
              selected: selectedId == feature.id,
              onTap: () => onSelect(feature),
            );
          },
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.feature,
    required this.selected,
    required this.onTap,
  });

  final AppFeature feature;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = feature.isAvailable;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.pink : AppTheme.border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: available ? AppTheme.pinkSoft : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      feature.icon,
                      size: 20,
                      color: available ? AppTheme.pink : AppTheme.textHint,
                    ),
                  ),
                  const Spacer(),
                  if (feature.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: available ? AppTheme.pink : const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        feature.badge!,
                        style: GoogleFonts.notoSansSc(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: available ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                feature.title,
                style: GoogleFonts.notoSansSc(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: available ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
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
      ),
    );
  }
}
