import 'package:flutter_test/flutter_test.dart';
import 'package:hayagsync/main.dart';

void main() {
  testWidgets('Smoke test - App builds and loads LoginScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HayagSyncApp());

    // Verify that the login page loads with core texts
    expect(find.text('HAYAGSYNC'), findsOneWidget);
    expect(find.text('Sign In'), findsNWidgets(2));
  });
}
