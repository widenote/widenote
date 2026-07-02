import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/local_database.dart';
import 'app/widenote_app.dart';
import 'features/capture/application/capture_background_processing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeCaptureBackgroundProcessing();

  final bootstrap = await WideNoteMobileBootstrap.production();

  runApp(
    ProviderScope(
      overrides: bootstrap.providerOverrides,
      child: const WideNoteApp(),
    ),
  );
}
