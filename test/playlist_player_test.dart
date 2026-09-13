import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcue/models/media_item.dart';
import 'package:nextcue/screens/playlist_player_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cue Complete overlay has Restart and Close buttons, but no Finish button',
      (WidgetTester tester) async {
    final tempFile = File('${Directory.systemTemp.path}/test_item.jpg')
      ..createSync();
    addTearDown(() {
      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    final items = [
      MediaItem(
        id: 'item-1',
        filePath: tempFile.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 1),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistPlayerScreen(playlist: items),
      ),
    );
    await tester.pump();

    // Tap play button to start timer
    final playBtn = find.byIcon(Icons.play_arrow);
    expect(playBtn, findsOneWidget);
    await tester.tap(playBtn);
    await tester.pump();

    // Wait for the single image item timer to finish (1 second + periodic timer)
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    // Cue Complete overlay should be displayed
    expect(find.text('Cue Complete!'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
  });
}
