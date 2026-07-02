import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_mobile/features/transcription/transcript_correction_controller.dart';
import 'package:widenote_mobile/features/transcription/transcription_settings.dart';

void main() {
  group('TranscriptCorrectionController', () {
    test(
      'auto-apply follows model output even for text that looks sensitive',
      () async {
        final model = runtime.FakeModel(
          responses: const <String>[
            '{"patches":[{"from":"Mimex 2 password","to":"Memex 2 password","span":{"start":4,"end":20},"confidence":"high","reason":"term_memory","requires_review":false}]}',
          ],
        );
        final controller = TranscriptCorrectionController(model: model);

        final result = await controller.correct(
          transcript: 'Use Mimex 2 password token.',
          glossaryTerms: const <String>['Mimex 2 password -> Memex 2 password'],
          mode: TranscriptCorrectionMode.autoApplyHighConfidence,
        );

        expect(result.autoApplied, isTrue);
        expect(result.correctedText, 'Use Memex 2 password token.');
        expect(result.patches.single.requiresReview, isFalse);
      },
    );

    test('model requires_review keeps high-confidence patch in review', () async {
      final model = runtime.FakeModel(
        responses: const <String>[
          '{"patches":[{"from":"Mimex","to":"Memex","span":{"start":4,"end":9},"confidence":"high","reason":"term_memory","requires_review":true}]}',
        ],
      );
      final controller = TranscriptCorrectionController(model: model);

      final result = await controller.correct(
        transcript: 'Use Mimex today.',
        glossaryTerms: const <String>['Mimex -> Memex'],
        mode: TranscriptCorrectionMode.autoApplyHighConfidence,
      );

      expect(result.autoApplied, isFalse);
      expect(result.correctedText, result.originalText);
      expect(result.patches.single.requiresReview, isTrue);
      expect(result.evidence['status'], 'needs_review');
    });

    test('missing model review signal conservatively requires review', () async {
      final model = runtime.FakeModel(
        responses: const <String>[
          '{"patches":[{"from":"Mimex","to":"Memex","span":{"start":4,"end":9},"confidence":"high","reason":"term_memory"}]}',
        ],
      );
      final controller = TranscriptCorrectionController(model: model);

      final result = await controller.correct(
        transcript: 'Use Mimex today.',
        glossaryTerms: const <String>['Mimex -> Memex'],
        mode: TranscriptCorrectionMode.autoApplyHighConfidence,
      );

      expect(result.autoApplied, isFalse);
      expect(result.patches.single.requiresReview, isTrue);
      expect(result.evidence['status'], 'needs_review');
    });

    test('schema-invalid fields conservatively require review', () async {
      const cases = <String, String>{
        'invalid confidence':
            '{"patches":[{"from":"Mimex","to":"Memex","span":{"start":4,"end":9},"confidence":"certain","reason":"term_memory","requires_review":false}]}',
        'invalid reason':
            '{"patches":[{"from":"Mimex","to":"Memex","span":{"start":4,"end":9},"confidence":"high","reason":"semantic_guess","requires_review":false}]}',
        'string review flag':
            '{"patches":[{"from":"Mimex","to":"Memex","span":{"start":4,"end":9},"confidence":"high","reason":"term_memory","requires_review":"false"}]}',
        'string span':
            '{"patches":[{"from":"Mimex","to":"Memex","span":{"start":"4","end":"9"},"confidence":"high","reason":"term_memory","requires_review":false}]}',
      };

      for (final entry in cases.entries) {
        final result =
            await TranscriptCorrectionController(
              model: runtime.FakeModel(responses: <String>[entry.value]),
            ).correct(
              transcript: 'Use Mimex today.',
              glossaryTerms: const <String>['Mimex -> Memex'],
              mode: TranscriptCorrectionMode.autoApplyHighConfidence,
            );

        expect(result.autoApplied, isFalse, reason: entry.key);
        expect(result.patches.single.requiresReview, isTrue, reason: entry.key);
        expect(result.evidence['status'], 'needs_review', reason: entry.key);
      }
    });

    test('malformed or untrusted output cannot auto-apply', () async {
      final malformedModel = runtime.FakeModel(
        responses: const <String>['not json'],
      );
      final malformed =
          await TranscriptCorrectionController(model: malformedModel).correct(
            transcript: 'Use Mimex today.',
            glossaryTerms: const <String>['Mimex -> Memex'],
            mode: TranscriptCorrectionMode.autoApplyHighConfidence,
          );

      expect(malformed.autoApplied, isFalse);
      expect(malformed.patches, isEmpty);
      expect(malformed.evidence['status'], 'needs_review');

      final badSpanModel = runtime.FakeModel(
        responses: const <String>[
          '{"patches":[{"from":"Mimex","to":"Memex","span":{"start":0,"end":5},"confidence":"high","reason":"term_memory","requires_review":false}]}',
        ],
      );
      final badSpan = await TranscriptCorrectionController(model: badSpanModel)
          .correct(
            transcript: 'Use Mimex today.',
            glossaryTerms: const <String>['Mimex -> Memex'],
            mode: TranscriptCorrectionMode.autoApplyHighConfidence,
          );

      expect(badSpan.autoApplied, isFalse);
      expect(badSpan.patches.single.requiresReview, isTrue);
      expect(badSpan.evidence['status'], 'needs_review');
    });
  });
}
