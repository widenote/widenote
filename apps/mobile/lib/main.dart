import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/local_database.dart';
import 'app/widenote_app.dart';
import 'features/capture/application/capture_background_processing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
    initializeCaptureBackgroundProcessing().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'widenote.capture.background',
          context: ErrorDescription(
            'while initializing capture background processing',
          ),
        ),
      );
    }),
  );

  final bootstrap = await WideNoteMobileBootstrap.production();

  runApp(
    ProviderScope(
      overrides: bootstrap.providerOverrides,
      child: const WideNoteApp(),
    ),
  );
}
