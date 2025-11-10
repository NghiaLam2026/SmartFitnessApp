import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_fitness_app/main.dart';

void main() {
  setUpAll(() async {
    // Initialize Supabase for testing with mock values
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: SmartFitnessApp()));

    // Verify that the app builds without errors
    expect(find.byType(SmartFitnessApp), findsOneWidget);
  });
}
