import 'package:nextcue/main.dart';
import 'package:nextcue/screens/file_selection_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NextCueApp launches and renders FileSelectionScreen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const NextCueApp());
    await tester.pumpAndSettle();

    expect(find.byType(NextCueApp), findsOneWidget);
    expect(find.byType(FileSelectionScreen), findsOneWidget);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Add media'), findsOneWidget);
    expect(find.text('Start Cue'), findsOneWidget);
  });
}
