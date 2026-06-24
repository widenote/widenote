import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_mobile/features/capture/application/capture_input_controller.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';
import 'package:widenote_mobile/features/capture/presentation/capture_console.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets('capture console voice draft visual baseline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final textController = TextEditingController(
      text: 'Draft the follow-up from today before saving it.',
    );
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      _VisualHarness(
        child: RepaintBoundary(
          key: const Key('capture-console-voice-visual'),
          child: CaptureConsole(
            controller: textController,
            inputState: CaptureInputState(
              mode: CaptureMode.voice,
              attachments: <CaptureAttachment>[
                CaptureAttachment(
                  id: 'visual-voice',
                  kind: CaptureAssetKind.voice,
                  displayName: 'Voice transcript sample.m4a',
                  mimeType: 'audio/mp4',
                  sourceUri: 'fake://voice/visual.m4a',
                  createdAt: DateTime.utc(2026, 6, 24, 10),
                  state: CaptureAttachmentState.needsReview,
                  previewText:
                      'Transcript draft: ask Chen to confirm launch notes.',
                  reviewReason: 'Transcript needs review before Memory.',
                  rawMetadata: const <String, Object?>{
                    'adapter': 'visual-test',
                  },
                ),
              ],
            ),
            isProcessing: false,
            onSubmit: () {},
            onModeChanged: (_) {},
            onAddPhoto: () {},
            onAddVoice: () {},
            onAddShare: () {},
            onRemoveAttachment: (_) {},
            onAcceptAttachmentReview: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('capture-console-voice-visual')),
      matchesGoldenFile('goldens/capture_console_voice_en.png'),
    );
  });
}

class _VisualHarness extends StatelessWidget {
  const _VisualHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2367C9),
      surface: Colors.white,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
          ),
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
