import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raku_music/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RakuMusicApp());

    // Verify that the app shows the Home, Library and Settings tabs in the bottom navigation bar.
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.library_music), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
