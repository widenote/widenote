import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';

void main() {
  testWidgets('renders core shell strings in English', (tester) async {
    await _pumpLocalizedApp(tester, const Locale('en'));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Packs'), findsOneWidget);
    expect(find.text('WideNote'), findsOneWidget);
    expect(find.text('WideNote / 广记'), findsNothing);
    expect(find.text('New record'), findsOneWidget);
    expect(find.text('Background voice'), findsOneWidget);

    await _openTab(tester, const Key('tab-chat'));
    expect(find.text('History'), findsOneWidget);
    expect(find.text('No local sessions yet.'), findsOneWidget);

    await _openTab(tester, const Key('tab-todos'));
    expect(find.text('Source-linked todos'), findsOneWidget);
    expect(find.text('No source-linked todos yet.'), findsOneWidget);

    await _openTab(tester, const Key('tab-plugins'));
    expect(find.text('Control entries'), findsOneWidget);
    expect(find.text('Pack Library'), findsOneWidget);
  });

  testWidgets('renders core shell strings in Chinese', (tester) async {
    await _pumpLocalizedApp(tester, const Locale('zh'));

    expect(find.text('首页/记录'), findsOneWidget);
    expect(find.text('对话'), findsOneWidget);
    expect(find.text('待办'), findsWidgets);
    expect(find.text('插件'), findsOneWidget);
    expect(find.text('广记'), findsOneWidget);
    expect(find.text('WideNote / 广记'), findsNothing);
    expect(find.text('新记录'), findsOneWidget);
    expect(find.text('后台录音'), findsOneWidget);
    expect(find.text('记录'), findsWidgets);

    await _openTab(tester, const Key('tab-chat'));
    expect(find.text('历史会话'), findsOneWidget);
    expect(find.text('还没有本地会话。'), findsOneWidget);

    await _openTab(tester, const Key('tab-todos'));
    expect(find.text('来源关联待办'), findsOneWidget);
    expect(find.text('还没有来源关联待办。'), findsOneWidget);

    await _openTab(tester, const Key('tab-plugins'));
    expect(find.text('控制入口'), findsOneWidget);
    expect(find.text('插件库'), findsOneWidget);

    await tester.tap(find.byKey(const Key('model-provider-entry')));
    await tester.pumpAndSettle();
    expect(find.text('模型提供商'), findsWidgets);
    expect(find.text('添加提供商'), findsOneWidget);
    expect(find.text('尚未配置模型'), findsOneWidget);

    await _openTab(tester, const Key('tab-plugins'));
    await tester.tap(find.byKey(const Key('backup-entry')));
    await tester.pumpAndSettle();
    expect(find.text('备份'), findsWidgets);
    expect(find.text('创建 .widenote 备份'), findsOneWidget);
    expect(find.textContaining('当前版本不提供操作入口'), findsOneWidget);
    expect(find.textContaining('但不包含 Provider Key'), findsOneWidget);
  });
}

Future<void> _pumpLocalizedApp(WidgetTester tester, Locale locale) async {
  final localDatabase = WideNoteLocalDatabase.inMemory();
  addTearDown(localDatabase.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(localDatabase)],
      child: WideNoteApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byKey(const Key('home-page')).evaluate().isEmpty) {
    await _openTab(tester, const Key('tab-home'));
  }
}

Future<void> _openTab(WidgetTester tester, Key tabKey) async {
  await tester.tap(find.byKey(tabKey));
  await tester.pumpAndSettle();
}
