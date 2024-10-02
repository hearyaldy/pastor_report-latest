// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pastor_report/main.dart'; // Ensure this points to your main.dart file

void main() {
  testWidgets('App startup test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const PastorReportApp()); // Update to match the correct app class name

    // Verify that the app displays the correct initial state or widget.
    expect(find.text('Sign In'), findsOneWidget); // Modify to match an element present on the initial screen
  });
}
