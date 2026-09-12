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
}
