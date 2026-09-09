import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eyes_right_flutter/ui/theme.dart';

void main() {
  testWidgets('bilibili-inspired theme builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(child: Text('Eyes Right')),
        ),
      ),
    );
    expect(find.text('Eyes Right'), findsOneWidget);
    expect(AppTheme.pink, const Color(0xFFFB7299));
  });
}
