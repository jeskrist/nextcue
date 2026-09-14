import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcue/models/media_item.dart';
import 'package:nextcue/screens/playlist_player_screen.dart';
import 'package:nextcue/widgets/single_image_viewer.dart';

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

    final playBtn = find.byIcon(Icons.play_arrow);
    expect(playBtn, findsOneWidget);
    await tester.tap(playBtn);
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    expect(find.text('Cue Complete!'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
  });

  testWidgets('Image cue resumes progress when revisiting a file and reset jumps back to the first item',
      (WidgetTester tester) async {
    final firstFile = File('${Directory.systemTemp.path}/first_item.jpg')
      ..createSync();
    final secondFile = File('${Directory.systemTemp.path}/second_item.jpg')
      ..createSync();
    addTearDown(() {
      if (firstFile.existsSync()) firstFile.deleteSync();
      if (secondFile.existsSync()) secondFile.deleteSync();
    });

    final items = [
      MediaItem(
        id: 'item-1',
        filePath: firstFile.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 5),
      ),
      MediaItem(
        id: 'item-2',
        filePath: secondFile.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 5),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistPlayerScreen(playlist: items),
      ),
    );
    await tester.pump();

    final playBtn = find.byIcon(Icons.play_arrow);
    expect(playBtn, findsOneWidget);
    await tester.tap(playBtn);
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 400));
    final firstState = tester.state(find.byType(SingleImageViewer))
        as SingleImageViewerState;
    expect(firstState.elapsed, greaterThan(Duration.zero));

    await tester.fling(find.byType(PageView), const Offset(-800, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(800, 0), 2000);
    await tester.pumpAndSettle();

    final resumedState = tester.state(find.byType(SingleImageViewer))
        as SingleImageViewerState;
    expect(resumedState.elapsed, greaterThan(Duration.zero));

    final resetBtn = find.byTooltip('Reset cue');
    expect(resetBtn, findsOneWidget);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
    final resetState = tester.state(find.byType(SingleImageViewer))
        as SingleImageViewerState;
    expect(resetState.elapsed, Duration.zero);
  });
}
