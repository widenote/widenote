import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/local_database.dart';
import 'app/widenote_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await WideNoteMobileBootstrap.production();

  runApp(
    ProviderScope(
      overrides: bootstrap.providerOverrides,
      child: const WideNoteApp(),
    ),
  );
}
