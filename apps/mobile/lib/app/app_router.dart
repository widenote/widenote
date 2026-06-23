import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/capture/presentation/home_page.dart';
import '../features/chat/presentation/chat_page.dart';
import '../features/plugins/presentation/plugins_page.dart';
import '../features/todos/presentation/todos_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return WideNoteShell(location: state.uri.path, child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/chat',
          name: 'chat',
          builder: (context, state) => const ChatPage(),
        ),
        GoRoute(
          path: '/todos',
          name: 'todos',
          builder: (context, state) => const TodosPage(),
        ),
        GoRoute(
          path: '/plugins',
          name: 'plugins',
          builder: (context, state) => const PluginsPage(),
        ),
      ],
    ),
  ],
);

class WideNoteShell extends StatelessWidget {
  const WideNoteShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _paths = ['/', '/chat', '/todos', '/plugins'];

  int get _selectedIndex {
    if (location.startsWith('/chat')) {
      return 1;
    }
    if (location.startsWith('/todos')) {
      return 2;
    }
    if (location.startsWith('/plugins')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => _openTab(context, index),
        destinations: const [
          NavigationDestination(
            key: Key('tab-home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页/记录',
          ),
          NavigationDestination(
            key: Key('tab-chat'),
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: '对话',
          ),
          NavigationDestination(
            key: Key('tab-todos'),
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '待办',
          ),
          NavigationDestination(
            key: Key('tab-plugins'),
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension),
            label: '插件',
          ),
        ],
      ),
    );
  }

  void _openTab(BuildContext context, int index) {
    final nextPath = _paths[index];
    if (location != nextPath) {
      context.go(nextPath);
    }
  }
}
