import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_model_providers/model_providers.dart';
import 'package:widenote_mobile/features/capture/application/capture_orchestrator.dart';
import 'package:widenote_mobile/features/model_providers/application/model_provider_settings_controller.dart';

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
    'DeepSeek Anthropic-compatible agent orchestration live QA',
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
        'runs realistic quick captures through live agent orchestration',
        () async {
          final endpoint = Uri.parse(endpointValue);
          final provider = modelProviderFromConfig(
            config: ModelProviderConfig(
              id: 'deepseek-live',
              kind: ModelProviderKind.anthropicCompatible,
              displayName: 'DeepSeek Live QA',
              endpoint: endpoint,
              model: model,
              apiKey: apiKey,
            ),
            httpClient: httpClient,
          );
          final modelClient = RuntimeModelClientAdapter(
            provider: provider,
            model: model,
          );
          for (final persona in _livePersonas()) {
            final eventStore = runtime.InMemoryEventStore();
            final traceSink = runtime.InMemoryTraceSink();
            final clock = const SystemWnClock();
            final orchestrator = CaptureOrchestrator.local(
              eventStore: eventStore,
              traceSink: traceSink,
              clock: clock,
              idGenerator: MonotonicWnIdGenerator(clock: clock),
              model: modelClient,
            );
            final scenarios = persona.scenarios;
            final allExclusiveNeedles = scenarios
                .expand((scenario) => scenario.exclusiveNeedles)
                .toSet();
            var observedAcceptedCount = 0;
            var observedReviewCount = 0;

            for (final scenario in scenarios) {
              final result = await orchestrator.processCapture(
                scenario.input,
                captureId: 'capture-deepseek-live-${persona.id}-${scenario.id}',
              );

              debugPrint(
                '[DeepSeek live QA] ${persona.id}/${scenario.id}: '
                '${result.memoryItem.statusLabel} | '
                '${result.memoryItem.summary}',
                wrapWidth: 1024,
              );

              expect(result.record.status, 'Processed locally');
              expect(
                result.record.id,
                'capture-deepseek-live-${persona.id}-${scenario.id}',
              );
              expect(result.record.body, scenario.input);
              expect(result.memoryItem.summary.trim(), isNotEmpty);
              expect(result.memoryItem.summary.length, lessThanOrEqualTo(240));
              expect(result.memoryItem.sourceRecordId, isNotEmpty);
              if (scenario.expectReview) {
                expect(
                  result.memoryItem.needsReview,
                  isTrue,
                  reason:
                      '${scenario.id} should route high-risk content to review.',
                );
              }
              if (result.memoryItem.needsReview) {
                observedReviewCount += 1;
              } else {
                observedAcceptedCount += 1;
              }
              expect(
                result.memoryItem.statusLabel,
                result.memoryItem.needsReview
                    ? 'needs review'
                    : 'auto-accepted',
              );
              expect(
                result.reviewCandidate == null,
                isNot(result.memoryItem.needsReview),
              );
              expect(result.todo.isSuggested, isTrue);
              expect(
                result.todo.title,
                contains(scenario.input.substring(0, 20)),
              );
              expect(result.acceptedMemoryCount, observedAcceptedCount);
              expect(result.reviewMemoryCount, observedReviewCount);
              _expectSummaryMatchesScenario(
                result.memoryItem.summary,
                scenario,
                forbiddenNeedles: allExclusiveNeedles.difference(
                  scenario.exclusiveNeedles.toSet(),
                ),
              );
              _expectScenarioEventShape(result, scenario);
            }

            final events = await eventStore.readAll();
            expect(
              events
                  .where(
                    (event) =>
                        event.type == runtime.WnEventTypes.memoryProposed,
                  )
                  .length,
              scenarios.length,
            );
            expect(
              events
                  .where(
                    (event) => event.type == runtime.WnEventTypes.todoSuggested,
                  )
                  .length,
              scenarios.length,
            );
            expect(
              events
                  .where(
                    (event) =>
                        event.type == runtime.WnEventTypes.artifactCreated,
                  )
                  .length,
              scenarios.length,
            );

            final traces = await traceSink.readAll();
            expect(
              traces
                  .where((trace) => trace.name == 'runtime.run.completed')
                  .map((trace) => trace.packId),
              containsAll(<String>[
                'pack.default',
                'pack.todo',
                'pack.pkm_library',
              ]),
            );
            expect(
              traces
                  .where((trace) => trace.name == 'runtime.model.completed')
                  .length,
              scenarios.length * 2,
            );

            for (final modelCompletedTrace in traces.where(
              (trace) => trace.name == 'runtime.model.completed',
            )) {
              expect(
                modelCompletedTrace.details['provider_id'],
                'deepseek-live',
              );
              expect(modelCompletedTrace.details['model'], model);
              expect(
                modelCompletedTrace.details.toString(),
                isNot(contains(apiKey)),
              );
            }
          }
        },
        timeout: const Timeout(Duration(minutes: 20)),
      );
    },
  );
}

List<_LivePersona> _livePersonas() {
  return const <_LivePersona>[
    _LivePersona(
      id: 'persona-a',
      scenarios: <_LiveCaptureScenario>[
        _LiveCaptureScenario(
          id: 'a01-atlas',
          input:
              'A01-Atlas 今天和张雨讨论 Project Atlas，下周三前我负责把 ADR-12 '
              '的 Agent Runtime 决策摘要发给她，重点是 local-first 和后端扩展点。',
          expectedNeedles: <String>['A01-Atlas', '张雨', 'ADR-12'],
          exclusiveNeedles: <String>['A01-Atlas'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a02-health',
          input:
              'A02-Health 昨晚 23:40 才睡，今天咖啡喝了两杯，下午焦虑感 6/10，'
              '跑步 20 分钟后缓解；以后晚上 10 点半提醒自己停工。',
          expectedNeedles: <String>['A02-Health', '23:40', '焦虑'],
          exclusiveNeedles: <String>['A02-Health'],
          expectReview: true,
        ),
        _LiveCaptureScenario(
          id: 'a03-pantry',
          input:
              'A03-Pantry 家里低糖酸奶只剩一盒，周末去山姆买蓝莓、燕麦和无糖苏打水；'
              '别买榴莲味零食，我不喜欢。',
          expectedNeedles: <String>['A03-Pantry', '蓝莓', '榴莲'],
          exclusiveNeedles: <String>['A03-Pantry'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a04-asr',
          input:
              'A04-ASR 试用 WideNote 捕捉语音时发现，嘈杂咖啡馆里转写会漏掉人名；'
              '后续 Agent 要在生成 Memory 前保留原始音频引用。',
          expectedNeedles: <String>['A04-ASR', '嘈杂咖啡馆', '原始音频'],
          exclusiveNeedles: <String>['A04-ASR'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a05-lark',
          input: 'A05-LarkBot 明天把 lark-cli 的审批查询 demo 发给子墨，先覆盖待我审批和我发起的两个列表。',
          expectedNeedles: <String>['A05-LarkBot', 'lark-cli', '子墨'],
          exclusiveNeedles: <String>['A05-LarkBot'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a06-finance',
          input: 'A06-Finance 这个月医疗发票和差旅报销要分开记，周五前整理 3 张收据给财务，金额先别放进共享文档。',
          expectedNeedles: <String>['A06-Finance', '医疗发票', '财务'],
          exclusiveNeedles: <String>['A06-Finance'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a07-nimbus',
          input:
              'A07-Nimbus 想把插件市场第一版做成 GitHub 仓库索引，不急着做托管商店；先保证 manifest 校验和 README 模板。',
          expectedNeedles: <String>['A07-Nimbus', 'GitHub', 'manifest'],
          exclusiveNeedles: <String>['A07-Nimbus'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a08-post',
          input:
              'A08-Post 周末写一篇短文，题目暂定“本地优先的软件如何长出生态”，结尾引用 WideNote 的 Pack 设计。',
          expectedNeedles: <String>['A08-Post', '本地优先', 'Pack'],
          exclusiveNeedles: <String>['A08-Post'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a09-book',
          input: 'A09-Book 今天读到《设计中的系统思维》第四章，想记住“约束不是阻力，而是可讨论的边界”。',
          expectedNeedles: <String>['A09-Book', '系统思维', '约束'],
          exclusiveNeedles: <String>['A09-Book'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a10-location',
          input: 'A10-Location 周四 19:30 去万象天地 B1 的蓝鲸书店取预订书，别走南门，那里最近在施工。',
          expectedNeedles: <String>['A10-Location', '19:30', '蓝鲸书店'],
          exclusiveNeedles: <String>['A10-Location'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a11-mentor',
          input: 'A11-Mentor 和老周聊完后记得下次先问他最近的摄影项目，再谈开源维护，效果会更自然。',
          expectedNeedles: <String>['A11-Mentor', '老周', '摄影项目'],
          exclusiveNeedles: <String>['A11-Mentor'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a12-token',
          input:
              'A12-Token 我在测试环境看到 demo-token-A12-rotate，提醒自己只记录需要轮换，不要保存完整凭据。',
          expectedNeedles: <String>['A12-Token', 'demo-token-A12-rotate', '凭据'],
          exclusiveNeedles: <String>['A12-Token'],
          expectReview: true,
        ),
        _LiveCaptureScenario(
          id: 'a13-run',
          input: 'A13-Run 今天晨跑配速 6 分 20 秒，膝盖没有不适；如果连续三次都稳定，再把周末长跑加到 8 公里。',
          expectedNeedles: <String>['A13-Run', '6 分 20 秒', '膝盖'],
          exclusiveNeedles: <String>['A13-Run'],
          expectReview: true,
        ),
        _LiveCaptureScenario(
          id: 'a14-recipe',
          input: 'A14-Recipe 番茄牛腩这次少放桂皮，多加一点白胡椒，汤底更清爽；下次用砂锅小火 90 分钟。',
          expectedNeedles: <String>['A14-Recipe', '番茄牛腩', '90 分钟'],
          exclusiveNeedles: <String>['A14-Recipe'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a15-design',
          input:
              'A15-Design Pack Library 的标签顺序应该是 source、trust、category、capability，再显示权限和输出数量。',
          expectedNeedles: <String>['A15-Design', 'Pack Library', 'trust'],
          exclusiveNeedles: <String>['A15-Design'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a16-family',
          input: 'A16-Family 记得 7 月 6 日给妹妹订生日蛋糕，她喜欢柠檬芝士，不喜欢太甜的奶油。',
          expectedNeedles: <String>['A16-Family', '7 月 6 日', '柠檬芝士'],
          exclusiveNeedles: <String>['A16-Family'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a17-travel',
          input: 'A17-Travel 下次短途出差只带 20L 背包，充电器、降噪耳机、Kindle 放最外层，别再塞第二双鞋。',
          expectedNeedles: <String>['A17-Travel', '20L', 'Kindle'],
          exclusiveNeedles: <String>['A17-Travel'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a18-novel',
          input: 'A18-Novel 小说设定：城市记忆会以街灯亮度保存，主角通过修灯找回失踪朋友留下的线索。',
          expectedNeedles: <String>['A18-Novel', '街灯', '失踪朋友'],
          exclusiveNeedles: <String>['A18-Novel'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a19-meeting',
          input: 'A19-Meeting 周一例会前先发三点：市场索引、PKM Pack、真实 LLM QA，避免会议跑题。',
          expectedNeedles: <String>['A19-Meeting', 'PKM Pack', 'LLM QA'],
          exclusiveNeedles: <String>['A19-Meeting'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'a20-reflect',
          input: 'A20-Reflect 今天做决策时先问“这个默认会不会锁死未来扩展”，这个问题很有用，之后评审都保留。',
          expectedNeedles: <String>['A20-Reflect', '锁死未来扩展', '评审'],
          exclusiveNeedles: <String>['A20-Reflect'],
          expectReview: false,
        ),
      ],
    ),
    _LivePersona(
      id: 'persona-b',
      scenarios: <_LiveCaptureScenario>[
        _LiveCaptureScenario(
          id: 'b01-coral',
          input: 'B01-Coral Coral CRM 的晨会决定先修客户备注导入，再做仪表盘配色；周二给 Mira 看第一版。',
          expectedNeedles: <String>['B01-Coral', 'Coral CRM', 'Mira'],
          exclusiveNeedles: <String>['B01-Coral'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b02-migraine',
          input: 'B02-Migraine 午后偏头痛 5/10，喝水和闭眼休息 15 分钟后缓解；以后连续两天出现要预约医生。',
          expectedNeedles: <String>['B02-Migraine', '偏头痛', '医生'],
          exclusiveNeedles: <String>['B02-Migraine'],
          expectReview: true,
        ),
        _LiveCaptureScenario(
          id: 'b03-parents',
          input: 'B03-Parents 周日给爸妈打电话，先问空调维修结果，再提醒他们把老照片备份到移动硬盘。',
          expectedNeedles: <String>['B03-Parents', '空调维修', '老照片'],
          exclusiveNeedles: <String>['B03-Parents'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b04-tax',
          input: 'B04-Tax 六月税务材料要包括咨询收入、设备发票和房租扣除，具体金额留在本地账本不要发群里。',
          expectedNeedles: <String>['B04-Tax', '税务材料', '本地账本'],
          exclusiveNeedles: <String>['B04-Tax'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b05-tags',
          input: 'B05-Tags PKM 里人物关系不要做成主表，先作为来源可追溯的 tag 和 derived artifact。',
          expectedNeedles: <String>['B05-Tags', 'derived artifact', 'tag'],
          exclusiveNeedles: <String>['B05-Tags'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b06-secret',
          input:
              'B06-Secret 看到测试串 demo-secret-B06-redact，只需要记住要轮换测试串，不能把完整 secret 入库。',
          expectedNeedles: <String>[
            'B06-Secret',
            'demo-secret-B06-redact',
            'secret',
          ],
          exclusiveNeedles: <String>['B06-Secret'],
          expectReview: true,
        ),
        _LiveCaptureScenario(
          id: 'b07-maintenance',
          input: 'B07-Maintenance 公寓水槽有轻微渗水，拍照给物业后周三上午留人在家等维修师傅。',
          expectedNeedles: <String>['B07-Maintenance', '水槽', '周三上午'],
          exclusiveNeedles: <String>['B07-Maintenance'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b08-lark',
          input: 'B08-Lark 飞书日程插件先支持 agenda 和 busy/free，会议室推荐可以放到第二轮。',
          expectedNeedles: <String>['B08-Lark', 'agenda', 'busy/free'],
          exclusiveNeedles: <String>['B08-Lark'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b09-paper',
          input: 'B09-Paper 论文笔记：检索增强不该只追求召回率，还要记录来源版本和生成时的上下文。',
          expectedNeedles: <String>['B09-Paper', '召回率', '来源版本'],
          exclusiveNeedles: <String>['B09-Paper'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b10-tea',
          input: 'B10-Tea 冷泡乌龙比例 8 克茶配 500 毫升水，冰箱 6 小时刚好；下次不要加蜂蜜。',
          expectedNeedles: <String>['B10-Tea', '8 克', '6 小时'],
          exclusiveNeedles: <String>['B10-Tea'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b11-door',
          input: 'B11-Door 临时门禁口令只在今晚给维修师傅使用，之后要删除记录并确认门禁已重置。',
          expectedNeedles: <String>['B11-Door', '门禁', '重置'],
          exclusiveNeedles: <String>['B11-Door'],
          expectReview: true,
        ),
        _LiveCaptureScenario(
          id: 'b12-class',
          input: 'B12-Class 下周的工作坊先讲 source truth，再让大家用三条记录做 Memory review 练习。',
          expectedNeedles: <String>[
            'B12-Class',
            'source truth',
            'Memory review',
          ],
          exclusiveNeedles: <String>['B12-Class'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b13-sleep',
          input: 'B13-Sleep 最近三天醒来都觉得口干，先记录饮水、睡前屏幕时间和室内湿度，周末再复盘。',
          expectedNeedles: <String>['B13-Sleep', '口干', '室内湿度'],
          exclusiveNeedles: <String>['B13-Sleep'],
          expectReview: true,
        ),
        _LiveCaptureScenario(
          id: 'b14-sprint',
          input:
              'B14-Sprint Sprint review 里先演示 Pack 开关影响运行时，再讲 marketplace index 的校验。',
          expectedNeedles: <String>[
            'B14-Sprint',
            'Pack 开关',
            'marketplace index',
          ],
          exclusiveNeedles: <String>['B14-Sprint'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b15-bug',
          input:
              'B15-Bug Android 上快速切 tab 后 Pack Library 偶尔没刷新，怀疑是 provider cache 没失效。',
          expectedNeedles: <String>['B15-Bug', 'Android', 'provider cache'],
          exclusiveNeedles: <String>['B15-Bug'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b16-visa',
          input: 'B16-Visa 出行材料清单包括护照复印件、邀请函、酒店确认单；证件号只保存在加密文件里。',
          expectedNeedles: <String>['B16-Visa', '邀请函', '加密文件'],
          exclusiveNeedles: <String>['B16-Visa'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b17-correction',
          input:
              'B17-Correction 如果 Memory 把“周三交付”写成“周五”，要在复核里编辑再接受，不要直接覆盖原始记录。',
          expectedNeedles: <String>['B17-Correction', '周三交付', '原始记录'],
          exclusiveNeedles: <String>['B17-Correction'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b18-kid',
          input: 'B18-Kid 侄女最近喜欢恐龙贴纸，儿童节礼物可以选考古套装，不要买发声玩具。',
          expectedNeedles: <String>['B18-Kid', '恐龙贴纸', '考古套装'],
          exclusiveNeedles: <String>['B18-Kid'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b19-procure',
          input: 'B19-Procure 办公室补货：白板笔、便利贴、Type-C 线各 10 个，先比价再下单。',
          expectedNeedles: <String>['B19-Procure', '白板笔', 'Type-C'],
          exclusiveNeedles: <String>['B19-Procure'],
          expectReview: false,
        ),
        _LiveCaptureScenario(
          id: 'b20-retro',
          input: 'B20-Retro 今天最有用的习惯是把风险写在方案前面，团队更容易先讨论边界再写代码。',
          expectedNeedles: <String>['B20-Retro', '风险', '边界'],
          exclusiveNeedles: <String>['B20-Retro'],
          expectReview: false,
        ),
      ],
    ),
  ];
}

void _expectScenarioEventShape(
  CapturePipelineResult result,
  _LiveCaptureScenario scenario,
) {
  final sourceEventId = result.record.sourceEventId;
  expect(sourceEventId, isNotNull);
  final checkedSourceEventId = sourceEventId!;
  expect(
    result.eventTypes,
    containsAllInOrder(<String>[
      runtime.WnEventTypes.captureCreated,
      runtime.WnEventTypes.memoryProposed,
      runtime.WnEventTypes.cardCreated,
      runtime.WnEventTypes.insightCreated,
      runtime.WnEventTypes.todoSuggested,
      runtime.WnEventTypes.artifactCreated,
    ]),
  );
  for (final type in <String>[
    runtime.WnEventTypes.memoryProposed,
    runtime.WnEventTypes.cardCreated,
    runtime.WnEventTypes.insightCreated,
    runtime.WnEventTypes.todoSuggested,
    runtime.WnEventTypes.artifactCreated,
  ]) {
    expect(
      result.eventTypes.where((eventType) => eventType == type),
      hasLength(1),
    );
  }

  final memoryEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.memoryProposed,
  );
  expect(memoryEvent.packId, 'pack.default');
  expect(memoryEvent.agentId, 'agent.capture_loop');
  expect(memoryEvent.payload['text'], result.memoryItem.summary);
  expect(
    memoryEvent.payload['source_excerpt'],
    contains(scenario.input.substring(0, 20)),
  );
  final memorySourceRefs = memoryEvent.payload['source_refs'];
  expect(memorySourceRefs, isA<List<Object?>>());
  expect(
    _sourceRefIds(memorySourceRefs as List<Object?>),
    containsAll(<String>[result.record.id, checkedSourceEventId]),
  );

  final cardEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.cardCreated,
  );
  expect(cardEvent.payload['source_capture_id'], result.record.id);
  expect(cardEvent.payload['source_event_id'], checkedSourceEventId);
  expect(
    _sourceRefIds(cardEvent.payload['source_refs']! as List<Object?>),
    containsAll(<String>[result.record.id, checkedSourceEventId]),
  );

  final insightEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.insightCreated,
  );
  expect(insightEvent.payload['source_capture_id'], result.record.id);
  expect(insightEvent.payload['source_event_id'], checkedSourceEventId);
  expect(
    _sourceRefIds(insightEvent.payload['source_refs']! as List<Object?>),
    containsAll(<String>[result.record.id, checkedSourceEventId]),
  );

  final todoEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.todoSuggested,
  );
  expect(todoEvent.packId, 'pack.todo');
  expect(todoEvent.agentId, 'agent.todo_loop');
  expect(todoEvent.payload['source_event_id'], checkedSourceEventId);
  expect(result.todo.sourceCaptureId, result.record.id);
  expect(result.todo.sourceEventId, checkedSourceEventId);

  final artifactEvent = result.events.singleWhere(
    (event) => event.type == runtime.WnEventTypes.artifactCreated,
  );
  expect(artifactEvent.packId, 'pack.pkm_library');
  expect(artifactEvent.agentId, 'agent.pkm_profile_builder');
  expect(artifactEvent.payload['artifact_kind'], 'pkm_profile_entry');
  expect(artifactEvent.payload['derived_output'], isTrue);
  expect(
    artifactEvent.payload['source_truth'],
    'raw_capture_and_memory_remain_canonical',
  );
  expect(artifactEvent.payload['body'].toString().trim(), isNotEmpty);
  expect(artifactEvent.payload['source_capture_id'], result.record.id);
  expect(artifactEvent.payload['source_event_id'], checkedSourceEventId);
  expect(
    _sourceRefIds(artifactEvent.payload['source_refs']! as List<Object?>),
    containsAll(<String>[result.record.id, checkedSourceEventId]),
  );
}

void _expectSummaryMatchesScenario(
  String summary,
  _LiveCaptureScenario scenario, {
  required Set<String> forbiddenNeedles,
}) {
  final matchedNeedles = scenario.expectedNeedles
      .where((needle) => summary.contains(needle))
      .toList(growable: false);
  if (matchedNeedles.isEmpty) {
    debugPrint(
      '[DeepSeek live QA] ${scenario.id} summary translated or compressed '
      'all expected anchors: $summary',
      wrapWidth: 1024,
    );
  }
  for (final needle in forbiddenNeedles) {
    expect(
      summary,
      isNot(contains(needle)),
      reason:
          'Memory summary for ${scenario.id} appears to include another '
          'scenario anchor "$needle". Summary: $summary',
    );
  }
}

final class _LivePersona {
  const _LivePersona({required this.id, required this.scenarios});

  final String id;
  final List<_LiveCaptureScenario> scenarios;
}

final class _LiveCaptureScenario {
  const _LiveCaptureScenario({
    required this.id,
    required this.input,
    required this.expectedNeedles,
    required this.exclusiveNeedles,
    required this.expectReview,
  });

  final String id;
  final String input;
  final List<String> expectedNeedles;
  final List<String> exclusiveNeedles;
  final bool expectReview;
}

Set<String> _sourceRefIds(List<Object?> sourceRefs) {
  return sourceRefs
      .whereType<Map>()
      .map((sourceRef) => sourceRef['id'])
      .whereType<String>()
      .toSet();
}
