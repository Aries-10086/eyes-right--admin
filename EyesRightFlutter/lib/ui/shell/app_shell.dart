import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../state/app_session.dart';
import '../home/home_tab.dart';
import '../mine/mine_tab.dart';
import '../theme.dart';
import '../workshop/workshop_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void goHome() => setState(() => _index = 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomeTab(),
          WorkshopTab(onOpenHome: goHome),
          const MineTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.9))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 62,
            backgroundColor: Colors.white,
            indicatorColor: AppTheme.pinkSoft,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppTheme.pink),
                label: '首页',
              ),
              NavigationDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded, color: AppTheme.pink),
                label: '玩法',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: AppTheme.pink),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶栏品牌（各 Tab 复用）
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AppTheme.pink, AppTheme.pinkDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.pink.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eyes Right',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Consumer<AppSession>(
                  builder: (_, session, __) {
                    return Text(
                      '当前玩法 · ${session.selectedFeature.title}',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PinkPageScaffold extends StatelessWidget {
  const PinkPageScaffold({
    super.key,
    required this.child,
    this.headerTrailing,
  });

  final Widget child;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.pinkWash,
            AppTheme.pinkSoft,
            AppTheme.bg,
            AppTheme.bg,
          ],
          stops: [0, 0.16, 0.4, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrandHeader(trailing: headerTrailing),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
