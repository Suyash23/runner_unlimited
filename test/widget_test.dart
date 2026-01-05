import 'package:flutter_test/flutter_test.dart';
import 'package:endless_tube/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our game starts.
    expect(find.byType(TubeGame), findsOneWidget);
  });
}
