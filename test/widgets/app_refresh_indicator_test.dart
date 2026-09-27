import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/views/shared/widgets/app_refresh_indicator.dart';

void main() {
  testWidgets('AppRefreshIndicator renders child and executes onRefresh on show()',
      (WidgetTester tester) async {
    bool refreshed = false;
    final key = GlobalKey<AppRefreshIndicatorState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRefreshIndicator(
            key: key,
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 100));
              refreshed = true;
            },
            child: ListView(
              children: const [
                Text('Item 1'),
                Text('Item 2'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Item 1'), findsOneWidget);
    expect(refreshed, isFalse);

    // Programmatically trigger refresh
    key.currentState?.show();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Updating hostel data...'), findsOneWidget);

    // Complete the async delayed future
    await tester.pump(const Duration(milliseconds: 150));
    // Settle transition
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
  });

  testWidgets('AppRefreshIndicator prevents concurrent refresh triggers',
      (WidgetTester tester) async {
    int refreshCount = 0;
    final key = GlobalKey<AppRefreshIndicatorState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRefreshIndicator(
            key: key,
            onRefresh: () async {
              refreshCount++;
              await Future<void>.delayed(const Duration(milliseconds: 200));
            },
            child: ListView(
              children: const [Text('Item')],
            ),
          ),
        ),
      ),
    );

    // First trigger
    key.currentState?.show();
    await tester.pump();

    // Second trigger while first is active
    key.currentState?.show();
    await tester.pump();

    // Advance past the 200ms refresh + 420ms settle delay + settle animation
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(refreshCount, equals(1));
  });

  testWidgets('AppRefreshIndicator triggers on downward pull drag gesture',
      (WidgetTester tester) async {
    bool refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRefreshIndicator(
            triggerOffset: 80.0,
            onRefresh: () async {
              refreshed = true;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100, child: Text('Header')),
                SizedBox(height: 100, child: Text('Content')),
              ],
            ),
          ),
        ),
      ),
    );

    // Pull down past threshold (120px)
    await tester.drag(find.text('Header'), const Offset(0, 140));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
  });
}
