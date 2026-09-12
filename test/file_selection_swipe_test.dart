import 'dart:convert';
import 'dart:io';

import 'package:nextcue/models/media_item.dart';
import 'package:nextcue/screens/file_selection_screen.dart';
import 'package:nextcue/screens/playlist_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Swiping left on FileSelectionScreen does nothing when playlist is empty',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: FileSelectionScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(FileSelectionScreen), findsOneWidget);
    expect(find.byType(PlaylistPlayerScreen), findsNothing);

    // Swipe left (drag from right to left: offset (-300, 0))
    await tester.drag(find.byType(FileSelectionScreen), const Offset(-300, 0));
    await tester.pump();

    // Verify still on FileSelectionScreen and NOT PlaylistPlayerScreen
    expect(find.byType(FileSelectionScreen), findsOneWidget);
    expect(find.byType(PlaylistPlayerScreen), findsNothing);
  });

  testWidgets(
      'Swiping left on FileSelectionScreen navigates to PlaylistPlayerScreen when at least one file is selected',
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
      ).toJson(),
    ];

    SharedPreferences.setMockInitialValues({
      'nextcue_playlist': jsonEncode(playlist),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: FileSelectionScreen(),
      ),
    );
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.byType(FileSelectionScreen), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);

    // Swipe left (fling from right to left)
    await tester.fling(find.byType(FileSelectionScreen), const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify navigates to PlaylistPlayerScreen
    expect(find.byType(PlaylistPlayerScreen), findsOneWidget);
  });
}
