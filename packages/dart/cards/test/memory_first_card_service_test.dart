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

    test('derives summary, count, and trend insights with sources', () {
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
              body: 'Latest Memory wins the summary insight.',
              createdAt: DateTime.utc(2026, 6, 24, 9),
              sourceLinks: const <SourceLink>[
                SourceLink(kind: 'capture', id: 'capture-late'),
              ],
            ),
          ],
        ),
      );

      expect(bundle.insights.map((insight) => insight.kind), [
        MemoryFirstInsightKind.summary,
        MemoryFirstInsightKind.count,
        MemoryFirstInsightKind.trend,
        MemoryFirstInsightKind.sourceMix,
      ]);
      expect(
        bundle.insights.every((insight) => insight.isSourceLinked),
        isTrue,
      );
      expect(
        bundle.insights[0].summary,
        'Latest Memory wins the summary insight.',
      );
      expect(bundle.insights[1].metricValue, 3);
      expect(bundle.insights[1].summary, contains('2 captures and 1 Memory'));
      expect(bundle.insights[2].metadata['day'], '2026-06-24');
      expect(bundle.insights[2].metricValue, 2);
      expect(bundle.insights[3].summary, contains('3 card(s)'));
      expect(bundle.insights[3].metadata['source_kinds'], isA<Map>());
    });

    test('derives action and attachment evidence insights', () {
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

      expect(
        bundle.insights.map((insight) => insight.kind),
        containsAll(<MemoryFirstInsightKind>[
          MemoryFirstInsightKind.actionPattern,
          MemoryFirstInsightKind.attachmentEvidence,
        ]),
      );
      final action = bundle.insights.singleWhere(
        (insight) => insight.kind == MemoryFirstInsightKind.actionPattern,
      );
      expect(action.summary, contains('follow-up'));
      expect(action.metadata['terms'], containsAll(<String>['follow up']));

      final media = bundle.insights.singleWhere(
        (insight) => insight.kind == MemoryFirstInsightKind.attachmentEvidence,
      );
      expect(media.metricValue, 2);
      expect(
        media.metadata['modalities'],
        containsAll(<String>['image', 'ocr', 'transcript', 'audio']),
      );
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
    });
  });
}
