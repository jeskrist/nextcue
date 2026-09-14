import 'package:flutter/material.dart';
import 'package:nextcue/main.dart';
import 'package:nextcue/screens/file_selection_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup splash stays visible for a minimum of 3 seconds',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const NextCueApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/splash/splash.png',
      ),
      findsOneWidget,
    );
    expect(find.byType(FileSelectionScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
    expect(find.byType(FileSelectionScreen), findsOneWidget);
  });

  testWidgets('FileSelectionScreen shows the keep-progress toggle',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: FileSelectionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Keep player positions'), findsOneWidget);
    final switchFinder = find.byType(SwitchListTile);
    expect(switchFinder, findsOneWidget);
    expect((tester.widget<SwitchListTile>(switchFinder)).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('nextcue_keep_playback_progress'), isFalse);
  });

  testWidgets('NextCueApp launches and renders FileSelectionScreen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const NextCueApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.byType(NextCueApp), findsOneWidget);
    expect(find.byType(FileSelectionScreen), findsOneWidget);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Add media'), findsOneWidget);
    expect(find.text('Start Cue'), findsOneWidget);
  });
}
