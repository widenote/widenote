import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_model_providers/model_providers.dart';
import 'package:widenote_mobile/features/model_providers/application/model_provider_settings_controller.dart';
import 'package:widenote_mobile/features/transcription/transcript_correction_controller.dart';
import 'package:widenote_mobile/features/transcription/transcription_settings.dart';

void main() {
  const apiKey = String.fromEnvironment('WIDENOTE_QA_DEEPSEEK_API_KEY');
  const endpointValue = String.fromEnvironment(
    'WIDENOTE_QA_DEEPSEEK_ENDPOINT',
    defaultValue: 'https://api.deepseek.com/anthropic',
  );
  const model = String.fromEnvironment(
    'WIDENOTE_QA_DEEPSEEK_MODEL',
    defaultValue: 'deepseek-v4-flash',
  );
  final hasApiKey = apiKey.trim().isNotEmpty;

  group(
    'DeepSeek transcript correction live QA',
    skip: hasApiKey
        ? null
        : 'Pass --dart-define=WIDENOTE_QA_DEEPSEEK_API_KEY to run live QA.',
    () {
      late DartIoModelProviderHttpClient httpClient;

      setUp(() {
        httpClient = DartIoModelProviderHttpClient();
      });

      tearDown(() {
        httpClient.close();
      });

      test(
        'returns a structured glossary patch without leaking credentials',
        () async {
          final provider = modelProviderFromConfig(
            config: ModelProviderConfig(
              id: 'deepseek-transcript-live',
              kind: ModelProviderKind.anthropicCompatible,
              displayName: 'DeepSeek Transcript Live QA',
              endpoint: Uri.parse(endpointValue),
              model: model,
              apiKey: apiKey.trim(),
            ),
            httpClient: httpClient,
          );
          final modelClient = RuntimeModelClientAdapter(
            provider: provider,
            model: model,
          );
          final controller = TranscriptCorrectionController(model: modelClient);

          final result = await controller.correct(
            transcript: 'WideNote uses Mimex for source-linked Memory.',
            glossaryTerms: const <String>[
              'Mimex -> Memex',
              'WideNote',
              'source-linked Memory',
            ],
            mode: TranscriptCorrectionMode.autoApplyHighConfidence,
          );

          expect(result.originalText, contains('Mimex'));
          expect(result.patches, isNotEmpty);
          expect(
            result.patches.any(
              (patch) =>
                  patch.from == 'Mimex' &&
                  patch.to == 'Memex' &&
                  patch.start == result.originalText.indexOf('Mimex') &&
                  patch.end == patch.start + 'Mimex'.length,
            ),
            isTrue,
          );
          expect(result.evidence['pack_id'], 'pack.transcript_correction');
          expect(result.evidence.toString(), isNot(contains(apiKey.trim())));
          if (result.autoApplied) {
            expect(result.correctedText, contains('Memex'));
            expect(result.correctedText, isNot(contains('Mimex')));
          }
        },
        timeout: const Timeout(Duration(seconds: 90)),
      );
    },
  );
}
