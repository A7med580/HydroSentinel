import 'package:flutter_test/flutter_test.dart';
import 'package:hydrosentinel/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App loads and shows dashboard', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: HydroSentinelApp()));

    // Verify that the dashboard title is present
    expect(find.text('HYDROSENTINEL DASHBOARD'), findsOneWidget);
  });
}
