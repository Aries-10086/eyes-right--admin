import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../state/app_session.dart';
import '../shell/app_shell.dart';
import '../theme.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

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
          '创作',
          style: GoogleFonts.notoSansSc(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.pink,
          ),
        ),
      ),
      child: Consumer<AppSession>(
        builder: (context, session, _) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  children: [
                    _Stage(session: session),
                    const SizedBox(height: 12),
                    _PreviewTabs(session: session),
                    const SizedBox(height: 14),
                    _Tip(session: session),
                  ],
                ),
              ),
              _BottomBar(session: session),
            ],
          );
        },
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final bytes = session.previewTab == PreviewTab.result
        ? session.resultBytes
        : session.sourceBytes;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.stage,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 52,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        session.ready ? '点下方相册或拍照开始' : '模型加载中…',
                        style: GoogleFonts.notoSansSc(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              if (session.busy)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            color: AppTheme.pink,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '贴眼处理中…',
                          style: GoogleFonts.notoSansSc(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTabs extends StatelessWidget {
  const _PreviewTabs({required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _item('原图', PreviewTab.source, session.sourceBytes != null),
          _item('结果', PreviewTab.result, session.resultBytes != null),
        ],
      ),
    );
  }

  Widget _item(String label, PreviewTab tab, bool enabled) {
    final selected = session.previewTab == tab;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: !enabled || session.busy
            ? null
            : () => session.setPreviewTab(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? AppTheme.pinkSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.notoSansSc(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: !enabled
                  ? AppTheme.textHint
                  : selected
                      ? AppTheme.pink
                      : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(session.status),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                session.status,
                style: GoogleFonts.notoSansSc(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.9))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _ActionIcon(
              icon: Icons.photo_library_outlined,
              label: '相册',
              onTap: (!session.ready || session.busy)
                  ? null
                  : () => session.pick(ImageSource.gallery),
            ),
            _ActionIcon(
              icon: Icons.photo_camera_outlined,
              label: '拍照',
              onTap: (!session.ready || session.busy)
                  ? null
                  : () => session.pick(ImageSource.camera),
            ),
            _ActionIcon(
              icon: Icons.save_alt_rounded,
              label: '保存',
              onTap: (session.resultBytes == null || session.busy)
                  ? null
                  : () async {
                      final err = await session.save();
                      if (context.mounted && err == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已保存到相册')),
                        );
                      }
                    },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: (!session.ready ||
                          session.busy ||
                          session.sourceBytes == null)
                      ? null
                      : session.process,
                  child: session.busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '开始贴眼',
                          style: GoogleFonts.notoSansSc(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? AppTheme.textPrimary : AppTheme.textHint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.notoSansSc(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
