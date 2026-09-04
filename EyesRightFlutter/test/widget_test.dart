import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eyes_right_flutter/ui/theme.dart';

void main() {
  testWidgets('theme builds a MaterialApp shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          appBar: AppBar(title: const Text('Eyes Right')),
        ),
      ),
    );
    expect(find.text('Eyes Right'), findsOneWidget);
  });
}
