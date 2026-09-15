import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirana_store/shared/widgets/debounced_button.dart';

void main() {
  group('DebouncedButton Tests', () {
    testWidgets('Prevents multiple rapid taps while processing async action', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebouncedButton(
              onPressed: () async {
                tapCount++;
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: const Text('Submit'),
            ),
          ),
        ),
      );

      // Tap once
      await tester.tap(find.text('Submit'));
      await tester.pump(); // Start async action, spinner displays

      expect(tapCount, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tap second time while still loading
      await tester.tap(find.byType(DebouncedButton));
      await tester.pump();

      // Tap count remains 1
      expect(tapCount, equals(1));

      // Advance time to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      expect(tapCount, equals(1));
      expect(find.text('Submit'), findsOneWidget);
    });
  });
}
