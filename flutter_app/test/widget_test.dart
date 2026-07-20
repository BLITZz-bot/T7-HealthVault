import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HealthVaultApp());

    // Verify that the login screen title is present.
    expect(find.text('T7 HealthVault'), findsOneWidget);
  });
}
