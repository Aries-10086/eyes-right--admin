import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../features/app_feature.dart';
import '../../state/app_session.dart';
import '../shell/app_shell.dart';
import '../theme.dart';

class MineTab extends StatelessWidget {
  const MineTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PinkPageScaffold(
      headerTrailing: Text(
        '我的',
        style: GoogleFonts.notoSansSc(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.pink,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _ProfileCard(),
          const SizedBox(height: 14),
          _Section(
            title: '关于',
            children: [
              _InfoTile(
                icon: Icons.lock_outline_rounded,
                title: '完全本地处理',
                subtitle: '照片与推理不上传云端',
              ),
              _InfoTile(
                icon: Icons.phone_iphone_rounded,
                title: '版本',
                subtitle: 'Eyes Right Mobile 0.1.0',
              ),
              _InfoTile(
                icon: Icons.extension_outlined,
                title: '已上线玩法',
                subtitle: FeatureCatalog.live.map((f) => f.title).join(' · '),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Consumer<AppSession>(
            builder: (_, session, __) {
              return _Section(
                title: '当前选择',
                children: [
                  _InfoTile(
                    icon: session.selectedFeature.icon,
                    title: session.selectedFeature.title,
                    subtitle: session.selectedFeature.subtitle,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            '新功能会先出现在「玩法」分区，再接入首页创作流。',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansSc(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppTheme.pink, AppTheme.pinkDeep],
              ),
            ),
            child: const Icon(Icons.remove_red_eye_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eyes Right',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '本地猫狗贴眼工具',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              title,
              style: GoogleFonts.notoSansSc(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.pink),
      title: Text(
        title,
        style: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.notoSansSc(fontSize: 12, color: AppTheme.textSecondary),
      ),
    );
  }
}
