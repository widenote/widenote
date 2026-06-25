import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_mobile/app/model_client.dart';

void main() {
  const apiKey = String.fromEnvironment('WIDENOTE_QA_MIMO_API_KEY');
  final hasApiKey = apiKey.trim().isNotEmpty;

  group(
    'Xiaomi MIMO live QA',
    skip: hasApiKey
        ? null
        : 'Pass --dart-define=WIDENOTE_QA_MIMO_API_KEY to run live QA.',
    () {
      late XiaomiMimoModelClient client;

      setUp(() {
        client = XiaomiMimoModelClient(apiKey: apiKey);
      });

      tearDown(() {
        client.close(force: true);
      });

      test(
        'summarizes Chinese capture without echoing sensitive snippets',
        () async {
          const fakeSecret = 'sk-live-redaction-example-123456';

          final response = await _completeLive(
            client,
            const runtime.ModelRequest(
              prompt:
                  'Summarize capture for Memory: 今天我和产品同学确认广记要保持本地优先，'
                  '明天整理插件权限。不要保存口令 sk-live-redaction-example-123456。',
            ),
          );
          if (response == null) {
            return;
          }

          expect(response.text.trim(), isNotEmpty);
          expect(response.text.length, lessThanOrEqualTo(180));
          expect(response.text, isNot(contains(fakeSecret)));
          expect(response.text, isNot(contains('sk-live')));
          expect(
            response.text,
            anyOf(
              contains('本地'),
              contains('插件'),
              contains('权限'),
              contains('广记'),
              contains('WideNote'),
            ),
          );
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'keeps long mixed-language captures concise',
        () async {
          final longCapture = <String>[
            'Summarize capture for Memory:',
            'WideNote QA batch 2026-06-25.',
            'Morning: capture a messy bilingual note with tabs, punctuation, and repeated fragments.',
            '中午：检查 Memory review、source drill-down、todo reopen，还有备份导入失败提示。',
            'Evening: compare the saved Memory against the raw capture and make sure original text stays intact.',
            'Repeat repeat repeat so the model has to compress instead of copying the full note.',
          ].join('\n');

          final response = await _completeLive(
            client,
            runtime.ModelRequest(prompt: longCapture),
          );
          if (response == null) {
            return;
          }

          expect(response.text.trim(), isNotEmpty);
          expect(response.text.length, lessThanOrEqualTo(180));
          expect(response.text, isNot(contains('Repeat repeat repeat')));
          expect(
            response.text.toLowerCase(),
            anyOf(
              contains('qa'),
              contains('memory'),
              contains('备份'),
              contains('待办'),
            ),
          );
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    },
  );
}

Future<runtime.ModelResponse?> _completeLive(
  XiaomiMimoModelClient client,
  runtime.ModelRequest request,
) async {
  try {
    return await client.complete(request);
  } on XiaomiMimoModelException catch (error) {
    if (error.statusCode == 429) {
      markTestSkipped('MIMO live endpoint returned HTTP 429.');
      return null;
    }
    rethrow;
  }
}
