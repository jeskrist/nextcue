import 'package:nextcue/widgets/duration_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DurationPickerSheet displays initial duration and has Done button',
      (WidgetTester tester) async {
    Duration? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  selected = await showDurationPickerSheet(
                    context: context,
                    initialDuration: const Duration(seconds: 45),
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      ),
    );

    // Tap open picker button
    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    // Verify Title and buttons exist
    expect(find.text('Display Duration'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Tap Done
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Verify duration returned
    expect(selected, isNotNull);
    expect(selected!.inSeconds, 45);
  });
}
