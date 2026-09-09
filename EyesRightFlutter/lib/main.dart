import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_session.dart';
import 'ui/shell/app_shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EyesRightApp());
}

class EyesRightApp extends StatelessWidget {
  const EyesRightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppSession(),
      child: MaterialApp(
        title: 'Eyes Right',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light().copyWith(
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.pink : AppTheme.textSecondary,
              );
            }),
          ),
        ),
        home: const AppShell(),
      ),
    );
  }
}
