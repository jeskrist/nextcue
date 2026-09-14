import 'dart:io';

import 'package:nextcue/models/media_item.dart';
import 'package:nextcue/screens/playlist_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Swiping right on PlaylistPlayerScreen with 1 item navigates back',
      (WidgetTester tester) async {
    final tempFile = File('${Directory.systemTemp.path}/test_image.jpg')
      ..createSync();
    addTearDown(() {
      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    final playlist = [
      MediaItem(
        id: 'test-1',
        filePath: tempFile.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 5),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistPlayerScreen(playlist: playlist),
                  ),
                );
              },
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistPlayerScreen), findsOneWidget);

    // Swipe right (drag from left to right: offset (+300, 0))
    await tester.drag(find.byType(PlaylistPlayerScreen), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistPlayerScreen), findsNothing);
  });

  testWidgets(
      'Swiping right on PlaylistPlayerScreen with 2 items navigates back when at index 0',
      (WidgetTester tester) async {
    final tempFile = File('${Directory.systemTemp.path}/test_image2.jpg')
      ..createSync();
    addTearDown(() {
      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    final playlist = [
      MediaItem(
        id: 'test-1',
        filePath: tempFile.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 5),
      ),
      MediaItem(
        id: 'test-2',
        filePath: tempFile.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 5),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistPlayerScreen(playlist: playlist),
                  ),
                );
              },
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistPlayerScreen), findsOneWidget);

    // Swipe right (drag from left to right: offset (+300, 0))
    await tester.drag(find.byType(PlaylistPlayerScreen), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistPlayerScreen), findsNothing);
  });

  testWidgets(
      'Swiping left on PlaylistPlayerScreen with 1 item navigates back',
      (WidgetTester tester) async {
    final tempFile = File('${Directory.systemTemp.path}/test_image_left.jpg')
      ..createSync();
    addTearDown(() {
      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    final playlist = [
      MediaItem(
        id: 'test-1',
        filePath: tempFile.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 5),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistPlayerScreen(playlist: playlist),
                  ),
                );
              },
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistPlayerScreen), findsOneWidget);

    // Swipe left (drag from right to left: offset (-300, 0))
    await tester.drag(find.byType(PlaylistPlayerScreen), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistPlayerScreen), findsNothing);
  });

  testWidgets(
      'Swiping left on PlaylistPlayerScreen while playing an image pauses the image',
      (WidgetTester tester) async {
    final tempFile1 = File('${Directory.systemTemp.path}/test_swipe_pause_1.jpg')
      ..createSync();
    final tempFile2 = File('${Directory.systemTemp.path}/test_swipe_pause_2.jpg')
      ..createSync();
    addTearDown(() {
      if (tempFile1.existsSync()) tempFile1.deleteSync();
      if (tempFile2.existsSync()) tempFile2.deleteSync();
    });

    final playlist = [
      MediaItem(
        id: 'test-1',
        filePath: tempFile1.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 10),
      ),
      MediaItem(
        id: 'test-2',
        filePath: tempFile2.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 10),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistPlayerScreen(playlist: playlist),
      ),
    );
    await tester.pump();

    // Start playing image 1
    final playBtn = find.byTooltip('Resume');
    expect(playBtn, findsOneWidget);
    await tester.tap(playBtn);
    await tester.pump(const Duration(milliseconds: 100));

    // Initially playing: paused overlay opacity is 0
    final animatedOpacityFinder = find.byType(AnimatedOpacity).first;
    expect(tester.widget<AnimatedOpacity>(animatedOpacityFinder).opacity, 0.0);

    // Fling left to swipe to next item
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();

    // The screen has moved to item 2 and is paused
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);
  });

  testWidgets(
      'Swiping right on PlaylistPlayerScreen from item 2 pauses playing media',
      (WidgetTester tester) async {
    final tempFile1 = File('${Directory.systemTemp.path}/test_swipe_right_1.jpg')
      ..createSync();
    final tempFile2 = File('${Directory.systemTemp.path}/test_swipe_right_2.jpg')
      ..createSync();
    addTearDown(() {
      if (tempFile1.existsSync()) tempFile1.deleteSync();
      if (tempFile2.existsSync()) tempFile2.deleteSync();
    });

    final playlist = [
      MediaItem(
        id: 'test-1',
        filePath: tempFile1.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 10),
      ),
      MediaItem(
        id: 'test-2',
        filePath: tempFile2.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 10),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistPlayerScreen(playlist: playlist, initialIndex: 1),
      ),
    );
    await tester.pump();

    // Start playing image 2
    final playBtn = find.byTooltip('Resume');
    expect(playBtn, findsOneWidget);
    await tester.tap(playBtn);
    await tester.pump(const Duration(milliseconds: 100));

    // Confirm it is playing
    final animatedOpacityFinder = find.byType(AnimatedOpacity).first;
    expect(tester.widget<AnimatedOpacity>(animatedOpacityFinder).opacity, 0.0);

    // Fling right to swipe back to item 1
    await tester.fling(find.byType(PageView), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();

    // The screen has moved to item 1 and is paused
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);
  });

  testWidgets(
      'Starting a swipe gesture immediately pauses the currently playing media before transition completes',
      (WidgetTester tester) async {
    final tempFile1 = File('${Directory.systemTemp.path}/test_swipe_immediate_1.jpg')
      ..createSync();
    final tempFile2 = File('${Directory.systemTemp.path}/test_swipe_immediate_2.jpg')
      ..createSync();
    addTearDown(() {
      if (tempFile1.existsSync()) tempFile1.deleteSync();
      if (tempFile2.existsSync()) tempFile2.deleteSync();
    });

    final playlist = [
      MediaItem(
        id: 'test-1',
        filePath: tempFile1.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 10),
      ),
      MediaItem(
        id: 'test-2',
        filePath: tempFile2.path,
        type: MediaType.image,
        imageDuration: const Duration(seconds: 10),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistPlayerScreen(playlist: playlist),
      ),
    );
    await tester.pump();

    // Start playing image 1
    final playBtn = find.byTooltip('Resume');
    expect(playBtn, findsOneWidget);
    await tester.tap(playBtn);
    await tester.pump(const Duration(milliseconds: 100));

    // Confirm playing (opacity 0)
    final animatedOpacityFinder = find.byType(AnimatedOpacity).first;
    expect(tester.widget<AnimatedOpacity>(animatedOpacityFinder).opacity, 0.0);

    // Begin a drag/swipe gesture (small drag, not crossing page boundary)
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump(const Duration(milliseconds: 50));

    // The media should already be paused immediately as swipe begins
    expect(tester.widget<AnimatedOpacity>(animatedOpacityFinder).opacity, 1.0);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}

