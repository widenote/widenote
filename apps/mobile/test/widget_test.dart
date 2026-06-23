import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_mobile/app/widenote_app.dart';

void main() {
  testWidgets('switches between the four WideNote tabs', (tester) async {
    await _pumpApp(tester);

    expect(find.byKey(const Key('home-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-todos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todos-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plugins-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
  });

  testWidgets('quick capture creates record, auto-accepted Memory, and trace', (
    tester,
  ) async {
    await _pumpApp(tester);

    const captureText = 'Met Lin about WideNote source-linked todos.';

    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      captureText,
    );
    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pumpAndSettle();

    expect(find.text(captureText), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('home-page')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Memory 自动入库'), findsOneWidget);
    expect(find.textContaining('auto-accepted'), findsWidgets);

    await tester.drag(
      find.byKey(const Key('home-page')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('runtime.run.completed'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: WideNoteApp()));
  await tester.pumpAndSettle();
}
