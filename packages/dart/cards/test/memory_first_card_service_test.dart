import 'package:test/test.dart';
import 'package:widenote_cards/widenote_cards.dart';

void main() {
  group('MemoryFirstCardService', () {
    const service = MemoryFirstCardService();

    test('returns no cards or insights for empty input', () {
      final bundle = service.generate(
        MemoryFirstCardInput(now: DateTime.utc(2026, 6, 24)),
      );

      expect(bundle.cards, isEmpty);
      expect(bundle.insights, isEmpty);
    });

    test('derives source-linked cards from captures and Memory', () {
      final bundle = service.generate(
        MemoryFirstCardInput(
          now: DateTime.utc(2026, 6, 24, 12),
          captures: <CaptureCardSource>[
            CaptureCardSource(
              id: 'capture-1',
              text: 'Met Lin about the WideNote cards lane.',
              createdAt: DateTime.utc(2026, 6, 24, 8),
            ),
          ],
          memories: <MemoryCardSource>[
            MemoryCardSource(
              id: 'memory-1',
              key: 'project.widenote.cards',
              body: 'Lin cares about source-linked cards.',
              memoryType: 'project',
              createdAt: DateTime.utc(2026, 6, 24, 9),
              sourceLinks: const <SourceLink>[
                SourceLink(
                  kind: 'capture',
                  id: 'capture-1',
                  excerpt: 'WideNote cards lane',
                ),
              ],
            ),
          ],
        ),
      );

      expect(bundle.cards, hasLength(2));
      expect(bundle.cards.every((card) => card.isSourceLinked), isTrue);
      expect(bundle.cards.first.kind, MemoryFirstCardKind.captureSummary);
      expect(bundle.cards.first.sourceLinks.single.kind, 'capture');
      expect(bundle.cards.first.sourceLinks.single.id, 'capture-1');

      final memoryCard = bundle.cards.singleWhere(
        (card) => card.kind == MemoryFirstCardKind.memorySummary,
      );
      expect(memoryCard.sourceLinks.map((link) => '${link.kind}:${link.id}'), [
        'memory:memory-1',
        'capture:capture-1',
      ]);
      expect(memoryCard.metadata['memory_key'], 'project.widenote.cards');
    });

    test('does not derive lightweight insights from captures and Memory', () {
      final bundle = service.generate(
        MemoryFirstCardInput(
          now: DateTime.utc(2026, 6, 24, 12),
          captures: <CaptureCardSource>[
            CaptureCardSource(
              id: 'capture-early',
              text: 'Morning capture',
              createdAt: DateTime.utc(2026, 6, 23, 8),
            ),
            CaptureCardSource(
              id: 'capture-late',
              text: 'Later capture',
              createdAt: DateTime.utc(2026, 6, 24, 8),
            ),
          ],
          memories: <MemoryCardSource>[
            MemoryCardSource(
              id: 'memory-latest',
              key: 'memory.latest',
              body: 'Latest Memory remains a source-linked card.',
              createdAt: DateTime.utc(2026, 6, 24, 9),
              sourceLinks: const <SourceLink>[
                SourceLink(kind: 'capture', id: 'capture-late'),
              ],
            ),
          ],
        ),
      );

      expect(bundle.cards, hasLength(3));
      expect(bundle.insights, isEmpty);
    });

    test('does not infer semantic or statistical insights locally', () {
      final bundle = service.generate(
        MemoryFirstCardInput(
          now: DateTime.utc(2026, 6, 24, 12),
          captures: <CaptureCardSource>[
            CaptureCardSource(
              id: 'capture-media',
              text:
                  'Review the launch whiteboard photo. OCR says prepare next step.',
              createdAt: DateTime.utc(2026, 6, 24, 8),
            ),
            CaptureCardSource(
              id: 'capture-voice',
              text:
                  'Voice transcript captured: follow up with source-linked cards.',
              createdAt: DateTime.utc(2026, 6, 24, 9),
            ),
          ],
        ),
      );

      expect(bundle.cards, hasLength(2));
      expect(bundle.insights, isEmpty);
    });

    test(
      'structured insight payload round-trips claims metrics and UI blocks',
      () {
        const source = SourceLink(
          kind: 'capture',
          id: 'capture-1',
          excerpt: 'WideNote source',
        );
        final payload = MemoryFirstInsightPayload(
          claims: <MemoryFirstInsightClaim>[
            MemoryFirstInsightClaim(
              id: 'claim-1',
              text: 'WideNote keeps insight claims source-linked.',
              sourceLinks: const <SourceLink>[source],
              confidence: 0.9,
            ),
          ],
          metrics: <MemoryFirstInsightMetric>[
            MemoryFirstInsightMetric(
              label: 'source-linked',
              value: 1,
              sourceLinks: const <SourceLink>[source],
            ),
          ],
          sourceLinks: const <SourceLink>[source],
          uiBlocks: <MemoryFirstInsightUiBlock>[
            MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.claimList),
            MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.metricRow),
            MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.sourceRefs),
            MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.note),
          ],
          note: 'Structured output is renderer-safe.',
        );

        final roundTripped = MemoryFirstInsightPayload.fromJson(
          Map<Object?, Object?>.from(payload.toJson()),
        );

        expect(roundTripped.claims.single.text, contains('source-linked'));
        expect(roundTripped.claims.single.sourceLinks.single.id, 'capture-1');
        expect(roundTripped.metrics.single.value, 1);
        expect(roundTripped.uiBlocks.map((block) => block.kind), [
          InsightUiBlockKinds.claimList,
          InsightUiBlockKinds.metricRow,
          InsightUiBlockKinds.sourceRefs,
          InsightUiBlockKinds.note,
        ]);
      },
    );

    test('structured insight payload accepts reserved deep insight blocks', () {
      const source = SourceLink(kind: 'capture', id: 'capture-1');
      final payload = MemoryFirstInsightPayload(
        claims: <MemoryFirstInsightClaim>[
          MemoryFirstInsightClaim(
            text: 'Deep insight blocks remain source-linked.',
            sourceLinks: const <SourceLink>[source],
          ),
        ],
        sourceLinks: const <SourceLink>[source],
        uiBlocks: <MemoryFirstInsightUiBlock>[
          MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.evidenceList),
          MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.counterEvidence),
          MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.confidenceBand),
          MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.contrast),
          MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.trendChart),
          MemoryFirstInsightUiBlock(kind: InsightUiBlockKinds.timeline),
        ],
      );

      final roundTripped = MemoryFirstInsightPayload.fromJson(
        Map<Object?, Object?>.from(payload.toJson()),
      );

      expect(roundTripped.uiBlocks.map((block) => block.kind), [
        InsightUiBlockKinds.evidenceList,
        InsightUiBlockKinds.counterEvidence,
        InsightUiBlockKinds.confidenceBand,
        InsightUiBlockKinds.contrast,
        InsightUiBlockKinds.trendChart,
        InsightUiBlockKinds.timeline,
      ]);
    });

    test('dedupes duplicate cards without creating local insights', () {
      final bundle = service.generate(
        MemoryFirstCardInput(
          now: DateTime.utc(2026, 6, 24, 12),
          captures: <CaptureCardSource>[
            CaptureCardSource(
              id: 'capture-1',
              text: 'Original source-linked capture.',
              createdAt: DateTime.utc(2026, 6, 24, 8),
            ),
            CaptureCardSource(
              id: 'capture-1',
              text: 'Duplicate source-linked capture should not double count.',
              createdAt: DateTime.utc(2026, 6, 24, 9),
            ),
            CaptureCardSource(
              id: 'capture-2',
              text: 'Latest ranked source-linked capture.',
              createdAt: DateTime.utc(2026, 6, 24, 10),
            ),
          ],
        ),
      );

      expect(bundle.cards.map((card) => card.id), [
        'card.capture.capture-1',
        'card.capture.capture-2',
      ]);
      expect(bundle.insights, isEmpty);
    });

    test('card and insight models reject missing source links', () {
      expect(
        () => MemoryFirstCard(
          id: 'card-empty',
          kind: MemoryFirstCardKind.captureSummary,
          title: 'Missing source',
          body: 'No source should fail.',
          sourceLinks: const <SourceLink>[],
          createdAt: DateTime.utc(2026, 6, 24),
        ),
        throwsArgumentError,
      );

      expect(
        () => MemoryFirstInsight(
          id: 'insight-empty',
          kind: MemoryFirstInsightKind.count,
          title: 'Missing source',
          summary: 'No source should fail.',
          sourceLinks: const <SourceLink>[],
          createdAt: DateTime.utc(2026, 6, 24),
        ),
        throwsArgumentError,
      );

      expect(
        () => MemoryFirstInsightClaim(
          text: 'A claim without sources must fail.',
          sourceLinks: const <SourceLink>[],
        ),
        throwsArgumentError,
      );

      expect(
        () => MemoryFirstInsightPayload.fromJson(<Object?, Object?>{
          'claims': <Object?>[
            <Object?, Object?>{
              'text': 'A parsed claim without refs must fail.',
              'source_refs': <Object?>[],
            },
          ],
        }),
        throwsArgumentError,
      );

      expect(
        () => MemoryFirstInsightUiBlock(kind: 'webview'),
        throwsArgumentError,
      );
    });
  });
}
